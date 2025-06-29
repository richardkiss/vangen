from python import Python, PythonObject, ConvertibleFromPython
from python.bindings import PythonModuleBuilder
from collections import List
from vangen_mojo.hash import hash160_span, hash160

from memory import Span, UnsafePointer


from gpu import thread_idx, block_dim, block_idx
from gpu.host import DeviceContext, HostBuffer, DeviceBuffer
from layout import Layout, LayoutTensor
from testing import assert_equal


@export
fn PyInit_vangen_mojo() -> PythonObject:
    try:
        var m = PythonModuleBuilder("vangen_mojo")
        m.def_function[hash160_mojo]("hash160")
        m.def_function[matching_hashes_for_range]("matching_hashes_for_range")
        m.def_function[matching_hashes_for_range_gpu](
            "matching_hashes_for_range_gpu"
        )
        return m.finalize()
    except e:
        print("Error initializing module: ", e)
        return PythonObject()


fn hash160_mojo(b: PythonObject) raises -> PythonObject:
    var buffer = String(b)
    var result = hash160(buffer.as_string_slice())

    var py_list = Python.list()
    for item in result:
        py_list.append(item)
    var bytes_class = Python.import_module("builtins").bytes
    var py_bytes = bytes_class(py_list)
    return py_bytes


fn input_for_index(i: Int, hex_prefix: Span[UInt8]) -> List[UInt8]:
    r = List[UInt8](capacity=8 + len(hex_prefix))
    r.extend(hex_prefix)
    for idx in range(8):
        r.append(UInt8((i >> (56 - idx * 8)) & 0xFF))
    return r


fn starts_with(data: Span[UInt8], prefix: Span[UInt8]) -> Bool:
    if len(data) < len(prefix):
        return False
    for i in range(len(prefix)):
        if data[i] != prefix[i]:
            return False
    return True


fn b2h(data: Span[UInt8]) -> String:
    """Converts a byte array to a hexadecimal string."""
    hex_chars = "0123456789abcdef"
    result = String()
    for byte in data:
        result += hex_chars[(byte >> 4) & 0x0F]
        result += hex_chars[byte & 0x0F]
    return result


