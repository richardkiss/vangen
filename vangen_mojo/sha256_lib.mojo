# Copyright (c) 2021 Pieter Wuille
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
"""Pure Mojo SHA-256 implementation library."""

# Based on SHA-256 specification and RIPEMD-160 template
# Adapted for Mojo by following the structure of ripemd160.mojo

from memory import Pointer
from memory.unsafe_pointer import UnsafePointer


struct SHA256:
    var K: InlineArray[UInt32, 64]  # Round constants

    fn __init__(out self):
        # SHA-256 round constants
        self.K = InlineArray[UInt32, 64](
            0x428A2F98,
            0x71374491,
            0xB5C0FBCF,
            0xE9B5DBA5,
            0x3956C25B,
            0x59F111F1,
            0x923F82A4,
            0xAB1C5ED5,
            0xD807AA98,
            0x12835B01,
            0x243185BE,
            0x550C7DC3,
            0x72BE5D74,
            0x80DEB1FE,
            0x9BDC06A7,
            0xC19BF174,
            0xE49B69C1,
            0xEFBE4786,
            0x0FC19DC6,
            0x240CA1CC,
            0x2DE92C6F,
            0x4A7484AA,
            0x5CB0A9DC,
            0x76F988DA,
            0x983E5152,
            0xA831C66D,
            0xB00327C8,
            0xBF597FC7,
            0xC6E00BF3,
            0xD5A79147,
            0x06CA6351,
            0x14292967,
            0x27B70A85,
            0x2E1B2138,
            0x4D2C6DFC,
            0x53380D13,
            0x650A7354,
            0x766A0ABB,
            0x81C2C92E,
            0x92722C85,
            0xA2BFE8A1,
            0xA81A664B,
            0xC24B8B70,
            0xC76C51A3,
            0xD192E819,
            0xD6990624,
            0xF40E3585,
            0x106AA070,
            0x19A4C116,
            0x1E376C08,
            0x2748774C,
            0x34B0BCB5,
            0x391C0CB3,
            0x4ED8AA4A,
            0x5B9CCA4F,
            0x682E6FF3,
            0x748F82EE,
            0x78A5636F,
            0x84C87814,
            0x8CC70208,
            0x90BEFFFA,
            0xA4506CEB,
            0xBEF9A3F7,
            0xC67178F2,
        )

    fn compress(
        self,
        mut h0: UInt32,
        mut h1: UInt32,
        mut h2: UInt32,
        mut h3: UInt32,
        mut h4: UInt32,
        mut h5: UInt32,
        mut h6: UInt32,
        mut h7: UInt32,
        block: UnsafePointer[UInt8],
    ) raises -> Tuple[
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32
    ]:
        """Compress state with block."""

        # Convert block to big-endian 32-bit words
        var w = InlineArray[UInt32, 64](UInt32(0))
        var x = block.bitcast[UInt32]()

        # Copy and convert to big-endian
        for i in range(16):
            var word = x[i]
            # Convert from little-endian to big-endian
            w[i] = (
                ((word & 0xFF) << 24)
                | (((word >> 8) & 0xFF) << 16)
                | (((word >> 16) & 0xFF) << 8)
                | ((word >> 24) & 0xFF)
            )

        # Extend the first 16 words into the remaining 48 words w[16..63] of the message schedule array
        for i in range(16, 64):
            var s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
            var s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] + s0 + w[i - 7] + s1

        # Initialize working variables
        var a = h0
        var b = h1
        var c = h2
        var d = h3
        var e = h4
        var f = h5
        var g = h6
        var h = h7

        # Main loop
        for i in range(64):
            var S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            var ch = (e & f) ^ ((~e) & g)
            var temp1 = h + S1 + ch + self.K[i] + w[i]
            var S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            var maj = (a & b) ^ (a & c) ^ (b & c)
            var temp2 = S0 + maj

            h = g
            g = f
            f = e
            e = d + temp1
            d = c
            c = b
            b = a
            a = temp1 + temp2

        # Add the compressed chunk to the current hash value
        return (h0 + a, h1 + b, h2 + c, h3 + d, h4 + e, h5 + f, h6 + g, h7 + h)

    fn sha256(self, data: Span[UInt8]) raises -> List[UInt8]:
        """Compute the SHA-256 hash of data."""
        # Initialize hash values (first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19)
        size = len(data)
        var s0: UInt32 = 0x6A09E667
        var s1: UInt32 = 0xBB67AE85
        var s2: UInt32 = 0x3C6EF372
        var s3: UInt32 = 0xA54FF53A
        var s4: UInt32 = 0x510E527F
        var s5: UInt32 = 0x9B05688C
        var s6: UInt32 = 0x1F83D9AB
        var s7: UInt32 = 0x5BE0CD19

        # Process full 64-byte blocks in the input
        var max_val = size >> 6
        u_data = data.unsafe_ptr()
        var b = UInt32(0)
        while b < max_val:
            var p1 = u_data + b * 64
            var result = self.compress(s0, s1, s2, s3, s4, s5, s6, s7, p1)
            s0 = result[0]
            s1 = result[1]
            s2 = result[2]
            s3 = result[3]
            s4 = result[4]
            s5 = result[5]
            s6 = result[6]
            s7 = result[7]
            b += 1

        # Construct final blocks (with padding and size)
        var fin = create_pad_blocks_sha256(u_data, size, max_val * 64)

        # Process final blocks
        var max_val_1 = len(fin) >> 6
        b = 0
        while b < max_val_1:
            # Extract a 64-byte block from fin
            var block_start = b * 64
            var block_end = (b + 1) * 64
            var block = List[UInt8](capacity=64)
            var i = block_start
            while i < block_end:
                block.append(fin[i])
                i += 1
            var result = self.compress(
                s0, s1, s2, s3, s4, s5, s6, s7, block.data
            )
            s0 = result[0]
            s1 = result[1]
            s2 = result[2]
            s3 = result[3]
            s4 = result[4]
            s5 = result[5]
            s6 = result[6]
            s7 = result[7]
            b += 1

        # Produce output (32 bytes, big-endian)
        var out = List[UInt8](capacity=32)
        # s0
        out.append(UInt8((s0 >> 24) & 0xFF))
        out.append(UInt8((s0 >> 16) & 0xFF))
        out.append(UInt8((s0 >> 8) & 0xFF))
        out.append(UInt8((s0 >> 0) & 0xFF))
        # s1
        out.append(UInt8((s1 >> 24) & 0xFF))
        out.append(UInt8((s1 >> 16) & 0xFF))
        out.append(UInt8((s1 >> 8) & 0xFF))
        out.append(UInt8((s1 >> 0) & 0xFF))
        # s2
        out.append(UInt8((s2 >> 24) & 0xFF))
        out.append(UInt8((s2 >> 16) & 0xFF))
        out.append(UInt8((s2 >> 8) & 0xFF))
        out.append(UInt8((s2 >> 0) & 0xFF))
        # s3
        out.append(UInt8((s3 >> 24) & 0xFF))
        out.append(UInt8((s3 >> 16) & 0xFF))
        out.append(UInt8((s3 >> 8) & 0xFF))
        out.append(UInt8((s3 >> 0) & 0xFF))
        # s4
        out.append(UInt8((s4 >> 24) & 0xFF))
        out.append(UInt8((s4 >> 16) & 0xFF))
        out.append(UInt8((s4 >> 8) & 0xFF))
        out.append(UInt8((s4 >> 0) & 0xFF))
        # s5
        out.append(UInt8((s5 >> 24) & 0xFF))
        out.append(UInt8((s5 >> 16) & 0xFF))
        out.append(UInt8((s5 >> 8) & 0xFF))
        out.append(UInt8((s5 >> 0) & 0xFF))
        # s6
        out.append(UInt8((s6 >> 24) & 0xFF))
        out.append(UInt8((s6 >> 16) & 0xFF))
        out.append(UInt8((s6 >> 8) & 0xFF))
        out.append(UInt8((s6 >> 0) & 0xFF))
        # s7
        out.append(UInt8((s7 >> 24) & 0xFF))
        out.append(UInt8((s7 >> 16) & 0xFF))
        out.append(UInt8((s7 >> 8) & 0xFF))
        out.append(UInt8((s7 >> 0) & 0xFF))

        return out


