"""Writes synthetic tafsir packs for the verifier's tests, with faults.

Independent of the writer: its own DDL copy, written from
docs/CONTENT_PACKS.md ("Tafsir pack") with sqlite3 and json only. Every text
is plainly synthetic: Latin words and a synthetic Arabic-script phrase from
escapes. Never Quran or book text.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

APPLICATION_ID = 1213288523

PHRASE = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"

# The ayah counts of the synthetic KFGQPC-shaped file (tests/build_support).
AYAH_COUNTS = {1: 4, 2: 3, 3: 1}

BOOK = ("Synthetic book title " + PHRASE, "Synthetic author", "Synthetic publisher", None, None)

# number, surah, first_ayah, last_ayah, text. Passages 1 and 4 are
# surah-level (D-184); ayah 2:1 and surah 3 have no passage.
PASSAGES = (
    (1, 1, 0, 0, "Synthetic surah-level paragraph\nSynthetic second paragraph"),
    (2, 1, 1, 2, "Synthetic passage with e\u0301 kept decomposed"),
    (3, 1, 3, 4, "  " + PHRASE + " \ufdfa "),
    (4, 2, 0, 0, "Synthetic surah-level line"),
    (5, 2, 2, 3, "Synthetic passage with \u00e9 kept precomposed"),
)

_BOOK_DDL = """CREATE TABLE book (
  title     TEXT NOT NULL,
  author    TEXT NOT NULL,
  publisher TEXT,
  edition   TEXT,
  editor    TEXT
) STRICT"""

_PASSAGE_DDL = """CREATE TABLE passage (
  number     INTEGER PRIMARY KEY,
  surah      INTEGER NOT NULL,
  first_ayah INTEGER NOT NULL,
  last_ayah  INTEGER NOT NULL,
  text       TEXT NOT NULL,
  UNIQUE (surah, first_ayah),
  CHECK (surah >= 1 AND ((first_ayah = 0 AND last_ayah = 0) OR (first_ayah >= 1 AND last_ayah >= first_ayah)))
) STRICT"""

_CHECK = (",\n  CHECK (surah >= 1 AND ((first_ayah = 0 AND last_ayah = 0) "
          "OR (first_ayah >= 1 AND last_ayah >= first_ayah)))")
_UNIQUE = ",\n  UNIQUE (surah, first_ayah)"

# Faults whose rows the format's CHECK or UNIQUE would refuse: the factory
# writes the passage table without that constraint, as a careless writer might.
_WITHOUT_CHECK = ("no_check", "reversed_range", "below_ayah_one")
_WITHOUT_UNIQUE = ("two_surah_level",)

FAULTS = (
    "flipped_byte",
    "wrong_counts",
    "wal_header",
    "wrong_application_id",
    "wrong_user_version",
    "format_version_1",
    "text_kind",
    "text_key",
    "missing_key",
    "wrong_source_role",
    "text_file_name",
    "zero_passages_count",
    "null_riwaya",
    "duplicate_key",
    "manifest_bom",
    "missing_file",
    "wrong_file_size",
    "extra_file",
    "wrong_directory",
    "short_signature",
    "non_strict_schema",
    "extra_column",
    "extra_table",
    "no_check",
    "extra_index",
    "extra_trigger",
    "freelist",
    "two_books",
    "no_book",
    "gap_in_numbering",
    "out_of_order",
    "overlap",
    "past_the_surah",
    "reversed_range",
    "below_ayah_one",
    "unknown_surah",
    "two_surah_level",
    "surah_level_after_ayah",
    "leading_bom",
    "inner_bom",
    "bad_utf8",
    "empty_text",
    "empty_fact",
    "bad_utf8_fact",
)


def text_values(book=BOOK, passages=PASSAGES):
    """Every book fact and passage text, for tests that a message holds none."""
    return [v for v in book if v] + [p[4] for p in passages]


def code_points(book=BOOK, passages=PASSAGES):
    return frozenset(ord(c) for value in text_values(book, passages) for c in value)


def _rows(passages, fault):
    rows = [list(p) for p in passages]
    if fault == "gap_in_numbering":
        for row in rows[2:]:
            row[0] += 1
    elif fault == "out_of_order":
        rows[2][1:4] = [3, 1, 1]
    elif fault == "overlap":
        rows[2][2] = 2
    elif fault == "past_the_surah":
        rows[2][3] = 5
    elif fault == "reversed_range":
        rows[2][2:4] = [4, 3]
    elif fault == "below_ayah_one":
        rows[4][1:4] = [3, 0, 1]
    elif fault == "unknown_surah":
        rows[4][1] = 4
    elif fault == "two_surah_level":
        rows[1][2:4] = [0, 0]
    elif fault == "surah_level_after_ayah":
        rows[0][2:4], rows[1][2:4] = [1, 2], [0, 0]
    texts = [row[4].encode("utf-8") for row in rows]
    if fault == "leading_bom":
        texts[0] = "\ufeff".encode("utf-8") + texts[0]
    elif fault == "inner_bom":
        texts[1] = texts[1].replace(b" ", "\ufeff".encode("utf-8"), 1)
    elif fault == "bad_utf8":
        texts[1] = texts[1] + b"\xc3"
    elif fault == "empty_text":
        texts[1] = b""
    return [row[:4] + [text] for row, text in zip(rows, texts)]


def _books(book, fault):
    values = [None if v is None else v.encode("utf-8") for v in book]
    if fault == "empty_fact":
        values[2] = b""
    elif fault == "bad_utf8_fact":
        values[0] = b"\xff" + values[0]
    if fault == "no_book":
        return []
    return [values, values] if fault == "two_books" else [values]


def _passage_ddl(fault):
    ddl = _PASSAGE_DDL
    if fault in _WITHOUT_CHECK:
        ddl = ddl.replace(_CHECK, "")
    if fault in _WITHOUT_UNIQUE:
        ddl = ddl.replace(_UNIQUE, "")
    if fault == "non_strict_schema":
        ddl = ddl[: -len(" STRICT")]
    return ddl


def _write_database(path, book, passages, fault):
    connection = sqlite3.connect(str(path), isolation_level=None)
    try:
        run = connection.execute
        run("PRAGMA encoding = 'UTF-8'")
        run("PRAGMA application_id = %d" % (APPLICATION_ID + (fault == "wrong_application_id")))
        run("PRAGMA user_version = %d" % (1 if fault == "wrong_user_version" else 2))
        run("PRAGMA journal_mode = DELETE")
        book_ddl = _BOOK_DDL
        if fault == "extra_column":
            book_ddl = book_ddl.replace("  editor    TEXT\n", "  editor    TEXT,\n  note      TEXT\n")
        run(book_ddl)
        run(_passage_ddl(fault))
        if fault == "extra_table":
            run("CREATE TABLE note (number INTEGER PRIMARY KEY) STRICT")
        run("BEGIN")
        columns = 6 if fault == "extra_column" else 5
        for values in _books(book, fault):
            run(
                "INSERT INTO book VALUES (%s)" % ", ".join(["CAST(? AS TEXT)"] * columns),
                values + [None] * (columns - 5),
            )
        for row in _rows(passages, fault):
            run("INSERT INTO passage VALUES (?, ?, ?, ?, CAST(? AS TEXT))", row)
        run("COMMIT")
        if fault == "extra_index":
            run("CREATE INDEX passage_by_surah ON passage(surah)")
        if fault == "extra_trigger":
            run("CREATE TRIGGER book_guard BEFORE DELETE ON book BEGIN SELECT RAISE(ABORT, 'synthetic'); END")
        run("VACUUM")
        if fault == "freelist":
            run("INSERT INTO passage VALUES (999, 3, 1, 1, ?)", ("x" * 40000,))
            run("DELETE FROM passage WHERE number = 999")
        if fault == "wal_header":
            run("PRAGMA journal_mode = WAL")
    finally:
        connection.close()


def _manifest(pack_id, version, path, passages):
    data = path.read_bytes()
    return {
        "format": "holyquran-pack",
        "format_version": 2,
        "id": pack_id,
        "kind": "tafsir",
        "version": version,
        "changelog": [{"version": version, "date": "2026-01-01", "summary": "Synthetic pack"}],
        "riwaya": "hafs",
        "sources": [
            {
                "role": "tafsir",
                "registry_row": 18,
                "name": "Synthetic tafsir source",
                "publisher": "Synthetic publisher",
                "url": "https://example.invalid/synthetic/book/1",
                "version": "2026-01-01",
                "fetched_on": "2026-01-01",
                "file_sha256": hashlib.sha256(b"synthetic pages").hexdigest(),
                "trust_grade": "B",
                "options": None,
                "licence": {
                    "text": None,
                    "permission_ref": "Synthetic permission 18",
                    "notice": None,
                    "allows_export": False,
                },
            }
        ],
        "files": [{"name": "tafsir.sqlite", "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}],
        "counts": {"passages": passages},
        "reviews": [{"reviewer": "synthetic reviewer", "date": "2026-01-01", "scope": "synthetic test data"}],
    }


def _apply_manifest_fault(manifest, fault):
    if fault == "wrong_counts":
        manifest["counts"]["passages"] += 1
    elif fault == "format_version_1":
        manifest["format_version"] = 1
    elif fault == "text_kind":
        manifest["kind"] = "text"
    elif fault == "text_key":
        manifest["edition"] = "synthetic-edition"
    elif fault == "missing_key":
        del manifest["reviews"]
    elif fault == "wrong_source_role":
        manifest["sources"][0]["role"] = "text"
    elif fault == "text_file_name":
        manifest["files"][0]["name"] = "text.sqlite"
    elif fault == "zero_passages_count":
        manifest["counts"]["passages"] = 0
    elif fault == "null_riwaya":
        manifest["riwaya"] = None
    elif fault == "wrong_file_size":
        manifest["files"][0]["bytes"] += 1
    elif fault == "wrong_directory":
        manifest["id"] += "-moved"


def _manifest_bytes(manifest, fault):
    text = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    if fault == "duplicate_key":
        text = text.replace('"kind": "tafsir",', '"kind": "tafsir",\n  "kind": "tafsir",', 1)
    data = text.encode("utf-8")
    return b"\xef\xbb\xbf" + data if fault == "manifest_bom" else data


def write_pack(root, *, book=BOOK, passages=PASSAGES, fault=None, pack_id="synthetic-tafsir", version=1) -> Path:
    """Writes `<root>/<id>/<version>/` and returns that directory."""
    if fault is not None and fault not in FAULTS:
        raise ValueError("unknown fault")
    directory = Path(root) / pack_id / str(version)
    directory.mkdir(parents=True)
    path = directory / "tafsir.sqlite"
    _write_database(path, book, passages, fault)
    manifest = _manifest(pack_id, version, path, len(passages))
    _apply_manifest_fault(manifest, fault)
    (directory / "manifest.json").write_bytes(_manifest_bytes(manifest, fault))
    if fault == "flipped_byte":
        data = bytearray(path.read_bytes())
        at = data.find(passages[1][4].encode("utf-8"))
        if at < 0:
            raise AssertionError("passage 2 is not in tafsir.sqlite")
        data[at] ^= 0x01
        path.write_bytes(bytes(data))
    elif fault == "missing_file":
        path.unlink()
    elif fault == "extra_file":
        (directory / "notes.txt").write_bytes(b"synthetic")
    elif fault == "short_signature":
        (directory / "manifest.json.sig").write_bytes(bytes(63))
    return directory
