"""The signing seam (D-080): `manifest.json.sig` is the raw 64-byte Ed25519
signature (RFC 8032) of the exact bytes of `manifest.json`.

Who holds the key and where signing runs is undecided (D-024, O-03), so the
signer is a protocol and the one implementation calls OpenSSL 3. An unsigned
pack is one without the signature file; the manifest has no field for it.
OpenSSL's output is captured and dropped so that no path or key detail reaches
a log.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path
from typing import Protocol

from .errors import PackError

SIGNATURE_FILE = "manifest.json.sig"
MANIFEST_FILE = "manifest.json"
SIGNATURE_LENGTH = 64

_VERIFIED = b"Signature Verified Successfully"
_NOT_VERIFIED = b"Signature Verification Failure"


class Signer(Protocol):
    def sign(self, data: bytes) -> bytes:
        """The raw 64-byte Ed25519 signature of exactly [data]."""
        ...


class OpenSslEd25519Signer:
    def __init__(self, key_path, openssl="openssl"):
        self._key_path = str(key_path)
        self._openssl = openssl

    def sign(self, data: bytes) -> bytes:
        with tempfile.TemporaryDirectory() as work:
            data_path = os.path.join(work, "data")
            signature_path = os.path.join(work, "signature")
            with open(data_path, "wb") as f:
                f.write(data)
            _run(
                [
                    self._openssl, "pkeyutl", "-sign", "-rawin",
                    "-inkey", self._key_path,
                    "-in", data_path,
                    "-out", signature_path,
                ],
                "signing",
                require_success=True,
            )
            with open(signature_path, "rb") as f:
                return f.read()


def sign_pack(directory, signer) -> Path:
    """Writes `manifest.json.sig` beside the manifest; never re-signs a pack."""
    directory = Path(directory)
    manifest = directory / MANIFEST_FILE
    target = directory / SIGNATURE_FILE
    if os.path.lexists(target):
        raise PackError(
            "%s already exists; a released pack is never re-signed in place"
            % SIGNATURE_FILE
        )
    if not manifest.is_file():
        raise PackError("%s is missing" % MANIFEST_FILE)
    signature = signer.sign(manifest.read_bytes())
    if not isinstance(signature, bytes) or len(signature) != SIGNATURE_LENGTH:
        length = len(signature) if isinstance(signature, bytes) else -1
        raise PackError(
            "the signer returned %d bytes; an Ed25519 signature is %d"
            % (length, SIGNATURE_LENGTH)
        )
    _write_atomically(target, signature)
    return target


def verify_signature(directory, public_key_path, openssl="openssl") -> bool:
    """True when `manifest.json.sig` is a valid signature of the manifest's bytes."""
    directory = Path(directory)
    manifest = directory / MANIFEST_FILE
    signature = directory / SIGNATURE_FILE
    if not signature.is_file():
        raise PackError("%s is missing" % SIGNATURE_FILE)
    if not manifest.is_file():
        raise PackError("%s is missing" % MANIFEST_FILE)
    if signature.stat().st_size != SIGNATURE_LENGTH:
        return False
    stdout = _run(
        [
            openssl, "pkeyutl", "-verify", "-pubin",
            "-inkey", str(public_key_path),
            "-rawin",
            "-in", str(manifest),
            "-sigfile", str(signature),
        ],
        "signature verification",
        require_success=False,
    )
    if _VERIFIED in stdout:
        return True
    if _NOT_VERIFIED in stdout:
        return False
    raise PackError("openssl could not verify the signature")


def _run(command, what, require_success):
    try:
        completed = subprocess.run(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError:
        raise PackError("openssl could not be run for %s" % what) from None
    if completed.returncode != 0 and (
        require_success or _NOT_VERIFIED not in completed.stdout
    ):
        raise PackError(
            "openssl %s failed with exit code %d" % (what, completed.returncode)
        )
    return completed.stdout


def _write_atomically(target: Path, data: bytes) -> None:
    descriptor, temporary = tempfile.mkstemp(
        dir=str(target.parent), prefix="." + target.name + ".", suffix=".tmp"
    )
    try:
        with os.fdopen(descriptor, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, str(target))
    except BaseException:
        if os.path.exists(temporary):
            os.remove(temporary)
        raise