fn rotr(x: UInt32, n: UInt8) -> UInt32:
    """Rotate right (used in SHA-256)."""
    var n32 = UInt32(n)
    return ((x >> n32) | (x << (32 - n32))) & 0xFFFFFFFF


fn create_pad_blocks_sha256(
    blob: UnsafePointer[UInt8], size: UInt32, offset: UInt32
) -> List[UInt8]:
    """Create padding and size blocks for the message (SHA-256 style)."""
    var remaining_size = Int(size - offset)

    # Calculate total padded size (remaining + 1 byte + padding + 8 bytes for size)
    # Must be multiple of 64 bytes
    var total_with_size = remaining_size + 1 + 8  # +1 for 0x80, +8 for size
    var blocks_needed = (
        total_with_size + 63
    ) // 64  # Round up to nearest block
    var padded_size = blocks_needed * 64
    var zero_pad_count = padded_size - total_with_size

    # Create output buffer
    var result = List[UInt8](capacity=padded_size)

    # Copy remaining data
    for i in range(remaining_size):
        result.append(blob[offset + i])

    # Add mandatory 0x80 byte
    result.append(0x80)

    # Add zero padding
    for _ in range(zero_pad_count):
        result.append(0)

    # Add 64-bit size in big-endian format (size in bits)
    var size_bits = UInt64(size) << 3
    # Big-endian format (most significant byte first)
    for i in range(8):
        result.append(UInt8((size_bits >> ((7 - i) * 8)) & 0xFF))

    return result


fn b2h(input_bytes: Span[Byte]) -> String:
    """Convert a byte array to a hex string."""
    var result = String(capacity=len(input_bytes) * 2)
    var size = len(input_bytes)
    var hex_chars = List[UInt8](
        48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102
    )
    for i in range(size):
        var byte = input_bytes[i]
        var c0 = hex_chars[(byte >> 4) & 0xF]
        var c1 = hex_chars[byte & 0xF]
        result.append_byte(c0)
        result.append_byte(c1)
    return result


fn sha256_hash_span(bytes_ref: Span[UInt8]) raises -> String:
    """Convenience function to hash a string and return hex representation."""
    var obj = SHA256()
    var h = obj.sha256(bytes_ref)
    return b2h(h)


fn sha256_hash(data_str: String) raises -> String:
    """Convenience function to hash a string and return hex representation."""
    var bytes_ref = data_str.as_bytes()
    return sha256_hash_span(bytes_ref)
