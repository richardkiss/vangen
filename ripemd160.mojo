# Copyright (c) 2021 Pieter Wuille
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.


from base64 import b16encode
from memory import Pointer


struct RipeMD160:
    var ML: InlineArray[UInt8, 80]
    var MR: InlineArray[UInt8, 80]
    var RL: InlineArray[UInt8, 80]
    var RR: InlineArray[UInt8, 80]
    var KL: InlineArray[UInt32, 5]
    var KR: InlineArray[UInt32, 5]

    fn __init__(out self):
        # Message schedule indexes for the left path.
        self.ML = InlineArray[UInt8, 80](
            0,
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
            13,
            14,
            15,
            7,
            4,
            13,
            1,
            10,
            6,
            15,
            3,
            12,
            0,
            9,
            5,
            2,
            14,
            11,
            8,
            3,
            10,
            14,
            4,
            9,
            15,
            8,
            1,
            2,
            7,
            0,
            6,
            13,
            11,
            5,
            12,
            1,
            9,
            11,
            10,
            0,
            8,
            12,
            4,
            13,
            3,
            7,
            15,
            14,
            5,
            6,
            2,
            4,
            0,
            5,
            9,
            7,
            12,
            2,
            10,
            14,
            1,
            3,
            8,
            11,
            6,
            15,
            13,
        )

        # Message schedule indexes for the right path.
        self.MR = InlineArray[UInt8, 80](
            5,
            14,
            7,
            0,
            9,
            2,
            11,
            4,
            13,
            6,
            15,
            8,
            1,
            10,
            3,
            12,
            6,
            11,
            3,
            7,
            0,
            13,
            5,
            10,
            14,
            15,
            8,
            12,
            4,
            9,
            1,
            2,
            15,
            5,
            1,
            3,
            7,
            14,
            6,
            9,
            11,
            8,
            12,
            2,
            10,
            0,
            4,
            13,
            8,
            6,
            4,
            1,
            3,
            11,
            15,
            0,
            5,
            12,
            2,
            13,
            9,
            7,
            10,
            14,
            12,
            15,
            10,
            4,
            1,
            5,
            8,
            7,
            6,
            2,
            13,
            14,
            0,
            3,
            9,
            11,
        )

        # Rotation counts for the left path.
        self.RL = InlineArray[UInt8, 80](
            11,
            14,
            15,
            12,
            5,
            8,
            7,
            9,
            11,
            13,
            14,
            15,
            6,
            7,
            9,
            8,
            7,
            6,
            8,
            13,
            11,
            9,
            7,
            15,
            7,
            12,
            15,
            9,
            11,
            7,
            13,
            12,
            11,
            13,
            6,
            7,
            14,
            9,
            13,
            15,
            14,
            8,
            13,
            6,
            5,
            12,
            7,
            5,
            11,
            12,
            14,
            15,
            14,
            15,
            9,
            8,
            9,
            14,
            5,
            6,
            8,
            6,
            5,
            12,
            9,
            15,
            5,
            11,
            6,
            8,
            13,
            12,
            5,
            12,
            13,
            14,
            11,
            8,
            5,
            6,
        )

        # Rotation counts for the right path.
        self.RR = InlineArray[UInt8, 80](
            8,
            9,
            9,
            11,
            13,
            15,
            15,
            5,
            7,
            7,
            8,
            11,
            14,
            14,
            12,
            6,
            9,
            13,
            15,
            7,
            12,
            8,
            9,
            11,
            7,
            7,
            12,
            7,
            6,
            15,
            13,
            11,
            9,
            7,
            15,
            11,
            8,
            6,
            6,
            14,
            12,
            13,
            5,
            14,
            13,
            13,
            7,
            5,
            15,
            5,
            8,
            11,
            14,
            14,
            6,
            14,
            6,
            9,
            12,
            9,
            12,
            5,
            15,
            8,
            8,
            5,
            12,
            9,
            12,
            5,
            14,
            6,
            8,
            13,
            6,
            5,
            15,
            13,
            11,
            11,
        )

        # K constants for the left path.
        self.KL = InlineArray[UInt32, 5](
            0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E
        )

        # K constants for the right path.
        self.KR = InlineArray[UInt32, 5](
            0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0
        )

    fn compress(
        self,
        mut h0: UInt32,
        mut h1: UInt32,
        mut h2: UInt32,
        mut h3: UInt32,
        mut h4: UInt32,
        block: Span[UInt32],
    ) raises -> None:
        """Compress state (h0, h1, h2, h3, h4) with block."""
        # Message schedule indexes for the left path.

        # Left path.
        al = h0
        bl = h1
        cl = h2
        dl = h3
        el = h4
        # Right path variables.
        ar = h0
        br = h1
        cr = h2
        dr = h3
        er = h4
        # message variables.

        # iterate over the 80 rounds of the compression.

        for j in range(80):
            rnd = j >> 4
            # perform left side of the transformation.
            v0 = al + fi(bl, cl, dl, rnd) + block[self.ML[j]] + self.KL[rnd]
            al = rol(UInt32(v0), self.RL[j]) + el
            al, bl, cl, dl, el = el, al, bl, rol(cl, 10), dl
            # perform right side of the transformation.
            v1 = ar + fi(br, cr, dr, 4 - rnd) + block[self.MR[j]] + self.KR[rnd]
            ar = rol(UInt32(v1), self.RR[j]) + er
            ar, br, cr, dr, er = er, ar, br, rol(cr, 10), dr

        # compose old state, left transform, and right transform into new state.
        (h0, h1, h2, h3, h4) = (
            h1 + cl + dr,
            h2 + dl + er,
            h3 + el + ar,
            h4 + al + br,
            h0 + bl + cr,
        )

    fn ripemd160(self, data: Span[UInt8]) raises -> List[UInt8]:
        """Compute the RIPEMD-160 hash of data."""
        # initialize state.
        s0: UInt32 = 0x67452301
        s1: UInt32 = 0xEFCDAB89
        s2: UInt32 = 0x98BADCFE
        s3: UInt32 = 0x10325476
        s4: UInt32 = 0xC3D2E1F0
        # process full 64-byte blocks in the input.
        size = len(data)
        max_val = size >> 6
        b = UInt32(0)
        u_data = data.unsafe_ptr()
        while b < max_val:
            p1 = u_data + (b * 64)
            # Convert UInt8 pointer to UInt32 span
            uint32_ptr = p1.bitcast[UInt32]()
            block_span = Span[UInt32, ImmutableAnyOrigin](
                ptr=uint32_ptr, length=16
            )
            self.compress(s0, s1, s2, s3, s4, block_span)
            b += 1
        # Construct final blocks (with padding and size).
        fin = create_pad_blocks(data, max_val * 64)
        # Process final blocks.
        max_val_1 = len(fin) >> 6
        b = 0
        while b < max_val_1:
            # Extract a 64-byte block from fin
            block_start = b * 64
            block_end = (b + 1) * 64
            block = List[UInt8](capacity=64)
            i = block_start
            while i < block_end:
                block.append(fin[i])
                i += 1
            # Convert to UInt32 span
            uint32_ptr = block.data.bitcast[UInt32]()
            block_span = Span[UInt32, ImmutableAnyOrigin](
                ptr=uint32_ptr, length=16
            )
            self.compress(s0, s1, s2, s3, s4, block_span)
            b += 1
        # Produce output.
        out = List[UInt8](capacity=20)
        append_uint32(out, s0)
        append_uint32(out, s1)
        append_uint32(out, s2)
        append_uint32(out, s3)
        append_uint32(out, s4)
        return out


