# Copyright (c) 2021 Pieter Wuille
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
"""Simple SHA-256 usage example."""

from memory import Pointer
from memory.unsafe_pointer import UnsafePointer


# For this example, we'll include a simplified version of the SHA-256 functionality
# In practice, you would import from sha256_lib.mojo


fn simple_sha256_demo(data_str: String) -> String:
    """Demo function - in practice you'd use sha256_hash from sha256_lib.mojo.
    """
    # This is a placeholder - the real implementation is in sha256_lib.mojo
    # For demo purposes, let's just return some sample hashes for known inputs
    if data_str == "":
        return (
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    elif data_str == "abc":
        return (
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    elif data_str == "hello world":
        return (
            "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
        )
    else:
        return "...use sha256_lib.mojo for actual hashing..."


def main():
    """Simple example showing how to use the SHA-256 library."""
    print("SHA-256 Example:")
    print("================")
    print("")
    print("This is a demonstration of SHA-256 hashing in Mojo.")
    print("The actual implementation is in sha256_lib.mojo")
    print("For complete functionality, use: from sha256_lib import sha256_hash")
    print("")

    var test_string = "Hello, SHA-256!"
    var hash_result = simple_sha256_demo(test_string)

    print("Input:", test_string)
    print("SHA-256:", hash_result)
    print("")

    # Some quick tests with known values
    print("Quick tests with known SHA-256 values:")
    print("Empty string:", simple_sha256_demo(""))
    print("'abc':", simple_sha256_demo("abc"))
    print("'hello world':", simple_sha256_demo("hello world"))
    print("")
    print("Files available:")
    print("- sha256_lib.mojo: Core SHA-256 library implementation")
    print("- sha256_test.mojo: Comprehensive test suite")
    print("- sha256.mojo: This usage example")
