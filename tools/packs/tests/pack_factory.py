"""Writes synthetic text packs for the verifier's tests, with faults.

Independent of the builder: its own DDL copy, token rule and digest, written
from docs/CONTENT_PACKS.md with sqlite3 and json only. Every text is plainly
synthetic: Latin words and a synthetic Arabic-script phrase from escapes.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
import struct
import unicodedata
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Surah:
    name: str
    ayat: tuple
    basmala: str | None = None
    place: str | None = None
    order: int | None = None


PHRASE = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"

SURAHS = (
    Surah(
        "Synthetic surah one",
        (
            "Synthetic ayah one",
            "Synthetic \u00e9 \u06d6 two \u06e9",
            "\u06da Synthetic e\u0301 three",
            " %s  " % PHRASE,
        ),
        basmala="Synthetic opening line",
        place="makki",
        order=2,
    ),
    Surah(
        "Synthetic surah two",
        (
            "Synthetic  double  spaces",
            "ab \U0001f600 \U0001d400z cd",
            "Synthetic \u0640 joined",
        ),
        place="madani",
        order=1,
    ),
    Surah(
        "Synthetic surah three",
        ("Synthetic last ayah",),
        basmala="Synthetic opening line",
    ),
)

DIVISIONS = (
    ("juz", 1, 1, 1), ("juz", 2, 2, 1),
    ("hizb", 1, 1, 1), ("hizb", 2, 1, 3), ("hizb", 3, 2, 1), ("hizb", 4, 3, 1),
    ("rub", 1, 1, 1), ("rub", 2, 1, 2), ("rub", 3, 1, 3), ("rub", 4, 1, 4),
    ("rub", 5, 2, 1), ("rub", 6, 2, 2), ("rub", 7, 2, 3), ("rub", 8, 3, 1),
    ("page", 1, 1, 1), ("page", 2, 1, 4), ("page", 3, 2, 2), ("page", 4, 3, 1),
)

SAJDAS = ((1, 2), (2, 3))

MARK_CODE_POINTS = frozenset({0x06D6, 0x06DA, 0x06E9, 0x1F600})

FONT_FAMILY = "Amiri Quran"
FONT_VERSION = "1.003"
FONT_SHA256 = hashlib.sha256(b"synthetic font file").hexdigest()

FAULTS = (
    "flipped_byte",
    "wrong_surah_hash",
    "wrong_counts",
    "leading_bom",
    "wal_header",
    "wrong_application_id",
    "wrong_user_version",
    "unsupported_format_version",
    "path_in_file_name",
    "missing_file",
    "wrong_file_size",
    "overlapping_spans",
    "non_strict_schema",
    "mark_overlaps_word",
    "wrong_after_word",
    "wrong_mark_count",
    "extra_file",
    "wrong_directory",
    "unknown_field",
    "duplicate_key",
    "empty_options",
    "licence_without_reference",
    "bool_for_int",
    "nbsp",
    "word_as_mark",
    "division_missing_ayah",
    "freelist",
    "extra_index",
    "extra_trigger",
    "short_signature",
    "manifest_bom",
    "manifest_string_bom",
    "nan_value",
)

APPLICATION_ID = 1213288523

DDL = (
    """CREATE TABLE surah (
  number           INTEGER PRIMARY KEY,
  name             TEXT NOT NULL,
  ayah_count       INTEGER NOT NULL,
  revelation_place TEXT CHECK (revelation_place IN ('makki','madani')),
  revelation_order INTEGER,
  basmala          TEXT
) STRICT""",
    """CREATE TABLE ayah (
  surah  INTEGER NOT NULL REFERENCES surah(number),
  number INTEGER NOT NULL,
  text   TEXT NOT NULL,
  PRIMARY KEY (surah, number)
) STRICT, WITHOUT ROWID""",
    """CREATE TABLE word (
  surah        INTEGER NOT NULL,
  ayah         INTEGER NOT NULL,
  number       INTEGER NOT NULL,
  start_offset INTEGER NOT NULL,
  end_offset   INTEGER NOT NULL,
  PRIMARY KEY (surah, ayah, number),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID""",
    """CREATE TABLE mark (
  surah        INTEGER NOT NULL,
  ayah         INTEGER NOT NULL,
  number       INTEGER NOT NULL,
  after_word   INTEGER NOT NULL,
  start_offset INTEGER NOT NULL,
  end_offset   INTEGER NOT NULL,
  PRIMARY KEY (surah, ayah, number),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID""",
    """CREATE TABLE division (
  kind   TEXT NOT NULL CHECK (kind IN ('juz','hizb','rub','page')),
  number INTEGER NOT NULL,
  surah  INTEGER NOT NULL,
  ayah   INTEGER NOT NULL,
  PRIMARY KEY (kind, number),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID""",
    """CREATE TABLE sajda (
  surah INTEGER NOT NULL,
  ayah  INTEGER NOT NULL,
  PRIMARY KEY (surah, ayah),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID""",
)


def text_values(surahs=SURAHS):
    """Every name, basmala and ayah, for tests that a message holds none."""
    values = []
    for surah in surahs:
        values.append(surah.name)
        if surah.basmala is not None:
            values.append(surah.basmala)
        values.extend(surah.ayat)
    return values


def code_points(surahs=SURAHS):
    """The code points of every basmala and ayah."""
    found = set()
    for surah in surahs:
        for text in surah.ayat + ((surah.basmala,) if surah.basmala else ()):
            found.update(map(ord, text))
    return frozenset(found)


def _width(token):
    return len(token.encode("utf-16-le")) // 2


def _spans(text, word_as_mark=False):
    """Word rows [number, start, end] and mark rows [number, after_word,
    start, end]; with word_as_mark the first word is stored as a mark."""
    words, marks = [], []
    start = 0
    for token in text.split(" "):
        end = start + _width(token)
        if token:
            letter = any(unicodedata.category(c)[0] == "L" for c in token)
            if word_as_mark and letter and not words:
                letter = False
                word_as_mark = False
            if letter:
                words.append([len(words) + 1, start, end])
            else:
                marks.append([len(marks) + 1, len(words), start, end])
        start = end + 1
    return words, marks


class _Ayah:
    def __init__(self, text, word_as_mark=False):
        self.text = text
        self.words, self.marks = _spans(text, word_as_mark)


def _stored(surahs, fault):
    stored = [[_Ayah(text) for text in surah.ayat] for surah in surahs]
    first = stored[0][0]
    if fault == "leading_bom":
        stored[0][0] = _Ayah("\ufeff" + first.text)
    elif fault == "nbsp":
        stored[-1][0] = _Ayah(stored[-1][0].text.replace(" ", "\u00a0", 1))
    elif fault == "word_as_mark":
        stored[0][0] = _Ayah(first.text, word_as_mark=True)
    elif fault == "overlapping_spans":
        first.words[1][1] = first.words[0][2] - 1
    elif fault in ("mark_overlaps_word", "wrong_after_word"):
        ayah = next(a for ayat in stored for a in ayat
                    if any(m[1] > 0 for m in a.marks))
        mark = next(m for m in ayah.marks if m[1] > 0)
        if fault == "wrong_after_word":
            mark[1] += 1
        else:
            mark[2] = ayah.words[mark[1] - 1][2] - 1
    return stored


def _digest(basmala, ayat):
    h = hashlib.sha256()
    fields = [] if basmala is None else [(0, basmala)]
    fields += [(n, text) for n, text in enumerate(ayat, 1)]
    for number, text in fields:
        data = text.encode("utf-8")
        h.update(struct.pack(">II", number, len(data)) + data)
    return h.hexdigest()


def _write_database(path, surahs, stored, divisions, sajdas, fault):
    connection = sqlite3.connect(str(path), isolation_level=None)
    try:
        run = connection.execute
        run("PRAGMA encoding = 'UTF-8'")
        run("PRAGMA application_id = %d" % (
            APPLICATION_ID + (fault == "wrong_application_id")))
        run("PRAGMA user_version = %d" % (1 + (fault == "wrong_user_version")))
        run("PRAGMA journal_mode = DELETE")
        if fault != "division_missing_ayah":
            run("PRAGMA foreign_keys = ON")
        for ddl in DDL:
            if fault == "non_strict_schema" and ddl is DDL[-1]:
                ddl = ddl.replace("STRICT, ", "")
            run(ddl)
        run("BEGIN")
        for s, (surah, ayat) in enumerate(zip(surahs, stored), 1):
            run("INSERT INTO surah VALUES (?, CAST(? AS TEXT), ?, ?, ?, "
                "CAST(? AS TEXT))",
                (s, surah.name.encode(), len(ayat), surah.place, surah.order,
                 None if surah.basmala is None else surah.basmala.encode()))
            for a, ayah in enumerate(ayat, 1):
                run("INSERT INTO ayah VALUES (?, ?, CAST(? AS TEXT))",
                    (s, a, ayah.text.encode()))
                for word in ayah.words:
                    run("INSERT INTO word VALUES (?, ?, ?, ?, ?)",
                        [s, a] + word)
                for mark in ayah.marks:
                    run("INSERT INTO mark VALUES (?, ?, ?, ?, ?, ?)",
                        [s, a] + mark)
        for kind, number, surah, ayah in divisions:
            if fault == "division_missing_ayah" and (kind, number) == (
                    "page", 4):
                ayah = 9
            run("INSERT INTO division VALUES (?, ?, ?, ?)",
                (kind, number, surah, ayah))
        for surah, ayah in sajdas:
            run("INSERT INTO sajda VALUES (?, ?)", (surah, ayah))
        run("COMMIT")
        if fault == "extra_index":
            run("CREATE INDEX word_by_start ON word(start_offset)")
        if fault == "extra_trigger":
            run("CREATE TRIGGER sajda_guard BEFORE DELETE ON sajda "
                "BEGIN SELECT RAISE(ABORT, 'synthetic'); END")
        run("VACUUM")
        if fault == "freelist":
            run("INSERT INTO ayah VALUES (3, 999, ?)", ("x" * 40000,))
            run("DELETE FROM ayah WHERE number = 999")
        if fault == "wal_header":
            run("PRAGMA journal_mode = WAL")
    finally:
        connection.close()


def _source(role, registry_row, options):
    return {
        "role": role,
        "registry_row": registry_row,
        "name": "Synthetic %s source" % role,
        "publisher": "Synthetic publisher",
        "url": "https://example.invalid/synthetic/%s" % role,
        "version": "1",
        "fetched_on": "2026-01-01",
        "file_sha256": hashlib.sha256(
            ("synthetic %s" % role).encode()).hexdigest(),
        "trust_grade": "A",
        "options": options,
        "licence": {
            "text": None,
            "permission_ref": "Synthetic permission %d" % registry_row,
            "notice": None,
            "allows_export": True,
        },
    }


def _manifest(pack_id, version, text_path, digests, counts):
    data = text_path.read_bytes()
    return {
        "format": "holyquran-pack",
        "format_version": 1,
        "id": pack_id,
        "kind": "text",
        "version": version,
        "changelog": [
            {"version": version, "date": "2026-01-01",
             "summary": "Synthetic pack"},
        ],
        "riwaya": "hafs",
        "edition": "synthetic-edition",
        "font": {"family": FONT_FAMILY, "version": FONT_VERSION,
                 "sha256": FONT_SHA256},
        "sources": [
            _source("text", 1, {"synthetic_type": "synthetic",
                                "synthetic_marks": True,
                                "synthetic_level": 1}),
            _source("edition_map", 4, None),
        ],
        "files": [{"name": "text.sqlite",
                   "sha256": hashlib.sha256(data).hexdigest(),
                   "bytes": len(data)}],
        "surah_sha256": digests,
        "counts": counts,
        "reviews": [
            {"reviewer": "synthetic reviewer", "date": "2026-01-01",
             "scope": "synthetic test data"},
        ],
    }


def _apply_manifest_fault(manifest, fault):
    counts = manifest["counts"]
    if fault == "wrong_surah_hash":
        manifest["surah_sha256"]["1"] = hashlib.sha256(
            b"synthetic wrong digest").hexdigest()
    elif fault == "wrong_counts":
        counts["ayat"] += 1
    elif fault == "wrong_mark_count":
        counts["marks"] += 1
    elif fault == "unsupported_format_version":
        manifest["format_version"] = 2
    elif fault == "path_in_file_name":
        manifest["files"][0]["name"] = "../text.sqlite"
    elif fault == "wrong_file_size":
        manifest["files"][0]["bytes"] += 1
    elif fault == "wrong_directory":
        manifest["id"] += "-moved"
    elif fault == "unknown_field":
        manifest["font"]["style"] = "regular"
    elif fault == "empty_options":
        manifest["sources"][0]["options"] = {}
    elif fault == "licence_without_reference":
        manifest["sources"][1]["licence"]["permission_ref"] = None
    elif fault == "bool_for_int":
        counts["sajdas"] = True
    elif fault == "manifest_string_bom":
        manifest["edition"] = "\ufeff" + manifest["edition"]
    elif fault == "nan_value":
        counts["sajdas"] = float("nan")


def _manifest_bytes(manifest, fault):
    text = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    if fault == "duplicate_key":
        text = text.replace('"kind": "text",', '"kind": "text",\n  "kind": '
                            '"text",', 1)
    data = text.encode("utf-8")
    return b"\xef\xbb\xbf" + data if fault == "manifest_bom" else data


def _flip_first_ayah(path, text):
    data = bytearray(path.read_bytes())
    at = data.find(text.encode("utf-8"))
    if at < 0:
        raise AssertionError("the first ayah is not in text.sqlite")
    data[at] ^= 0x01
    path.write_bytes(bytes(data))


def write_pack(root, *, surahs=SURAHS, divisions=DIVISIONS, sajdas=SAJDAS,
               fault=None, pack_id="synthetic-text", version=1) -> Path:
    """Writes `<root>/<id>/<version>/` and returns that directory."""
    if fault is not None and fault not in FAULTS:
        raise ValueError("unknown fault")
    directory = Path(root) / pack_id / str(version)
    directory.mkdir(parents=True)
    text_path = directory / "text.sqlite"
    stored = _stored(surahs, fault)
    _write_database(text_path, surahs, stored, divisions, sajdas, fault)
    digests = {
        str(n): _digest(surah.basmala, [a.text for a in ayat])
        for n, (surah, ayat) in enumerate(zip(surahs, stored), 1)
    }
    kinds = ("juz", "hizb", "rub", "page")
    counts = {
        "surahs": len(stored),
        "ayat": sum(len(ayat) for ayat in stored),
        "words": sum(len(a.words) for ayat in stored for a in ayat),
        "marks": sum(len(a.marks) for ayat in stored for a in ayat),
        "divisions": {k: sum(d[0] == k for d in divisions) for k in kinds},
        "sajdas": len(sajdas),
    }
    manifest = _manifest(pack_id, version, text_path, digests, counts)
    _apply_manifest_fault(manifest, fault)
    (directory / "manifest.json").write_bytes(_manifest_bytes(manifest, fault))
    if fault == "flipped_byte":
        _flip_first_ayah(text_path, stored[0][0].text)
    elif fault == "missing_file":
        text_path.unlink()
    elif fault == "extra_file":
        (directory / "notes.txt").write_bytes(b"synthetic")
    elif fault == "short_signature":
        (directory / "manifest.json.sig").write_bytes(bytes(63))
    return directory
