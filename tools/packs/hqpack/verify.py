"""An independent verifier of a text pack directory (docs/CONTENT_PACKS.md).

It shares no code with the writer beyond `errors.py`: everything the app's
manifest parser and its integrity suite check is recomputed here from the
stored bytes. Problems name addresses, numbers, field paths, file names and
code points only, never a text value of the pack.

This module checks the directory, the file and its header and runs the rest:
`verify_manifest`, `verify_database` and `verify_spans`.
"""

from __future__ import annotations

import hashlib
import sqlite3
import struct
from dataclasses import dataclass
from pathlib import Path

from .verify_database import (
    Contents, numbering_problems, reference_problems, schema_problems,
    text_problems)
from .verify_manifest import FORMAT_VERSION, TEXT, read_manifest, safe_name
from .verify_spans import all_span_problems, coverage_problems

MANIFEST = "manifest.json"
SIGNATURE = "manifest.json.sig"
SIGNATURE_BYTES = 64
APPLICATION_ID = 1213288523


@dataclass(frozen=True)
class Report:
    problems: list
    counts: dict | None
    signed: bool


def verify_pack(directory, mark_code_points=None, font=None) -> Report:
    directory = Path(directory)
    problems = []
    if not directory.is_dir():
        return Report(["the pack directory does not exist"], None, False)
    signed = _directory_problems(directory, problems)
    manifest = read_manifest(directory / MANIFEST, problems)
    if manifest is None:
        return Report(problems, None, signed)
    counts = manifest["counts"]
    _location_problems(directory, manifest, problems)
    if font is not None:
        _font_identity_problems(manifest["font"], font, problems)
    text = directory / TEXT
    if not text.is_file() or text.is_symlink():
        problems.append("text.sqlite is missing")
        return Report(problems, counts, signed)
    _file_problems(text, manifest["files"][0], problems)
    if _header_problems(text, problems):
        _database_problems(text, manifest, mark_code_points, font, problems)
    return Report(problems, counts, signed)


def _directory_problems(directory, problems):
    allowed = (MANIFEST, TEXT, SIGNATURE)
    for entry in sorted(directory.iterdir()):
        if entry.name not in allowed:
            problems.append(
                "the pack directory holds an unexpected entry %s"
                % safe_name(entry.name))
        elif entry.is_symlink() or not entry.is_file():
            problems.append("%s is not a regular file" % entry.name)
    signature = directory / SIGNATURE
    if not signature.is_file():
        return False
    size = signature.stat().st_size
    if size != SIGNATURE_BYTES:
        problems.append(
            "manifest.json.sig has %d bytes, not %d" % (size, SIGNATURE_BYTES))
    return True


def _location_problems(directory, manifest, problems):
    parts = directory.resolve().parts
    if len(parts) < 3 or parts[-2] != manifest["id"]:
        problems.append(
            "manifest.id is not the name of the directory above the version "
            "directory")
    if parts[-1] != str(manifest["version"]):
        problems.append(
            "manifest.version %d is not the name of the directory the pack "
            "sits in" % manifest["version"])


def _font_identity_problems(listed, font, problems):
    if font.sha256 != listed["sha256"]:
        problems.append("font.sha256 is not the SHA-256 of the font file")
    if font.family != listed["family"]:
        problems.append("font.family is not the family of the font file")
    if font.version != listed["version"]:
        problems.append("font.version is not the version of the font file")


def _file_problems(path, listed, problems):
    size = path.stat().st_size
    if size != listed["bytes"]:
        problems.append(
            "text.sqlite has %d bytes; files[0].bytes is %d"
            % (size, listed["bytes"]))
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    if digest.hexdigest() != listed["sha256"]:
        problems.append("text.sqlite: SHA-256 differs from files[0].sha256")


def _header_problems(path, problems):
    """False when the file is not SQLite 3 at all."""
    with path.open("rb") as stream:
        header = stream.read(100)
    if len(header) < 100 or not header.startswith(b"SQLite format 3\x00"):
        problems.append("text.sqlite is not an SQLite 3 file")
        return False
    for offset in (18, 19):
        if header[offset] != 1:
            problems.append(
                "text.sqlite: header byte %d is %d, not 1 (journal_mode "
                "DELETE)" % (offset, header[offset]))

    def u32(offset):
        return struct.unpack(">I", header[offset:offset + 4])[0]

    if u32(56) != 1:
        problems.append(
            "text.sqlite: text encoding is %d, not UTF-8 (1)" % u32(56))
    if u32(60) != FORMAT_VERSION:
        problems.append(
            "text.sqlite: user_version is %d, not %d"
            % (u32(60), FORMAT_VERSION))
    if u32(68) != APPLICATION_ID:
        problems.append(
            "text.sqlite: application_id is %d, not %d"
            % (u32(68), APPLICATION_ID))
    if u32(36) != 0:
        problems.append(
            "text.sqlite: %d free pages: the build did not end with VACUUM"
            % u32(36))
    return True


def _database_problems(path, manifest, mark_code_points, font, problems):
    uri = path.resolve().as_uri() + "?mode=ro&immutable=1"
    try:
        connection = sqlite3.connect(uri, uri=True)
    except sqlite3.Error as e:
        problems.append("text.sqlite does not open (%s)" % type(e).__name__)
        return
    try:
        if schema_problems(connection, problems):
            pack = Contents(connection)
            numbering_problems(pack, manifest, problems)
            reference_problems(pack, problems)
            texts = text_problems(pack, manifest, problems)
            all_span_problems(pack, texts, mark_code_points, problems)
            if font is not None:
                coverage_problems(texts, font, problems)
    except sqlite3.Error as e:
        problems.append("text.sqlite cannot be read (%s)" % type(e).__name__)
    finally:
        connection.close()
