"""The text.sqlite checks of the independent verifier: schema, integrity,
numbering, references, stored text and surah digests."""

from __future__ import annotations

import hashlib
import struct

from .verify_manifest import DIVISION_KINDS, safe_name

# Table, WITHOUT ROWID, columns as (name, declared type, notnull, pk
# position), foreign keys as (parent table, column, parent column).
_TABLES = (
    ("surah", False, (
        ("number", "INTEGER", 0, 1),
        ("name", "TEXT", 1, 0),
        ("ayah_count", "INTEGER", 1, 0),
        ("revelation_place", "TEXT", 0, 0),
        ("revelation_order", "INTEGER", 0, 0),
        ("basmala", "TEXT", 0, 0),
    ), ()),
    ("ayah", True, (
        ("surah", "INTEGER", 1, 1),
        ("number", "INTEGER", 1, 2),
        ("text", "TEXT", 1, 0),
    ), (("surah", "surah", "number"),)),
    ("word", True, (
        ("surah", "INTEGER", 1, 1),
        ("ayah", "INTEGER", 1, 2),
        ("number", "INTEGER", 1, 3),
        ("start_offset", "INTEGER", 1, 0),
        ("end_offset", "INTEGER", 1, 0),
    ), (("ayah", "surah", "surah"), ("ayah", "ayah", "number"))),
    ("mark", True, (
        ("surah", "INTEGER", 1, 1),
        ("ayah", "INTEGER", 1, 2),
        ("number", "INTEGER", 1, 3),
        ("after_word", "INTEGER", 1, 0),
        ("start_offset", "INTEGER", 1, 0),
        ("end_offset", "INTEGER", 1, 0),
    ), (("ayah", "surah", "surah"), ("ayah", "ayah", "number"))),
    ("division", True, (
        ("kind", "TEXT", 1, 1),
        ("number", "INTEGER", 1, 2),
        ("surah", "INTEGER", 1, 0),
        ("ayah", "INTEGER", 1, 0),
    ), (("ayah", "surah", "surah"), ("ayah", "ayah", "number"))),
    ("sajda", True, (
        ("surah", "INTEGER", 1, 1),
        ("ayah", "INTEGER", 1, 2),
    ), (("ayah", "surah", "surah"), ("ayah", "ayah", "number"))),
)


def schema_problems(connection, problems):
    """False when the tables, columns or STRICT differ, so that no row can be
    trusted to hold the types the format gives it."""
    encoding = connection.execute("PRAGMA encoding").fetchone()[0]
    if encoding != "UTF-8":
        problems.append("text.sqlite: PRAGMA encoding is not UTF-8")
    expected = [table[0] for table in _TABLES]
    created = [row[0] for row in connection.execute(
        "SELECT name FROM sqlite_schema WHERE type = 'table' "
        "AND substr(name, 1, 7) != 'sqlite_' ORDER BY rowid")]
    listed = {row[0]: row[1:] for row in connection.execute(
        "SELECT name, type, strict, wr FROM pragma_table_list "
        "WHERE schema = 'main' AND substr(name, 1, 7) != 'sqlite_'")}
    if created != expected or sorted(listed) != sorted(expected):
        problems.append(
            "text.sqlite: the tables are %s, not %s"
            % (", ".join(safe_name(name) for name in created), ", ".join(expected)))
        return False
    sound = True
    for name, without_rowid, columns, keys in _TABLES:
        kind, strict, wr = listed[name]
        if kind != "table" or strict != 1:
            problems.append("text.sqlite: table %s is not STRICT" % name)
            sound = False
        if wr != int(without_rowid):
            problems.append(
                "text.sqlite: table %s is %sWITHOUT ROWID"
                % (name, "" if wr else "not "))
        if not _column_problems(connection, name, columns, problems):
            sound = False
        found_keys = tuple(connection.execute(
            'SELECT "table", "from", "to" FROM pragma_foreign_key_list(?) '
            "ORDER BY id, seq", (name,)))
        if found_keys != keys:
            problems.append(
                "text.sqlite: table %s has other foreign keys than format v1"
                % name)
    _object_problems(connection, problems)
    _check_problems(connection, problems)
    return sound


