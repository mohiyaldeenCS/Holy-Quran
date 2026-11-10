"""An independent verifier of a tafsir pack directory (docs/CONTENT_PACKS.md,
"Tafsir pack"; D-184).

It shares no code with the writer (`tafsir_database`, `manifest`) beyond
`errors.py`: it holds its own copy of the format's DDL and recomputes every
rule from the stored bytes. Ranges are checked against the P5 ayah counts
(`ayah_counts.read_ayah_counts`). Problems name passage numbers, surahs, ayat,
field paths, file names and code points only, never a text of the pack.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path
from types import SimpleNamespace

from .verify import (
    MANIFEST, Report, directory_problems, file_problems, header_problems,
    location_problems)
from .verify_manifest import (
    BAD, Fields, changelog_problems, files_problems, read_checked,
    review_problems, riwaya_problems, safe_name, sources_problems)
from .verify_spans import coverage_problems

TAFSIR = "tafsir.sqlite"
FORMAT_VERSION = 2
SURAH_LEVEL = (0, 0)
# D-185: the two code points the tafsir font lacks that a passage may hold.
FONT_EXEMPT = frozenset({0x2009, 0x2063})

_MANIFEST_KEYS = (
    "format", "format_version", "id", "kind", "version", "changelog",
    "riwaya", "sources", "files", "counts", "reviews",
)
_FACTS = ("title", "author", "publisher", "edition", "editor")

# Table, columns as (name, declared type, notnull, pk position), and its
# CREATE statement as the format gives it, without comments.
_TABLES = (
    ("book", (
        ("title", "TEXT", 1, 0),
        ("author", "TEXT", 1, 0),
        ("publisher", "TEXT", 0, 0),
        ("edition", "TEXT", 0, 0),
        ("editor", "TEXT", 0, 0),
    ), "CREATE TABLE book ( title TEXT NOT NULL, author TEXT NOT NULL, "
       "publisher TEXT, edition TEXT, editor TEXT ) STRICT"),
    ("passage", (
        ("number", "INTEGER", 0, 1),
        ("surah", "INTEGER", 1, 0),
        ("first_ayah", "INTEGER", 1, 0),
        ("last_ayah", "INTEGER", 1, 0),
        ("text", "TEXT", 1, 0),
    ), "CREATE TABLE passage ( number INTEGER PRIMARY KEY, surah INTEGER NOT "
       "NULL, first_ayah INTEGER NOT NULL, last_ayah INTEGER NOT NULL, text "
       "TEXT NOT NULL, UNIQUE (surah, first_ayah), CHECK (surah >= 1 AND "
       "((first_ayah = 0 AND last_ayah = 0) OR (first_ayah >= 1 AND "
       "last_ayah >= first_ayah))) ) STRICT"),
)


def verify_tafsir_pack(directory, ayah_counts, font=None) -> Report:
    """`ayah_counts` is {surah: ayah count} for surahs 1 to n; with `font`,
    every code point of the book and its passages must be in it."""
    directory = Path(directory)
    problems = []
    if not directory.is_dir():
        return Report(["the pack directory does not exist"], None, False)
    signed = directory_problems(directory, TAFSIR, problems)
    manifest = read_checked(directory / MANIFEST, problems, _manifest_problems)
    if manifest is None:
        return Report(problems, None, signed)
    counts = manifest["counts"]
    location_problems(directory, manifest, problems)
    path = directory / TAFSIR
    if not path.is_file() or path.is_symlink():
        problems.append("tafsir.sqlite is missing")
        return Report(problems, counts, signed)
    file_problems(path, manifest["files"][0], problems)
    if header_problems(path, FORMAT_VERSION, problems):
        _database_problems(path, counts["passages"], ayah_counts, font,
                           problems)
    return Report(problems, counts, signed)


def _manifest_problems(manifest, problems):
    if not isinstance(manifest, dict):
        problems.append("manifest.json is not a JSON object")
        return
    if manifest.get("format") != "holyquran-pack":
        problems.append("manifest.format is not holyquran-pack")
    version = manifest.get("format_version")
    if type(version) is not int or version != FORMAT_VERSION:
        problems.append(
            "manifest.format_version is not %d, the format of a tafsir pack"
            % FORMAT_VERSION)
        return
    root = Fields(manifest, "manifest", problems)
    root.expect_keys(_MANIFEST_KEYS)
    kind = root.string("kind")
    if kind is not BAD and kind != "tafsir":
        root.field_problem("kind", "is not tafsir")
    riwaya_problems(root, "tafsir")
    root.string("id")
    root.positive("version")
    changelog_problems(root)
    sources_problems(root, "tafsir", ("tafsir",))
    files_problems(root, "tafsir", TAFSIR)
    counts = root.object("counts")
    if counts is not None:
        counts.expect_keys(("passages",))
        counts.positive("passages")
    review_problems(root)


def _database_problems(path, listed, ayah_counts, font, problems):
    uri = path.resolve().as_uri() + "?mode=ro&immutable=1"
    try:
        connection = sqlite3.connect(uri, uri=True)
    except sqlite3.Error as e:
        problems.append("tafsir.sqlite does not open (%s)" % type(e).__name__)
        return
    try:
        if _schema_problems(connection, problems):
            texts = {}
            _book_problems(connection.execute(
                "SELECT %s FROM book"
                % ", ".join("CAST(%s AS BLOB)" % c for c in _FACTS)
            ).fetchall(), texts, problems)
            _passage_problems(connection.execute(
                "SELECT number, surah, first_ayah, last_ayah, "
                "CAST(text AS BLOB) FROM passage ORDER BY number"
            ).fetchall(), listed, ayah_counts, texts, problems)
            if font is not None:
                covered = SimpleNamespace(
                    code_points=frozenset(font.code_points) | FONT_EXEMPT)
                coverage_problems(texts, covered, problems)
    except sqlite3.Error as e:
        problems.append("tafsir.sqlite cannot be read (%s)" % type(e).__name__)
    finally:
        connection.close()


def _schema_problems(connection, problems):
    """False when the tables or columns differ, so that no row can be trusted
    to hold the types the format gives it."""
    if connection.execute("PRAGMA encoding").fetchone()[0] != "UTF-8":
        problems.append("tafsir.sqlite: PRAGMA encoding is not UTF-8")
    expected = [table[0] for table in _TABLES]
    created = connection.execute(
        "SELECT name, sql FROM sqlite_schema WHERE type = 'table' "
        "AND substr(name, 1, 7) != 'sqlite_' ORDER BY rowid").fetchall()
    listed = {row[0]: row[1:] for row in connection.execute(
        "SELECT name, type, strict, wr FROM pragma_table_list "
        "WHERE schema = 'main' AND substr(name, 1, 7) != 'sqlite_'")}
    names = [name for name, _ in created]
    if names != expected or sorted(listed) != sorted(expected):
        problems.append(
            "tafsir.sqlite: the tables are %s, not %s"
            % (", ".join(safe_name(name) for name in names),
               ", ".join(expected)))
        return False
    sound = True
    for (name, columns, ddl), (_, sql) in zip(_TABLES, created):
        kind, strict, wr = listed[name]
        if kind != "table" or strict != 1:
            problems.append("tafsir.sqlite: table %s is not STRICT" % name)
            sound = False
        if wr != 0:
            problems.append("tafsir.sqlite: table %s is WITHOUT ROWID" % name)
            sound = False
        if not _column_problems(connection, name, columns, problems):
            sound = False
        elif " ".join(sql.split()) != ddl:
            problems.append(
                "tafsir.sqlite: table %s is not created as format 2 gives it "
                "(its keys or CHECK differ)" % name)
    for kind, name, sql in connection.execute(
            "SELECT type, name, sql FROM sqlite_schema "
            "WHERE type != 'table' ORDER BY rowid"):
        if not (kind == "index" and sql is None
                and name.startswith("sqlite_autoindex_")):
            problems.append(
                "tafsir.sqlite: sqlite_schema holds the %s %s, which format "
                "2 has not" % (safe_name(kind), safe_name(name)))
    report = [row[0] for row in connection.execute("PRAGMA integrity_check")]
    if report != ["ok"]:
        problems.append(
            "tafsir.sqlite: PRAGMA integrity_check reports %d problems"
            % len(report))
    return sound


def _column_problems(connection, table, columns, problems):
    found = [tuple(row) for row in connection.execute(
        'SELECT name, type, "notnull", pk, hidden FROM pragma_table_xinfo(?) '
        "ORDER BY cid", (table,))]
    if len(found) != len(columns):
        problems.append(
            "tafsir.sqlite: table %s has %d columns, not %d"
            % (table, len(found), len(columns)))
        return False
    sound = True
    for index, (row, column) in enumerate(zip(found, columns)):
        if row != column + (0,):
            problems.append(
                "tafsir.sqlite: table %s column %d is %s %s notnull %d pk %d "
                "hidden %d, not %s %s notnull %d pk %d hidden 0"
                % ((table, index + 1, safe_name(row[0]),
                    safe_name(row[1] or "-")) + row[2:] + column))
            sound = False
    return sound


def _book_problems(rows, texts, problems):
    if len(rows) != 1:
        problems.append("the book table holds %d rows, not 1" % len(rows))
    for index, row in enumerate(rows, 1):
        for column, data in zip(_FACTS, row):
            if data is None:
                continue
            where = ("book.%s" % column if len(rows) == 1
                     else "book row %d.%s" % (index, column))
            texts[where] = _decoded(bytes(data), where, problems)


def _passage_problems(rows, listed, ayah_counts, texts, problems):
    if listed != len(rows):
        problems.append(
            "counts.passages is %d; the passage table holds %d"
            % (listed, len(rows)))
    previous = None
    for index, (number, surah, first, last, data) in enumerate(rows, 1):
        if number != index:
            problems.append("passage %d is numbered %d" % (index, number))
        _range_problems(number, surah, first, last, ayah_counts, problems)
        if previous is not None:
            _order_problems(previous, (number, surah, first, last), problems)
        previous = (number, surah, first, last)
        where = "passage %d" % number
        texts[where] = _decoded(bytes(data), where, problems)


def _range_problems(number, surah, first, last, ayah_counts, problems):
    if surah not in ayah_counts:
        problems.append(
            "passage %d: surah %d is not a surah of the ayah counts (1 to %d)"
            % (number, surah, len(ayah_counts)))
    elif (first, last) == SURAH_LEVEL:
        return
    elif first < 1:
        problems.append(
            "passage %d: range %d..%d of surah %d is neither surah-level "
            "(0..0) nor from ayah 1" % (number, first, last, surah))
    elif last < first:
        problems.append(
            "passage %d: range %d..%d of surah %d is reversed"
            % (number, first, last, surah))
    elif last > ayah_counts[surah]:
        problems.append(
            "passage %d reaches ayah %d of surah %d, which has %d"
            % (number, last, surah, ayah_counts[surah]))


def _order_problems(before, passage, problems):
    number, surah, first, _ = passage
    b_number, b_surah, b_first, b_last = before
    if (surah, first) == (b_surah, b_first) and (first, b_first) == (0, 0):
        problems.append(
            "surah %d has more than one surah-level passage (passages %d and "
            "%d)" % (surah, b_number, number))
    elif (surah, first) <= (b_surah, b_first):
        problems.append(
            "passage %d does not follow passage %d in mushaf order"
            % (number, b_number))
    elif surah == b_surah and first <= b_last:
        problems.append("passages %d and %d overlap" % (b_number, number))


def _decoded(data, where, problems):
    """The stored bytes as a string, or None when they are not strict UTF-8."""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as e:
        problems.append("%s is not UTF-8 (byte %d)" % (where, e.start))
        return None
    if not text:
        problems.append("%s is empty" % where)
    at = text.find("\ufeff")
    if at >= 0:
        problems.append("%s holds U+FEFF at code point %d" % (where, at))
    return text
