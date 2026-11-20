"""An independent verifier of a text pack directory (docs/CONTENT_PACKS.md).

It shares no code with the writer beyond `errors.py`: everything the app's
manifest parser and its integrity suite check is recomputed here from the
stored bytes. Problems name addresses, numbers, field paths, file names and
code points only, never a text value of the pack.

This module checks the directory, the file and its header and runs the rest:
`verify_manifest`, `verify_database` and `verify_spans`. Its directory, file
and header checks serve every kind; `pack_kind` tells the command line which
verifier a pack needs. A text pack of format 3 stores its text with its
presentation (D-198 Q4); its spans are recomputed from the presentation rules
of the table of known differences, so it is verified with them.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
import struct
from dataclasses import dataclass
from pathlib import Path

from .verify_database import (
    Contents, numbering_problems, reference_problems, schema_problems,
    text_problems)
from .verify_manifest import PRESENTED_FORMAT_VERSION, TEXT, read_manifest, safe_name
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


def verify_pack(directory, mark_code_points=None, font=None, presentation=None) -> Report:
    """`presentation` (known_differences.presentation of the table) checks
    the spans of a pack of format 3; format 1 has none and ignores it."""
    directory = Path(directory)
    problems = []
    if not directory.is_dir():
        return Report(["the pack directory does not exist"], None, False)
    signed = directory_problems(directory, TEXT, problems)
    manifest = read_manifest(directory / MANIFEST, problems)
    if manifest is None:
        return Report(problems, None, signed)
    counts = manifest["counts"]
    location_problems(directory, manifest, problems)
    if font is not None:
        _font_identity_problems(manifest["font"], font, problems)
    text = directory / TEXT
    if not text.is_file() or text.is_symlink():
        problems.append("text.sqlite is missing")
        return Report(problems, counts, signed)
    file_problems(text, manifest["files"][0], problems)
    if header_problems(text, manifest["format_version"], problems):
        _database_problems(
            text, manifest, mark_code_points, font, presentation, problems)
    return Report(problems, counts, signed)


def pack_kind(directory):
    """The manifest's `kind` when manifest.json is a JSON object with a
    string kind, else None; the verifier of that kind checks the rest."""
    kind = _peek(directory).get("kind")
    return kind if isinstance(kind, str) else None


def pack_format_version(directory):
    """The manifest's `format_version` when manifest.json is a JSON object
    with an integer one, else None; the verifier checks the rest."""
    version = _peek(directory).get("format_version")
    return version if type(version) is int else None


def _peek(directory):
    """manifest.json as a JSON object, or {} when it is none, so that a
    command can choose its checks before the verifier reads it strictly."""
    try:
        manifest = json.loads(
            (Path(directory) / MANIFEST).read_bytes().decode("utf-8"))
    except (OSError, ValueError):
        return {}
    return manifest if isinstance(manifest, dict) else {}


def directory_problems(directory, data_file, problems):
    """True when the pack carries a signature file."""
    allowed = (MANIFEST, data_file, SIGNATURE)
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


def location_problems(directory, manifest, problems):
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


def file_problems(path, listed, problems):
    size = path.stat().st_size
    if size != listed["bytes"]:
        problems.append(
            "%s has %d bytes; files[0].bytes is %d"
            % (path.name, size, listed["bytes"]))
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    if digest.hexdigest() != listed["sha256"]:
        problems.append("%s: SHA-256 differs from files[0].sha256" % path.name)


def header_problems(path, user_version, problems):
    """False when the file is not SQLite 3 at all."""
    name = path.name
    with path.open("rb") as stream:
        header = stream.read(100)
    if len(header) < 100 or not header.startswith(b"SQLite format 3\x00"):
        problems.append("%s is not an SQLite 3 file" % name)
        return False
    for offset in (18, 19):
        if header[offset] != 1:
            problems.append(
                "%s: header byte %d is %d, not 1 (journal_mode "
                "DELETE)" % (name, offset, header[offset]))

    def u32(offset):
        return struct.unpack(">I", header[offset:offset + 4])[0]

    if u32(56) != 1:
        problems.append(
            "%s: text encoding is %d, not UTF-8 (1)" % (name, u32(56)))
    if u32(60) != user_version:
        problems.append(
            "%s: user_version is %d, not %d" % (name, u32(60), user_version))
    if u32(68) != APPLICATION_ID:
        problems.append(
            "%s: application_id is %d, not %d"
            % (name, u32(68), APPLICATION_ID))
    if u32(36) != 0:
        problems.append(
            "%s: %d free pages: the build did not end with VACUUM"
            % (name, u32(36)))
    return True


def _database_problems(path, manifest, mark_code_points, font, presentation,
                       problems):
    version = manifest["format_version"]
    presented = version == PRESENTED_FORMAT_VERSION
    if presented and presentation is None:
        problems.append(
            "text.sqlite of format %d stores its text with its presentation; "
            "its spans are checked only with the presentation rules of the "
            "table of known differences" % version)
    uri = path.resolve().as_uri() + "?mode=ro&immutable=1"
    try:
        connection = sqlite3.connect(uri, uri=True)
    except sqlite3.Error as e:
        problems.append("text.sqlite does not open (%s)" % type(e).__name__)
        return
    try:
        if schema_problems(connection, problems, version):
            pack = Contents(connection, version)
            numbering_problems(pack, manifest, problems)
            reference_problems(pack, problems)
            texts = text_problems(pack, manifest, problems)
            if not presented:
                all_span_problems(pack, texts, mark_code_points, problems)
            elif presentation is not None:
                all_span_problems(
                    pack, texts, mark_code_points, problems, presentation)
            if font is not None:
                coverage_problems(texts, font, problems)
    except sqlite3.Error as e:
        problems.append("text.sqlite cannot be read (%s)" % type(e).__name__)
    finally:
        connection.close()