fn h2b(str: StringSlice[mut=False]) -> List[UInt8]:
    """Performs base16 decoding on the input string, writing to a mutable List[UInt8].

    Args:
        str: A base16 encoded string.
    """
    alias `A` = UInt8(ord("A"))
    alias `a` = UInt8(ord("a"))
    alias `Z` = UInt8(ord("Z"))
    alias `z` = UInt8(ord("z"))
    alias `0` = UInt8(ord("0"))
    alias `9` = UInt8(ord("9"))

    @parameter
    @always_inline
    fn decode(c: UInt8) -> UInt8:
        if `A` <= c <= `Z`:
            return c - `A` + UInt8(10)
        elif `a` <= c <= `z`:
            return c - `a` + UInt8(10)
        elif `0` <= c <= `9`:
            return c - `0`
        else:
            return UInt8(-1)

    var data = str.as_bytes()
    var n = str.byte_length()
    debug_assert(n % 2 == 0, "Input length '", n, "' must be divisible by 2")

    result = List[UInt8](capacity=n // 2)
    for i in range(0, n, 2):
        var hi = data[i]
        var lo = data[i + 1]
        result.append(decode(hi) << 4 | decode(lo))
    return result


fn matching_hashes_for_range(
    start_py: PythonObject,
    size_py: PythonObject,
    prefix_hex_py: PythonObject,
    match_hex_py: PythonObject,
) raises -> PythonObject:
    var start: Int = Int(start_py)
    var size: Int = Int(size_py)
    var prefix_string = String(prefix_hex_py)
    var match_string = String(match_hex_py)
    ps_b = h2b(prefix_string)
    ms_b = h2b(match_string)
    r = Python.list()
    for i in range(start, start + size):
        input_data = input_for_index(i, ps_b)
        hash_result = hash160_span(input_data)
        # print(b2h(hash_result))
        if starts_with(hash_result, ms_b):
            print(b2h(hash_result))
            r.append(i)
    return r


fn set_bit(bit_array: UnsafePointer[UInt8], index: Int) -> None:
    byte_index = index // 8
    bit_index = index % 8
    bit_array[byte_index] |= 1 << bit_index


struct BitArray[origin: Origin]:
    var bits: Span[UInt8, origin=origin]

    fn __init__(out self, bits: Span[UInt8, origin=origin]):
        self.bits = bits

    fn set(mut self, index: Int) -> None:
        byte_index = index // 8
        if byte_index < len(self.bits):
            set_bit(Span(self.bits).unsafe_ptr(), index)

    fn get(self, index: Int) -> Bool:
        byte_index = index // 8
        bit_index = index % 8
        if byte_index >= len(self.bits):
            return False
        return (self.bits[byte_index] & (1 << bit_index)) != 0


fn matching_hashes_for_range_gpu(
    start_py: PythonObject,
    size_py: PythonObject,
    prefix_hex_py: PythonObject,
    match_hex_py: PythonObject,
) raises -> PythonObject:
    var start: Int = Int(start_py)
    var size: Int = Int(size_py)
    var prefix_string = String(prefix_hex_py)
    var match_string = String(match_hex_py)
    prefix = h2b(prefix_string)
    match_bytes = h2b(match_string)

    # Scale thread count based on workload size for better parallelism
    base_thread_count = 4096  # Increased from 1024
    # For very large workloads, use even more threads
    thread_count = min(base_thread_count, size)  # Don't exceed work size

    count_per_thread_unrounded = (size + thread_count - 1) // thread_count
    # Reduce rounding to minimize idle threads
    count_per_thread = (
        (count_per_thread_unrounded + 3) // 4 * 4
    )  # Round up to nearest multiple of 4 (instead of 8)

    print(
        "count_per_thread_unrounded=",
        count_per_thread_unrounded,
        " count_per_thread=",
        count_per_thread,
    )

    return launch_gpu_threads(
        start,
        size,
        count_per_thread,
        prefix,
        match_bytes,
        thread_count,
    )


fn bit_array_to_list(
    bit_array: Span[UInt8], offset: Int
) raises -> PythonObject:
    r = Python.list()
    for i in range(len(bit_array) * 8):
        if (bit_array[i // 8] & (1 << (i % 8))) != 0:
            r.append(i + offset)
    return r


fn launch_cpu_threads(
    start: Int,
    size: Int,
    count_per_thread: Int,
    prefix: List[UInt8],
    match_bytes: List[UInt8],
    thread_count: Int,
) raises -> PythonObject:
    print("Launching CPU threads")
    length = (size + 7) // 8
    bit_array_memory = List[UInt8](length=length, fill=0)
    for thread_id in range(thread_count):
        process_thread(
            start,
            size,
            count_per_thread,
            prefix,
            match_bytes,
            bit_array_memory,
            thread_id,
        )

    # convert bit array to a list of indices
    return bit_array_to_list(bit_array_memory, start)


fn launch_gpu_threads(
    start: Int,
    size: Int,
    count_per_thread: Int,
    prefix: List[UInt8],
    match_bytes: List[UInt8],
    thread_count: Int,
) raises -> PythonObject:
    print("Launching GPU threads")
    length = (size + 7) // 8
    with DeviceContext() as ctx:
        bit_array_memory = ctx.enqueue_create_buffer[DType.uint8](
            length
        ).enqueue_fill(0)

        # Calculate optimal grid and block dimensions for maximum GPU utilization
        optimal_block_size = (
            512  # Increased for better occupancy on modern GPUs
        )
        grid_size = (
            thread_count + optimal_block_size - 1
        ) // optimal_block_size

        print(
            "thread_count=",
            thread_count,
            " grid_size=",
            grid_size,
            " optimal_block_size=",
            optimal_block_size,
        )
        print("Total GPU threads=", grid_size * optimal_block_size)

        ctx.enqueue_function[process_gpu_thread](
            start,
            size,
            count_per_thread,
            prefix,
            match_bytes,
            bit_array_memory,
            grid_dim=grid_size,
            block_dim=optimal_block_size,
        )

        ctx.synchronize()

        with bit_array_memory.map_to_host() as bit_array_host:
            s = Span(bit_array_host.as_span())
            r = bit_array_to_list(s, start)
    return r


fn process_thread(
    start: Int,
    size: Int,
    count_per_thread: Int,
    prefix: List[UInt8],
    match_bytes: List[UInt8],
    bit_array: Span[mut=True, UInt8],
    thread_id: Int,
) -> None:
    my_start = thread_id * count_per_thread + start
    my_end = min(my_start + count_per_thread, start + size)
    for offset in range(my_end - my_start):
        idx = my_start + offset
        input_data = input_for_index(idx, prefix)
        try:
            hash_result = hash160_span(input_data)
            if starts_with(hash_result, match_bytes):
                set_bit(bit_array.unsafe_ptr(), idx - start)
        except e:
            print("Error processing index ", idx, ": ", e)


fn process_gpu_thread(
    start: Int,
    size: Int,
    count_per_thread: Int,
    prefix: List[UInt8],
    match_bytes: List[UInt8],
    bit_array: UnsafePointer[UInt8],
) -> None:
    # Calculate global thread ID across all blocks
    thread_id = Int(block_idx.x) * Int(block_dim.x) + Int(thread_idx.x)
    my_start = thread_id * count_per_thread + start
    my_end = min(my_start + count_per_thread, start + size)
    print(
        "thread_id=",
        thread_id,
        " block_idx=",
        block_idx.x,
        " thread_idx=",
        thread_idx.x,
    )
    print("my_start=", my_start, " my_end=", my_end, " thread_id=", thread_id)
    for offset in range(my_end - my_start):
        idx = my_start + offset
        input_data = input_for_index(idx, prefix)
        try:
            hash_result = hash160_span(input_data)
            if starts_with(hash_result, match_bytes):
                set_bit(bit_array, idx - start)
        except e:
            print("Error processing index ", idx, ": ", e)
