# Mojo Vanity Bitcoin Address Generator

A high-performance Bitcoin vanity address generator built with Mojo, demonstrating GPU acceleration for cryptographic hash operations.

## Project Overview

This hackathon project explores building a Bitcoin vanity address generator using Mojo's GPU capabilities. A vanity address is a Bitcoin address with a recognizable pattern or prefix, which requires significant computational effort to find through brute force searching.

**Key Achievement**: Successfully implemented GPU-accelerated hash searching with significant performance improvements over CPU-only implementations.

## What's Implemented

### Core Hash Pipeline
- **Hash160 Implementation**: Complete SHA-256 + RIPEMD-160 hashing pipeline in both CPU and GPU versions
- **GPU Optimization**: Highly optimized CUDA kernels targeting NVIDIA A6000 architecture (10,752 cores)
- **Memory Efficiency**: Stack-allocated buffers and bit arrays to minimize GPU memory overhead
- **Consistency Testing**: Built-in verification that CPU and GPU implementations produce identical results

### Performance Features
- **Dual Processing Modes**: Both CPU and GPU implementations for comparison
- **Optimized Thread Distribution**: Sophisticated workload balancing across GPU cores
- **SIMD Vectorization**: Leverages Mojo's SIMD capabilities for performance
- **Modern Mojo Features**: Uses cutting-edge Mojo 25.4 syntax including origin tracking and span operations

### Benchmarking
The main benchmark (`go.py`) tests both implementations with:
- **Workload**: ~67 million hash operations (2^26)
- **Pattern Matching**: Searches for specific hex prefixes in hash outputs
- **Performance Comparison**: Direct CPU vs GPU timing with speedup calculations

## What's Missing (The ECDSA Punt)

The original goal was to implement a complete Bitcoin vanity address generator, which requires:

1. **Private Key Generation** ✅ (Input parameter)
2. **ECDSA Public Key Derivation** ❌ **PUNTED**
3. **Hash160 (SHA-256 + RIPEMD-160)** ✅ **IMPLEMENTED**
4. **Base58/Bech32 Encoding** ❌ **PUNTED**
5. **Pattern Matching** ✅ **IMPLEMENTED**

**Why the punt?** Implementing secp256k1 elliptic curve operations (the ECDSA part) in Mojo would have been a significant undertaking requiring:
- Complex modular arithmetic operations
- Elliptic curve point addition and multiplication
- Proper handling of edge cases and security considerations

Instead, this project focuses on demonstrating Mojo's GPU acceleration capabilities on the computationally intensive hash search portion of the pipeline.

## Current Architecture

```
Input: Integer index + hex prefix
    ↓
Generate test input (simplified - skips ECDSA)
    ↓
Hash160 (SHA-256 + RIPEMD-160) ← GPU ACCELERATED
    ↓
Pattern matching against target prefix
    ↓
Output: Matching indices
```

## Performance Results

The GPU implementation shows significant speedup over CPU for the hash-intensive workload:
- **GPU Version**: Utilizes full A6000 capacity with optimized CUDA kernels
- **CPU Version**: Multi-threaded implementation for comparison
- **Measurable Speedup**: Direct timing comparison shows GPU acceleration benefits

## Technical Highlights

### GPU Optimization Strategy
- **Full Hardware Utilization**: Optimized for 100% A6000 GPU utilization
- **Memory Management**: Stack-allocated buffers to avoid GPU memory allocation overhead
- **Thread Scaling**: Dynamic thread count adjustment based on workload size
- **Architecture-Specific**: Tuned block sizes and grid dimensions for Ampere architecture

### Modern Mojo Usage
- **GPU Intrinsics**: Direct use of CUDA operations through Mojo's GPU module
- **Memory Safety**: Leverages Mojo's origin tracking and span types
- **Python Interop**: Exposes Mojo functions to Python for easy benchmarking
- **Performance Primitives**: Uses `UnsafePointer`, `InlineArray`, and other zero-cost abstractions

## Usage

```bash
# Run the benchmark
git clone https://github.com/richardkiss/vangen
cd vangen
uv venv
uv sync
source .venv/bin/activate
sh build.sh
python go.py
```

This will execute both CPU and GPU versions of the hash search and report timing results.

## Project Structure

- `vangen_mojo/` - Main Mojo implementation with GPU kernels
- `go.py` - Benchmarking script
- `pyproject.toml` - Project configuration
- `build.sh` - Build script for Mojo module

## Lessons Learned

1. **Mojo's GPU capabilities** are powerful for compute-intensive workloads
2. **Memory management** is crucial for GPU performance - avoiding allocations in hot paths
3. **Incremental optimization** approach works well - can compare CPU vs GPU implementations
4. **Modern Mojo syntax** provides excellent low-level control while maintaining safety

## Future Work

To complete the full vanity address generator:
1. Implement secp256k1 elliptic curve operations
2. Add Base58Check encoding for proper Bitcoin addresses
3. Integrate the full pipeline from private key to final address
4. Add support for different address formats (P2PKH, P2SH, Bech32)

This project successfully demonstrates Mojo's potential for high-performance cryptographic computing, even if it doesn't implement every piece of the Bitcoin address generation puzzle.