alias bytes_ptr = Pointer[Int8]


# @always_inline
fn fi(x: UInt32, y: UInt32, z: UInt32, i: UInt32) -> UInt32:
    """The f1, f2, f3, f4, and f5 functions from the specification."""
    if i == 0:
        return x ^ y ^ z
    elif i == 1:
        return (x & y) | (~x & z)
    elif i == 2:
        return (x | ~y) ^ z
    elif i == 3:
        return (x & z) | (y & ~z)
    return x ^ (y | ~z)


fn rol(x: UInt32, i: UInt8) -> UInt32:
    """Rotate the bottom 32 bits of x left by i bits."""
    i32 = UInt32(i)
    return ((x << i32) | ((x & 0xFFFFFFFF) >> (32 - i32))) & 0xFFFFFFFF


fn create_pad_blocks(data: Span[UInt8], offset: UInt32) -> List[UInt8]:
    """Create padding and size blocks for the message."""
    size = UInt32(len(data))
    remaining_size = Int(size - offset)

    # Calculate total padded size (remaining + 1 byte + padding + 8 bytes for size)
    # Must be multiple of 64 bytes
    total_with_size = remaining_size + 1 + 8  # +1 for 0x80, +8 for size
    blocks_needed = (total_with_size + 63) // 64  # Round up to nearest block
    padded_size = blocks_needed * 64
    zero_pad_count = padded_size - total_with_size

    # Create output buffer
    result = List[UInt8](capacity=padded_size)

    # Copy remaining data
    for i in range(remaining_size):
        result.append(data[Int(offset) + i])

    # Add mandatory 0x80 byte
    result.append(0x80)

    # Add zero padding
    for _ in range(zero_pad_count):
        result.append(0)

    # Add 64-bit size in little-endian format (size in bits)
    size_bits = UInt64(size) << 3
    for i in range(8):
        result.append(UInt8((size_bits >> (i * 8)) & 0xFF))

    return result


@always_inline
fn append_uint32(mut out: List[UInt8], val: UInt32) -> None:
    """Append a 32-bit integer to a byte array."""
    out.append(UInt8((val >> 0) & 0xFF))
    out.append(UInt8((val >> 8) & 0xFF))
    out.append(UInt8((val >> 16) & 0xFF))
    out.append(UInt8((val >> 24) & 0xFF))
