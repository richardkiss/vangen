import pycoin.ecdsa.native.openssl

pycoin.ecdsa.native.openssl.load_library = lambda *args: None

import argparse
import hashlib
import sys

from pycoin.ecdsa.secp256k1 import secp256k1_generator

import max.mojo.importer

sys.path.insert(0, "")

from vangen_mojo import hash160


BASE58_ALPHABET = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
BASE58_BASE = len(BASE58_ALPHABET)
BASE58_LOOKUP = dict((c, i) for i, c in enumerate(BASE58_ALPHABET))


def b2a_base58(s):
    """Convert binary to base58 using BASE58_ALPHABET."""
    num = int.from_bytes(s, "big")
    encode = bytearray()
    while num:
        num, mod = divmod(num, BASE58_BASE)
        encode.append(BASE58_ALPHABET[mod])
    encode.reverse()
    # Add '1' for each leading 0 byte
    for byte in s:
        if byte == 0:
            encode.insert(0, BASE58_ALPHABET[0])
        else:
            break
    return encode.decode("ascii")


def double_sha256(data):
    """Returns the double SHA-256 hash of the input data."""
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def b2a_hashed_base58(data):
    """
    A "hashed_base58" structure is a base58 integer with four bytes of hash
    data at the end.

    This function turns data (of type "bytes") into its hashed_base58 equivalent.
    """
    return b2a_base58(data + double_sha256(data)[:4])


def parse_arguments() -> argparse.Namespace:
    """Parses command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate Bitcoin addresses for a range of keys."
    )

    parser.add_argument(
        "initial_key", type=int, help="The initial private key to start the range."
    )

    parser.add_argument("count", type=int, help="The number of addresses to generate.")

    return parser.parse_args()


def public_pair_to_bytes(public_pair: tuple, compressed: bool = True) -> bytes:
    """Convert a public pair (x, y) to its SEC byte encoding."""
    x, y = public_pair
    if compressed:
        prefix = b"\x02" if (y % 2 == 0) else b"\x03"
        return prefix + x.to_bytes(32, byteorder="big")
    else:
        prefix = b"\x04"
        return (
            prefix + x.to_bytes(32, byteorder="big") + y.to_bytes(32, byteorder="big")
        )


def compute_bitcoin_address(private_key: int) -> str:
    """Compute the Bitcoin address from a private key."""
    # Generate the public pair (x, y) from the private key
    public_pair = secp256k1_generator * private_key

    # Convert the public pair into compressed byte form
    public_key_bytes = public_pair_to_bytes(public_pair)

    # Generate the hash160 (RIPEMD-160(SHA-256(public_key_bytes)))
    h160 = hash160(public_key_bytes)

    # Compute the Bitcoin address (P2PKH format)
    bitcoin_address = b2a_hashed_base58(b"\x00" + h160)

    return bitcoin_address


def main() -> None:
    """Main function to execute the tool."""
    args = parse_arguments()
    initial_key: int = args.initial_key
    count: int = args.count

    # Generate and print addresses for the range
    for i in range(initial_key, initial_key + count):
        address = compute_bitcoin_address(i)
        print(address)


if __name__ == "__main__":
    main()
