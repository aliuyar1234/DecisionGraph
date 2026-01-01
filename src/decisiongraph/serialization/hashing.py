"""SHA-256 hashing utilities per SSOT DD-008."""

import hashlib


def sha256_hex(data: bytes) -> str:
    """Compute SHA-256 hash as hex string.

    Args:
        data: Bytes to hash

    Returns:
        Lowercase hex string of SHA-256 hash
    """
    return hashlib.sha256(data).hexdigest()


def sha256_prefixed(data: bytes) -> str:
    """Compute SHA-256 hash with 'sha256:' prefix.

    Args:
        data: Bytes to hash

    Returns:
        String in format "sha256:<hex>"
    """
    return f"sha256:{sha256_hex(data)}"


__all__ = ["sha256_hex", "sha256_prefixed"]
