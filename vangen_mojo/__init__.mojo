from python import Python, PythonObject, ConvertibleFromPython
from python.bindings import PythonModuleBuilder
from collections import List
from vangen_mojo.hash import hash160_span, hash160

from base64 import b16decode


@export
fn PyInit_vangen_mojo() -> PythonObject:
    try:
        var m = PythonModuleBuilder("vangen_mojo")
        m.def_function[hash160_mojo]("hash160")
        m.def_function[matching_hashes_for_range]("matching_hashes_for_range")
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
