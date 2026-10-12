from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from hqpack.errors import PackError
from hqpack.signing import (
    SIGNATURE_FILE,
    OpenSslEd25519Signer,
    sign_pack,
    verify_signature,
)

MANIFEST = b'{\n  "format": "holyquran-pack",\n  "id": "synthetic-text"\n}\n'


class FakeSigner:
    def __init__(self, length=64):
        self.length = length
        self.calls = []

    def sign(self, data: bytes) -> bytes:
        self.calls.append(data)
        return (hashlib.sha512(data).digest() * 2)[: self.length]


def _openssl_has_ed25519() -> bool:
    if shutil.which("openssl") is None:
        return False
    with tempfile.TemporaryDirectory() as work:
        try:
            completed = subprocess.run(
                ["openssl", "genpkey", "-algorithm", "ed25519",
                 "-out", os.path.join(work, "probe.pem")],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        except OSError:
            return False
        return completed.returncode == 0


def _openssl(*arguments):
    subprocess.run(
        ["openssl", *arguments],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True,
    )


class SignPackTest(unittest.TestCase):
    def setUp(self):
        self._work = tempfile.TemporaryDirectory()
        self.pack = Path(self._work.name)
        (self.pack / "manifest.json").write_bytes(MANIFEST)

    def tearDown(self):
        self._work.cleanup()

    def test_writes_exactly_the_signature_of_the_manifest_bytes(self):
        signer = FakeSigner()
        path = sign_pack(self.pack, signer)
        self.assertEqual(path, self.pack / SIGNATURE_FILE)
        self.assertEqual(signer.calls, [MANIFEST])
        self.assertEqual(path.read_bytes(), FakeSigner().sign(MANIFEST))
        self.assertEqual(
            sorted(p.name for p in self.pack.iterdir()),
            ["manifest.json", SIGNATURE_FILE],
        )

    def test_refuses_to_re_sign(self):
        (self.pack / SIGNATURE_FILE).write_bytes(b"x" * 64)
        signer = FakeSigner()
        with self.assertRaises(PackError) as caught:
            sign_pack(self.pack, signer)
        self.assertIn(SIGNATURE_FILE, str(caught.exception))
        self.assertEqual(signer.calls, [])
        self.assertEqual((self.pack / SIGNATURE_FILE).read_bytes(), b"x" * 64)

    def test_refuses_a_missing_manifest(self):
        (self.pack / "manifest.json").unlink()
        with self.assertRaises(PackError) as caught:
            sign_pack(self.pack, FakeSigner())
        self.assertIn("manifest.json", str(caught.exception))
        self.assertEqual(list(self.pack.iterdir()), [])

    def test_refuses_a_signature_of_the_wrong_length(self):
        for length in (0, 63, 65):
            with self.subTest(length=length):
                with self.assertRaises(PackError) as caught:
                    sign_pack(self.pack, FakeSigner(length))
                self.assertIn("%d bytes" % length, str(caught.exception))
                self.assertEqual(
                    [p.name for p in self.pack.iterdir()], ["manifest.json"]
                )

    def test_refuses_a_signature_that_is_not_bytes(self):
        class TextSigner:
            def sign(self, data):
                return "x" * 64

        with self.assertRaises(PackError):
            sign_pack(self.pack, TextSigner())
        self.assertEqual([p.name for p in self.pack.iterdir()], ["manifest.json"])

    def test_messages_are_ascii(self):
        (self.pack / SIGNATURE_FILE).write_bytes(b"x")
        with self.assertRaises(PackError) as caught:
            sign_pack(self.pack, FakeSigner())
        str(caught.exception).encode("ascii")


class VerifySignatureWithoutOpenSslTest(unittest.TestCase):
    def setUp(self):
        self._work = tempfile.TemporaryDirectory()
        self.pack = Path(self._work.name)
        (self.pack / "manifest.json").write_bytes(MANIFEST)

    def tearDown(self):
        self._work.cleanup()

    def test_refuses_a_missing_signature(self):
        with self.assertRaises(PackError) as caught:
            verify_signature(self.pack, self.pack / "public.pem")
        self.assertIn(SIGNATURE_FILE, str(caught.exception))

    def test_reports_openssl_that_cannot_run(self):
        sign_pack(self.pack, FakeSigner())
        missing = str(self.pack / "no-such-openssl")
        with self.assertRaises(PackError) as caught:
            verify_signature(self.pack, self.pack / "public.pem", openssl=missing)
        self.assertNotIn(missing, str(caught.exception))

    def test_signer_reports_openssl_that_cannot_run(self):
        missing = str(self.pack / "no-such-openssl")
        signer = OpenSslEd25519Signer(self.pack / "key.pem", openssl=missing)
        with self.assertRaises(PackError) as caught:
            signer.sign(MANIFEST)
        self.assertNotIn(missing, str(caught.exception))


@unittest.skipUnless(_openssl_has_ed25519(), "openssl with Ed25519 is not available")
class OpenSslRoundTripTest(unittest.TestCase):
    def setUp(self):
        self._work = tempfile.TemporaryDirectory()
        work = Path(self._work.name)
        self.keys = work / "keys"
        self.keys.mkdir()
        self.pack = work / "pack"
        self.pack.mkdir()
        (self.pack / "manifest.json").write_bytes(MANIFEST)
        self.private_key, self.public_key = self._key_pair("a")

    def tearDown(self):
        self._work.cleanup()

    def _key_pair(self, name):
        private_key = self.keys / (name + ".pem")
        public_key = self.keys / (name + ".pub.pem")
        _openssl("genpkey", "-algorithm", "ed25519", "-out", str(private_key))
        _openssl("pkey", "-in", str(private_key), "-pubout", "-out", str(public_key))
        return private_key, public_key

    def test_signs_and_verifies(self):
        path = sign_pack(self.pack, OpenSslEd25519Signer(self.private_key))
        self.assertEqual(len(path.read_bytes()), 64)
        self.assertTrue(verify_signature(self.pack, self.public_key))

    def test_signature_is_deterministic(self):
        signer = OpenSslEd25519Signer(self.private_key)
        self.assertEqual(signer.sign(MANIFEST), signer.sign(MANIFEST))

    def test_a_changed_manifest_byte_fails(self):
        sign_pack(self.pack, OpenSslEd25519Signer(self.private_key))
        changed = bytearray(MANIFEST)
        changed[5] ^= 0x01
        (self.pack / "manifest.json").write_bytes(bytes(changed))
        self.assertFalse(verify_signature(self.pack, self.public_key))

    def test_another_key_fails(self):
        sign_pack(self.pack, OpenSslEd25519Signer(self.private_key))
        _, other_public_key = self._key_pair("b")
        self.assertFalse(verify_signature(self.pack, other_public_key))

    def test_a_truncated_signature_fails(self):
        path = sign_pack(self.pack, OpenSslEd25519Signer(self.private_key))
        path.write_bytes(path.read_bytes()[:63])
        self.assertFalse(verify_signature(self.pack, self.public_key))

    def test_an_unreadable_public_key_is_an_error(self):
        sign_pack(self.pack, OpenSslEd25519Signer(self.private_key))
        with self.assertRaises(PackError) as caught:
            verify_signature(self.pack, self.keys / "missing.pem")
        self.assertNotIn("missing.pem", str(caught.exception))

    def test_an_unreadable_private_key_is_an_error(self):
        signer = OpenSslEd25519Signer(self.keys / "missing.pem")
        with self.assertRaises(PackError) as caught:
            signer.sign(MANIFEST)
        self.assertIn("exit code", str(caught.exception))
        self.assertNotIn("missing.pem", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
