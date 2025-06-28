import argparse

# monkey-patch due to bug
import pycoin.ecdsa.native.openssl

pycoin.ecdsa.native.openssl.load_library = lambda *args: None

from pycoin.encoding.hash import hash160
from pycoin.ecdsa.secp256k1 import secp256k1_generator
from pycoin.networks.registry import network_for_netcode


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


def compute_bitcoin_address(private_key: int, network) -> str:
    """Compute the Bitcoin address from a private key."""
    # Generate the public pair (x, y) from the private key
    public_pair = secp256k1_generator * private_key

    # Convert the public pair into compressed byte form
    public_key_bytes = public_pair_to_bytes(public_pair)

    # Generate the hash160 (RIPEMD-160(SHA-256(public_key_bytes)))
    h160 = hash160(public_key_bytes)

    # Compute the Bitcoin address (P2PKH format)
    bitcoin_address = network.address.for_p2pkh(h160)

    return bitcoin_address


def main() -> None:
    """Main function to execute the tool."""
    args = parse_arguments()
    initial_key: int = args.initial_key
    count: int = args.count

    # Get the default Bitcoin network
    network = network_for_netcode("BTC")

    # Generate and print addresses for the range
    for i in range(initial_key, initial_key + count):
        address = compute_bitcoin_address(i, network)
        print(address)


if __name__ == "__main__":
    main()
