from memory import UnsafePointer, Span
from collections import List
from vangen_mojo.sha256_gpu import sha256_gpu_kernel
from vangen_mojo.ripemd160_gpu import ripemd160_gpu_kernel

# Back to GPU-optimized version now that we've verified correctness
fn hash160_span_gpu_optimized(blob: Span[UInt8], out_buffer: UnsafePointer[UInt8]) -> None:
    """GPU-optimized hash160 using stack-only allocations - should match original exactly."""
    
    # Stack-allocated buffers - no heap allocation!
    var sha_result = InlineArray[UInt8, 32](0)  # SHA256 output
    
    # Compute SHA256 directly to stack buffer
    sha256_gpu_kernel(blob, sha_result.unsafe_ptr())
    
    # Compute RIPEMD160 directly to output buffer
    var sha_span = Span[UInt8](sha_result.unsafe_ptr(), 32)
    ripemd160_gpu_kernel(sha_span, out_buffer)

# GPU-optimized input generation with fixed-size buffer
fn input_for_index_gpu(i: Int, hex_prefix: Span[UInt8], out_buffer: UnsafePointer[UInt8]) -> Int:
    """Generate input data directly into pre-allocated buffer. Returns total size."""
    var prefix_len = len(hex_prefix)
    
    # Copy prefix manually (no memcpy needed)
    for j in range(prefix_len):
        out_buffer[j] = hex_prefix[j]
    
    # Add 8-byte integer in big-endian format
    var offset = prefix_len
    out_buffer[offset + 0] = UInt8((i >> 56) & 0xFF)
    out_buffer[offset + 1] = UInt8((i >> 48) & 0xFF)
    out_buffer[offset + 2] = UInt8((i >> 40) & 0xFF)
    out_buffer[offset + 3] = UInt8((i >> 32) & 0xFF)
    out_buffer[offset + 4] = UInt8((i >> 24) & 0xFF)
    out_buffer[offset + 5] = UInt8((i >> 16) & 0xFF)
    out_buffer[offset + 6] = UInt8((i >> 8) & 0xFF)
    out_buffer[offset + 7] = UInt8(i & 0xFF)
    
    return prefix_len + 8