def _column_problems(connection, table, columns, problems):
    found = list(connection.execute(
        'SELECT name, type, "notnull", pk, hidden FROM pragma_table_xinfo(?) '
        "ORDER BY cid", (table,)))
    if len(found) != len(columns):
        problems.append(
            "text.sqlite: table %s has %d columns, not %d"
            % (table, len(found), len(columns)))
        return False
    sound = True
    for index, (row, column) in enumerate(zip(found, columns)):
        if tuple(row) != column + (0,):
            problems.append(
                "text.sqlite: table %s column %d is %s %s notnull %d pk %d "
                "hidden %d, not %s %s notnull %d pk %d hidden 0"
                % ((table, index + 1, safe_name(row[0]), safe_name(row[1] or "-"))
                   + tuple(row[2:]) + column))
            sound = False
    return sound


def _object_problems(connection, problems):
    for kind, name, sql in connection.execute(
            "SELECT type, name, sql FROM sqlite_schema "
            "WHERE type != 'table' ORDER BY rowid"):
        automatic = (
            kind == "index" and sql is None
            and name.startswith("sqlite_autoindex_"))
        if not automatic:
            problems.append(
                "text.sqlite: sqlite_schema holds the %s %s, which format v1 "
                "has not" % (safe_name(kind), safe_name(name)))


def _check_problems(connection, problems):
    report = [row[0] for row in connection.execute("PRAGMA integrity_check")]
    if report != ["ok"]:
        problems.append(
            "text.sqlite: PRAGMA integrity_check reports %d problems"
            % len(report))
    broken = {}
    for row in connection.execute("PRAGMA foreign_key_check"):
        broken[row[0]] = broken.get(row[0], 0) + 1
    for table in sorted(broken):
        problems.append(
            "text.sqlite: PRAGMA foreign_key_check: %d rows of %s break a "
            "foreign key" % (broken[table], safe_name(table)))


class Contents:
    """Every row of the pack, text as stored bytes."""

    def __init__(self, connection):
        self.surahs = connection.execute(
            "SELECT number, ayah_count, CAST(revelation_place AS BLOB), "
            "CAST(name AS BLOB), CAST(basmala AS BLOB) FROM surah "
            "ORDER BY number").fetchall()
        self.ayat = connection.execute(
            "SELECT surah, number, CAST(text AS BLOB) FROM ayah "
            "ORDER BY surah, number").fetchall()
        self.words = _grouped(connection.execute(
            "SELECT surah, ayah, number, start_offset, end_offset FROM word "
            "ORDER BY surah, ayah, number"))
        self.marks = _grouped(connection.execute(
            "SELECT surah, ayah, number, after_word, start_offset, end_offset "
            "FROM mark ORDER BY surah, ayah, number"))
        self.divisions = connection.execute(
            "SELECT CAST(kind AS BLOB), number, surah, ayah FROM division "
            "ORDER BY kind, number").fetchall()
        self.sajdas = connection.execute(
            "SELECT surah, ayah FROM sajda ORDER BY surah, ayah").fetchall()
        self.addresses = {(surah, number) for surah, number, _ in self.ayat}


def _grouped(rows):
    groups = {}
    for row in rows:
        groups.setdefault((row[0], row[1]), []).append(tuple(row[2:]))
    return groups


def numbering_problems(pack, manifest, problems):
    counts = manifest["counts"]
    ayat_of = {}
    for surah, number, _ in pack.ayat:
        ayat_of.setdefault(surah, []).append(number)
    for index, (number, ayah_count, place, _, _) in enumerate(pack.surahs):
        if number != index + 1:
            problems.append("surah %d is numbered %d" % (index + 1, number))
        if ayat_of.get(number, []) != list(range(1, ayah_count + 1)):
            problems.append(
                "surah %d: its ayat are not numbered 1 to %d"
                % (number, ayah_count))
        if place not in (None, b"makki", b"madani"):
            problems.append(
                "surah %d: revelation_place is not makki, madani or null"
                % number)
    numbers = {row[0] for row in pack.surahs}
    for surah in sorted(set(ayat_of) - numbers):
        problems.append(
            "the ayah table holds rows of surah %d, which the surah table "
            "lacks" % surah)

    def expect(field, listed, found, where):
        if listed != found:
            problems.append(
                "counts.%s is %d; %s %d" % (field, listed, where, found))

    expect("surahs", counts["surahs"], len(pack.surahs),
           "the surah table holds")
    expect("ayat", counts["ayat"], len(pack.ayat), "the ayah table holds")
    expect("ayat", counts["ayat"], sum(row[1] for row in pack.surahs),
           "surah.ayah_count sums to")
    expect("words", counts["words"],
           sum(len(rows) for rows in pack.words.values()),
           "the word table holds")
    expect("marks", counts["marks"],
           sum(len(rows) for rows in pack.marks.values()),
           "the mark table holds")
    for kind in DIVISION_KINDS:
        found = sum(1 for row in pack.divisions if row[0] == kind.encode())
        expect("divisions.%s" % kind, counts["divisions"][kind], found,
               "the %s rows of the division table number" % kind)
    listed = sum(counts["divisions"].values())
    if listed != len(pack.divisions):
        problems.append(
            "counts.divisions sum to %d; the division table holds %d rows"
            % (listed, len(pack.divisions)))
    expect("sajdas", counts["sajdas"], len(pack.sajdas),
           "the sajda table holds")


