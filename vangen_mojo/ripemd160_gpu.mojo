# GPU-optimized RIPEMD160 implementation - faithful to original algorithm
# Eliminates dynamic memory allocations while preserving exact algorithm

from memory import UnsafePointer, Span

struct RipeMD160_GPU:
    var ML: InlineArray[UInt8, 80]
    var MR: InlineArray[UInt8, 80]
    var RL: InlineArray[UInt8, 80]
    var RR: InlineArray[UInt8, 80]
    var KL: InlineArray[UInt32, 5]
    var KR: InlineArray[UInt32, 5]

    fn __init__(out self):
        # Message schedule indexes for the left path - copied exactly from original
        self.ML = InlineArray[UInt8, 80](
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
            7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
            3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
            1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
            4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13,
        )

        # Message schedule indexes for the right path - copied exactly from original
        self.MR = InlineArray[UInt8, 80](
            5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
            6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
            15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
            8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
            12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11,
        )

        # Rotation amounts for left path - copied exactly from original
        self.RL = InlineArray[UInt8, 80](
            11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
            7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
            11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
            11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
            9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6,
        )

        # Rotation amounts for right path - copied exactly from original
        self.RR = InlineArray[UInt8, 80](
            8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
            9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
            9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
            15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
            8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11,
        )

        # Round constants - copied exactly from original
        self.KL = InlineArray[UInt32, 5](
            0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E
        )
        self.KR = InlineArray[UInt32, 5](
            0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000
        )

    fn ripemd160_to_buffer_gpu(self, data: Span[UInt8], out_buffer: UnsafePointer[UInt8]) -> None:
        """GPU-optimized RIPEMD160 that writes directly to buffer - exact algorithm."""
        
        var size = len(data)
        # Initialize hash values
        var h0: UInt32 = 0x67452301
        var h1: UInt32 = 0xEFCDAB89
        var h2: UInt32 = 0x98BADCFE
        var h3: UInt32 = 0x10325476
        var h4: UInt32 = 0xC3D2E1F0

        var u_data = data.unsafe_ptr()
        
        # Process full 64-byte blocks
        var full_blocks = size >> 6
        for b in range(full_blocks):
            var p1 = u_data + b * 64
            var result = self.compress_gpu(h0, h1, h2, h3, h4, p1)
            h0 = result[0]; h1 = result[1]; h2 = result[2]; h3 = result[3]; h4 = result[4]

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
        
        # Add size in bits as little-endian 64-bit integer (RIPEMD160 uses little-endian)
        var size_bits = UInt64(size) << 3
        var size_offset = padded_size - 8
        for i in range(8):
            final_block[size_offset + i] = UInt8((size_bits >> (i * 8)) & 0xFF)
        
        # Process final blocks
        for b in range(blocks_needed):
            var block_ptr = final_block.unsafe_ptr() + b * 64
            var result = self.compress_gpu(h0, h1, h2, h3, h4, block_ptr)
            h0 = result[0]; h1 = result[1]; h2 = result[2]; h3 = result[3]; h4 = result[4]

        # Write output directly to buffer (20 bytes, little-endian)
        write_u32_le(out_buffer + 0, h0);   write_u32_le(out_buffer + 4, h1)
        write_u32_le(out_buffer + 8, h2);   write_u32_le(out_buffer + 12, h3)
        write_u32_le(out_buffer + 16, h4)

    fn compress_gpu(
        self, h0: UInt32, h1: UInt32, h2: UInt32, h3: UInt32, h4: UInt32,
        block: UnsafePointer[UInt8]
    ) -> Tuple[UInt32, UInt32, UInt32, UInt32, UInt32]:
        """GPU-optimized RIPEMD160 compression - faithful to original algorithm."""
        
        # Convert block to little-endian 32-bit words
        var w = InlineArray[UInt32, 16](UInt32(0))
        var x = block.bitcast[UInt32]()
        
        # Copy words (assume little-endian system)
        for i in range(16):
            w[i] = x[i]

        # Initialize working variables for left and right lines
        var al = h0; var bl = h1; var cl = h2; var dl = h3; var el = h4
        var ar = h0; var br = h1; var cr = h2; var dr = h3; var er = h4

        # 80 rounds - exact algorithm from original
        for j in range(80):
            # Left line
            var t = al + f_rmd(j, bl, cl, dl) + w[Int(self.ML[j])] + self.KL[j // 16]
            t = rotl_gpu(t, self.RL[j]) + el
            al = el; el = dl; dl = rotl_gpu(cl, 10); cl = bl; bl = t

            # Right line
            t = ar + f_rmd(79 - j, br, cr, dr) + w[Int(self.MR[j])] + self.KR[j // 16]
            t = rotl_gpu(t, self.RR[j]) + er
            ar = er; er = dr; dr = rotl_gpu(cr, 10); cr = br; br = t

        # Combine results
        var t = h1 + cl + dr
        return (t, h0 + dl + er, h2 + el + ar, h3 + al + br, h4 + bl + cr)

@always_inline
fn f_rmd(j: Int, x: UInt32, y: UInt32, z: UInt32) -> UInt32:
    """RIPEMD160 selection functions - exact from original."""
    if j < 16:
        return x ^ y ^ z
    elif j < 32:
        return (x & y) | ((~x) & z)
    elif j < 48:
        return (x | (~y)) ^ z
    elif j < 64:
        return (x & z) | (y & (~z))
    else:
        return x ^ (y | (~z))

@always_inline
fn rotl_gpu(x: UInt32, n: UInt8) -> UInt32:
    """GPU-optimized rotate left."""
    var n32 = UInt32(n)
    return ((x << n32) | (x >> (32 - n32))) & 0xFFFFFFFF

@always_inline 
fn write_u32_le(ptr: UnsafePointer[UInt8], value: UInt32) -> None:
    """Write 32-bit value in little-endian format."""
    ptr[0] = UInt8(value & 0xFF)
    ptr[1] = UInt8((value >> 8) & 0xFF)
    ptr[2] = UInt8((value >> 16) & 0xFF) 
    ptr[3] = UInt8((value >> 24) & 0xFF)

# Convenience function for GPU kernels
fn ripemd160_gpu_kernel(data: Span[UInt8], out_buffer: UnsafePointer[UInt8]) -> None:
    """Single function call for GPU kernels."""
    var hasher = RipeMD160_GPU()
    hasher.ripemd160_to_buffer_gpu(data, out_buffer)
