"""The surah digest of docs/CONTENT_PACKS.md, and file hashes."""

from __future__ import annotations

import hashlib
import struct

_CHUNK = 1 << 16


def surah_digest(fields) -> str:
    """SHA-256 over `u32be(number) || u32be(byte_length) || bytes` per field.

    The caller passes the basmala first as field 0 when the surah has one
    (an empty one counts), then every ayah with its number.
    """
    h = hashlib.sha256()
    for number, data in fields:
        h.update(struct.pack(">II", number, len(data)))
        h.update(data)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(_CHUNK), b""):
            h.update(chunk)
    return h.hexdigest()
