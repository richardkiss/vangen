from memory import UnsafePointer, Span
from collections import List
from vangen_mojo.sha256_lib import SHA256
from vangen_mojo.ripemd160 import RipeMD160

fn hash160(data: StringSlice) raises -> List[UInt8]:
    blob = data.as_bytes()
    size = len(data)
    var sha_hasher = SHA256()
    var sha_result = sha_hasher.sha256(blob)

    var ripe_hasher = RipeMD160()
    var ripe_result = ripe_hasher.ripemd160(Span(sha_result))

    return ripe_result