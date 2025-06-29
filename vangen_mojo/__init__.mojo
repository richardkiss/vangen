from python import Python, PythonObject, ConvertibleFromPython
from python.bindings import PythonModuleBuilder
from collections import List
from vangen_mojo.hash import hash160_span, hash160

from memory import Span, UnsafePointer

from base64 import b16decode


@export
fn PyInit_vangen_mojo() -> PythonObject:
    try:
        var m = PythonModuleBuilder("vangen_mojo")
        m.def_function[hash160_mojo]("hash160")
        m.def_function[matching_hashes_for_range]("matching_hashes_for_range")
        m.def_function[matching_hashes_for_range_gpu]("matching_hashes_for_range_gpu")
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


fn dump_hex(data: Span[UInt8]) -> None:
    hex_chars = "0123456789abcdef"
    for byte in data:
        print(hex_chars[(byte >> 4) & 0x0F], end="")
        print(hex_chars[byte & 0x0F], end="")
    print()


fn matching_hashes_for_range(
    start: PythonObject, size: PythonObject, prefix_hex: PythonObject, match_hex: PythonObject
) raises -> PythonObject:  # List[UInt64]:
    var s: Int = Int(start)
    var sz: Int = Int(size)
    var ps = String(prefix_hex)
    var ms = String(match_hex)
    ps_b = b16decode(ps).as_bytes()
    ms_b = b16decode(ms).as_bytes()
    r = Python.list()
    for i in range(sz):
        idx: Int = s + i
        input_data = input_for_index(idx, ps_b)
        hash_result = hash160_span(input_data)
        # dump_hex(hash_result)
        if starts_with(hash_result, ms_b):
            r.append(idx)
    return r


fn set_bit(bit_array: UnsafePointer[UInt8], index: Int) -> None:
    byte_index = index // 8
    bit_index = index % 8
    bit_array[byte_index] |= (1 << bit_index)


struct BitArray:
    var bits: List[UInt8]

    fn __init__(out self, size: Int):
        byte_length=(size + 7) // 8
        self.bits = List[UInt8](fill=0, length=byte_length)

    fn set(mut self, index: Int) -> None:
        byte_index = index // 8
        if byte_index >= len(self.bits):
            new_size = byte_index + 1
            self.bits.resize(new_size=new_size, value=0)
        set_bit(Span(self.bits).unsafe_ptr(), index)

    fn get(self, index: Int) -> Bool:
        byte_index = index // 8
        bit_index = index % 8
        if byte_index >= len(self.bits):
            return False
        return (self.bits[byte_index] & (1 << bit_index)) != 0


from gpu import thread_idx, block_dim, block_idx
from gpu.host import DeviceContext, HostBuffer
from layout import Layout, LayoutTensor
from testing import assert_equal

# ANCHOR: broadcast_add_layout_tensor
alias SIZE = 2
alias BLOCKS_PER_GRID = 1
alias THREADS_PER_BLOCK = (3, 3)
alias dtype = DType.float32
alias out_layout = Layout.row_major(SIZE, SIZE)
alias a_layout = Layout.row_major(1, SIZE)
alias b_layout = Layout.row_major(SIZE, 1)




fn matching_hashes_for_range_gpu(
    start: PythonObject, size: PythonObject, prefix_hex: PythonObject, match_hex: PythonObject
) raises -> PythonObject:
    var s: Int = Int(start)
    var sz: Int = Int(size)
    var ps = String(prefix_hex)
    var ms = String(match_hex)
    ps_b = b16decode(ps).as_bytes()
    ms_b = b16decode(ms).as_bytes()
    thread_count = 32
    size_per_thread_unrounded = (sz + thread_count - 1) // thread_count
    size_per_thread = (size_per_thread_unrounded + 7) // 8 * 8  # round up to nearest multiple of 8

    print("size_per_thread_unrounded=", size_per_thread_unrounded, " size_per_thread=", size_per_thread)

    bit_array = BitArray(sz)
    ptr = bit_array.bits.unsafe_ptr()

    for thread_id in range(thread_count):
        start0 = thread_id * size_per_thread
        end0 = min(start0 + size_per_thread, sz)
        process_thread(start0, end0, thread_id, ps_b, ms_b, ptr, s)

    # convert bit array to a list of indices
    r = Python.list()
    for i in range(sz):
        if bit_array.get(i):
            r.append(s + i)
    return r

fn process_thread(start: Int, end: Int, thread_id: Int, ps_b: Span[UInt8], ms_b: Span[UInt8], bit_array: UnsafePointer[UInt8], s: Int) -> None:
    for i in range(start, end):
        idx: Int = s + i  # Convert relative index to absolute index
        input_data = input_for_index(idx, ps_b)
        try:
            hash_result = hash160_span(input_data)
            if starts_with(hash_result, ms_b):
                print("matching index=", idx)
                set_bit(bit_array, i)  # Set bit at relative position i

                # Here we would set the bit in a shared bit array or similar structure
                # This is a placeholder for the actual GPU logic
                pass
        except e:
            print("Error processing index ", idx, ": ", e)