_DIVISION_KIND_BYTES = frozenset(kind.encode("ascii") for kind in DIVISION_KINDS)


def reference_problems(pack, problems):
    by_kind = {}
    for kind, number, surah, ayah in pack.divisions:
        if kind not in _DIVISION_KIND_BYTES:
            problems.append("the division table holds a row of an unknown kind")
            continue
        name = kind.decode("ascii")
        by_kind.setdefault(name, []).append((number, surah, ayah))
        if (surah, ayah) not in pack.addresses:
            problems.append(
                "%s %d refers to %d:%d, not an ayah of the pack"
                % (name, number, surah, ayah))
    for kind in DIVISION_KINDS:
        rows = by_kind.get(kind, [])
        for index, (number, surah, ayah) in enumerate(rows):
            if number != index + 1:
                problems.append(
                    "%s %d is numbered %d" % (kind, index + 1, number))
            if index and (surah, ayah) <= rows[index - 1][1:]:
                problems.append(
                    "%s %d does not start after %s %d"
                    % (kind, number, kind, rows[index - 1][0]))
    for surah, ayah in pack.sajdas:
        if (surah, ayah) not in pack.addresses:
            problems.append(
                "a sajda refers to %d:%d, not an ayah of the pack"
                % (surah, ayah))
    for table, groups in (("word", pack.words), ("mark", pack.marks)):
        for surah, ayah in sorted(set(groups) - pack.addresses):
            problems.append(
                "the %s table holds rows of %d:%d, not an ayah of the pack"
                % (table, surah, ayah))


def _decoded(data, where, problems):
    """The stored bytes as a string, or None when they are not strict UTF-8;
    a leading EF BB BF is a problem and is kept."""
    if data.startswith(b"\xef\xbb\xbf"):
        problems.append("%s begins with U+FEFF" % where)
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as e:
        problems.append("%s is not UTF-8 (byte %d)" % (where, e.start))
        return None


def text_problems(pack, manifest, problems):
    """Each decoded basmala and ayah, keyed by where it is, in order."""
    texts = {}
    listed = manifest["surah_sha256"]
    ayat_of = {}
    for surah, number, data in pack.ayat:
        ayat_of.setdefault(surah, []).append((number, data))
    for number, _, _, name, basmala in pack.surahs:
        _decoded(name, "surah %d name" % number, problems)
        digest = hashlib.sha256()
        if basmala is not None:
            where = "surah %d basmala" % number
            texts[where] = _decoded(basmala, where, problems)
            _digest_field(digest, 0, basmala)
        for ayah, data in ayat_of.get(number, []):
            where = "ayah %d:%d" % (number, ayah)
            texts[where] = _decoded(data, where, problems)
            _digest_field(digest, ayah, data)
        key = str(number)
        if key not in listed:
            problems.append(
                "surah %d: surah_sha256 has no entry for it" % number)
        elif digest.hexdigest() != listed[key]:
            problems.append("surah %d: digest differs from surah_sha256" % number)
    numbers = {str(row[0]) for row in pack.surahs}
    for key in sorted(set(listed) - numbers, key=int):
        problems.append(
            "surah_sha256 lists surah %s, which the surah table lacks" % key)
    return texts


def _digest_field(digest, number, data):
    digest.update(struct.pack(">II", number, len(data)))
    digest.update(data)
