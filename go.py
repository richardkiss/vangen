import max.mojo.importer
import sys

sys.path.insert(0, "")
import vangen_mojo

import time


def timeit(f):
    now = time.time()
    r = f()
    elapsed = time.time() - now
    print(f"Elapsed: {elapsed:.2f} seconds")
    return r


def main():
    start = 10000
    size = 1 << 24
    prefix_hex = "3400000000000010"
    match_hex = "5282" #21"


    print("Starting matching hashes for range GPU...")
    r = timeit(
        lambda: vangen_mojo.matching_hashes_for_range_gpu(
            start, size, prefix_hex, match_hex
        )
    )
    print(f"r={r}")

    print("Starting matching hashes for range...")
    r = timeit(
        lambda: vangen_mojo.matching_hashes_for_range(
            start, size, prefix_hex, match_hex
        )
    )
    print(f"r={r}")


if __name__ == "__main__":
    main()
