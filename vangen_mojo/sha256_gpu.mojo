# GPU-optimized SHA-256 implementation
# Eliminates all dynamic memory allocations for maximum GPU performance

from memory import UnsafePointer, Span, memset_zero

struct SHA256_GPU:
    var K: InlineArray[UInt32, 64]  # Round constants

    fn __init__(out self):
        # SHA-256 round constants - same as original
        self.K = InlineArray[UInt32, 64](
            0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
            0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
            0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
            0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
            0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
            0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
            0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
            0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
            0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
            0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
            0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
            0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
            0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
            0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
            0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
            0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
        )

    fn compress_gpu(
        self,
        mut h0: UInt32, mut h1: UInt32, mut h2: UInt32, mut h3: UInt32,
        mut h4: UInt32, mut h5: UInt32, mut h6: UInt32, mut h7: UInt32,
        block: UnsafePointer[UInt8],
    ) -> Tuple[UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32]:
        """GPU-optimized compression function - no exceptions, stack-only."""
        
        # Use stack-allocated array instead of dynamic allocation
        var w = InlineArray[UInt32, 64](UInt32(0))
        var x = block.bitcast[UInt32]()

        # Copy and convert to big-endian - optimized for GPU performance
        for i in range(16):
            var word = x[i]
            w[i] = ((word & 0xFF) << 24) | (((word >> 8) & 0xFF) << 16) | 
                   (((word >> 16) & 0xFF) << 8) | ((word >> 24) & 0xFF)

        # Extend message schedule - optimized for GPU
        for i in range(16, 64):
            var s0 = rotr_gpu(w[i - 15], 7) ^ rotr_gpu(w[i - 15], 18) ^ (w[i - 15] >> 3)
            var s1 = rotr_gpu(w[i - 2], 17) ^ rotr_gpu(w[i - 2], 19) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] + s0 + w[i - 7] + s1

        # Initialize working variables
        var a = h0; var b = h1; var c = h2; var d = h3
        var e = h4; var f = h5; var g = h6; var h = h7

        # Main compression loop - optimized for GPU performance
        for i in range(64):
            var S1 = rotr_gpu(e, 6) ^ rotr_gpu(e, 11) ^ rotr_gpu(e, 25)
            var ch = (e & f) ^ ((~e) & g)
            var temp1 = h + S1 + ch + self.K[i] + w[i]
            var S0 = rotr_gpu(a, 2) ^ rotr_gpu(a, 13) ^ rotr_gpu(a, 22)
            var maj = (a & b) ^ (a & c) ^ (b & c)
            var temp2 = S0 + maj

            h = g; g = f; f = e; e = d + temp1
            d = c; c = b; b = a; a = temp1 + temp2

        return (h0 + a, h1 + b, h2 + c, h3 + d, h4 + e, h5 + f, h6 + g, h7 + h)

    fn sha256_to_buffer_gpu(self, data: Span[UInt8], out_buffer: UnsafePointer[UInt8]) -> None:
        """GPU-optimized SHA256 that writes directly to buffer - no allocations."""
        
        var size = len(data)
        # Initialize hash values
        var s0: UInt32 = 0x6A09E667; var s1: UInt32 = 0xBB67AE85
        var s2: UInt32 = 0x3C6EF372; var s3: UInt32 = 0xA54FF53A  
        var s4: UInt32 = 0x510E527F; var s5: UInt32 = 0x9B05688C
        var s6: UInt32 = 0x1F83D9AB; var s7: UInt32 = 0x5BE0CD19

        var u_data = data.unsafe_ptr()
        
        # Process full 64-byte blocks
        var full_blocks = size >> 6
        for b in range(full_blocks):
            var p1 = u_data + b * 64
            var result = self.compress_gpu(s0, s1, s2, s3, s4, s5, s6, s7, p1)
            s0 = result[0]; s1 = result[1]; s2 = result[2]; s3 = result[3]
            s4 = result[4]; s5 = result[5]; s6 = result[6]; s7 = result[7]

        # Handle final block with padding - use stack buffer
        var final_block = InlineArray[UInt8, 128](0)  # Max 2 blocks needed
        var remaining_size = size - (full_blocks * 64)
        
        # Copy remaining data
        for i in range(remaining_size):
            final_block[i] = u_data[full_blocks * 64 + i]
        
        # Add padding
        final_block[remaining_size] = 0x80
        
        # Calculate where to put size (last 8 bytes)
        var total_with_size = remaining_size + 1 + 8
        var blocks_needed = (total_with_size + 63) // 64
        var padded_size = blocks_needed * 64
        
        # Add size in bits as big-endian 64-bit integer
        var size_bits = UInt64(size) << 3
        var size_offset = padded_size - 8
        for i in range(8):
            final_block[size_offset + i] = UInt8((size_bits >> ((7 - i) * 8)) & 0xFF)
        
        # Process final blocks
        for b in range(blocks_needed):
            var block_ptr = final_block.unsafe_ptr() + b * 64
            var result = self.compress_gpu(s0, s1, s2, s3, s4, s5, s6, s7, block_ptr)
            s0 = result[0]; s1 = result[1]; s2 = result[2]; s3 = result[3]
            s4 = result[4]; s5 = result[5]; s6 = result[6]; s7 = result[7]

        # Write output directly to buffer (32 bytes, big-endian)
        write_u32_be(out_buffer + 0, s0);   write_u32_be(out_buffer + 4, s1)
        write_u32_be(out_buffer + 8, s2);   write_u32_be(out_buffer + 12, s3)
        write_u32_be(out_buffer + 16, s4);  write_u32_be(out_buffer + 20, s5)
        write_u32_be(out_buffer + 24, s6);  write_u32_be(out_buffer + 28, s7)

@always_inline
fn rotr_gpu(x: UInt32, n: UInt8) -> UInt32:
    """GPU-optimized rotate right."""
    var n32 = UInt32(n)
    return ((x >> n32) | (x << (32 - n32))) & 0xFFFFFFFF

@always_inline 
fn write_u32_be(ptr: UnsafePointer[UInt8], value: UInt32) -> None:
    """Write 32-bit value in big-endian format."""
    ptr[0] = UInt8((value >> 24) & 0xFF)
    ptr[1] = UInt8((value >> 16) & 0xFF) 
    ptr[2] = UInt8((value >> 8) & 0xFF)
    ptr[3] = UInt8(value & 0xFF)

# Convenience function for GPU kernels
fn sha256_gpu_kernel(data: Span[UInt8], out_buffer: UnsafePointer[UInt8]) -> None:
    """Single function call for GPU kernels - no exceptions, no allocations."""
    var hasher = SHA256_GPU()
    hasher.sha256_to_buffer_gpu(data, out_buffer)
