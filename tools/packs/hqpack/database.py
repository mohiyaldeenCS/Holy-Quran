"""`text.sqlite` of format v1 (docs/CONTENT_PACKS.md, "Text pack").

Every text is bound as the Python str the strict reader produced; Python's
sqlite3 binds a str as its exact UTF-8 bytes. Nothing is stripped,
normalised or re-encoded. Errors name the step and an address only, never a
SQLite message, which can quote a bound value.
"""

from __future__ import annotations

import os
import pathlib
import sqlite3
from contextlib import closing
from dataclasses import dataclass

from .errors import PackError

APPLICATION_ID = 1213288523  # ASCII HQPK
FORMAT_VERSION = 1
MIN_SQLITE = (3, 37, 0)

_FILE = "text.sqlite"

# The DDL of docs/CONTENT_PACKS.md without its comments, in its table order.
_SCHEMA = (
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

# Child table -> (child key columns, parent table, parent key columns).
_FOREIGN_KEYS = {
    "ayah": (("surah",), "surah", ("number",)),
    "word": (("surah", "ayah"), "ayah", ("surah", "number")),
    "mark": (("surah", "ayah"), "ayah", ("surah", "number")),
    "division": (("surah", "ayah"), "ayah", ("surah", "number")),
    "sajda": (("surah", "ayah"), "ayah", ("surah", "number")),
}

_SIDE_FILES = ("-journal", "-wal", "-shm")


@dataclass(frozen=True)
class AyahRow:
    number: int
    text: str
    words: list  # [(start, end)], UTF-16 half-open
    marks: list  # [(after_word, start, end)], UTF-16 half-open


@dataclass(frozen=True)
class SurahRow:
    number: int
    name: str
    revelation_place: str | None
    revelation_order: int | None
    basmala: str | None
    ayat: list


@dataclass(frozen=True)
class StoredTexts:
    names: dict  # surah -> bytes
    basmalas: dict  # surah -> bytes or None
    ayat: dict  # (surah, ayah) -> bytes


def require_sqlite() -> str:
    """The SQLite version; STRICT tables need 3.37 or later."""
    version = sqlite3.sqlite_version
    found = tuple(int(part) for part in version.split(".")[:3])
    if found < MIN_SQLITE:
        raise PackError(
            "SQLite %s found; %s needs %d.%d.%d or later"
            % ((version, _FILE) + MIN_SQLITE)
        )
    return version


def write_text_database(path, surahs, divisions, sajdas) -> None:
    """Writes a new `text.sqlite` at `path`; refuses an existing path."""
    require_sqlite()
    path = os.fspath(path)
    try:
        open(path, "xb").close()
    except FileExistsError:
        raise PackError("%s: the output path already exists" % _FILE) from None
    except OSError as e:
        raise PackError("%s: creating the file failed (%s)" % (_FILE, type(e).__name__)) from None
    try:
        with closing(sqlite3.connect(path, isolation_level=None)) as db:
            _set_header(db)
            _create_tables(db)
            _insert_all(db, surahs, divisions, sajdas)
            _check_foreign_keys(db)
            _run(db, "VACUUM", "vacuum")
    except BaseException:
        _remove(path)
        raise


def read_stored_texts(path) -> StoredTexts:
    """Every name, basmala and ayah as the bytes stored in the file."""
    uri = pathlib.Path(path).absolute().as_uri() + "?mode=ro&immutable=1"
    try:
        with closing(sqlite3.connect(uri, uri=True)) as db:
            surahs = db.execute(
                "SELECT number, CAST(name AS BLOB), CAST(basmala AS BLOB) "
                "FROM surah ORDER BY number"
            ).fetchall()
            ayat = db.execute(
                "SELECT surah, number, CAST(text AS BLOB) FROM ayah "
                "ORDER BY surah, number"
            ).fetchall()
    except sqlite3.Error as e:
        raise PackError(
            "%s: reading the stored texts failed (%s)" % (_FILE, type(e).__name__)
        ) from None
    return StoredTexts(
        names={n: bytes(name) for n, name, _ in surahs},
        basmalas={n: None if b is None else bytes(b) for n, _, b in surahs},
        ayat={(s, a): bytes(text) for s, a, text in ayat},
    )


def _set_header(db) -> None:
    _run(db, "PRAGMA encoding = 'UTF-8'", "setting the encoding")
    _run(db, "PRAGMA application_id = %d" % APPLICATION_ID, "setting application_id")
    _run(db, "PRAGMA user_version = %d" % FORMAT_VERSION, "setting user_version")
    mode = _run(db, "PRAGMA journal_mode = DELETE", "setting journal_mode").fetchone()
    if mode is None or mode[0] != "delete":
        raise PackError("%s: journal_mode is not delete" % _FILE)
    _run(db, "PRAGMA foreign_keys = ON", "enabling foreign keys")
    encoding = _run(db, "PRAGMA encoding", "reading the encoding").fetchone()
    if encoding is None or encoding[0] != "UTF-8":
        raise PackError("%s: the encoding is not UTF-8" % _FILE)


def _create_tables(db) -> None:
    for number, statement in enumerate(_SCHEMA, 1):
        _run(db, statement, "creating table %d of %d" % (number, len(_SCHEMA)))


def _insert_all(db, surahs, divisions, sajdas) -> None:
    _run(db, "BEGIN", "beginning the transaction")
    for surah in surahs:
        _insert_surah(db, surah)
    for kind, number, surah, ayah in divisions:
        _run(
            db,
            "INSERT INTO division VALUES (?, ?, ?, ?)",
            "inserting division %s %s (surah %s, ayah %s)"
            % (_kind_name(kind), number, surah, ayah),
            (kind, number, surah, ayah),
        )
    for surah, ayah in sajdas:
        _run(
            db,
            "INSERT INTO sajda VALUES (?, ?)",
            "inserting sajda %s:%s" % (surah, ayah),
            (surah, ayah),
        )
    _run(db, "COMMIT", "committing")


def _insert_surah(db, surah: SurahRow) -> None:
    where = "surah %s" % surah.number
    _check_text(surah.name, where + " name")
    if surah.basmala is not None:
        _check_text(surah.basmala, where + " basmala")
    _run(
        db,
        "INSERT INTO surah VALUES (?, ?, ?, ?, ?, ?)",
        "inserting " + where,
        (
            surah.number,
            surah.name,
            len(surah.ayat),
            surah.revelation_place,
            surah.revelation_order,
            surah.basmala,
        ),
    )
    for ayah in surah.ayat:
        _insert_ayah(db, surah.number, ayah)


def _insert_ayah(db, surah: int, ayah: AyahRow) -> None:
    address = "%s:%s" % (surah, ayah.number)
    _check_text(ayah.text, "ayah " + address)
    _run(
        db,
        "INSERT INTO ayah VALUES (?, ?, ?)",
        "inserting ayah " + address,
        (surah, ayah.number, ayah.text),
    )
    for number, (start, end) in enumerate(ayah.words, 1):
        _run(
            db,
            "INSERT INTO word VALUES (?, ?, ?, ?, ?)",
            "inserting word %s:%d" % (address, number),
            (surah, ayah.number, number, start, end),
        )
    for number, (after_word, start, end) in enumerate(ayah.marks, 1):
        _run(
            db,
            "INSERT INTO mark VALUES (?, ?, ?, ?, ?, ?)",
            "inserting mark %s:%d" % (address, number),
            (surah, ayah.number, number, after_word, start, end),
        )


def _check_text(value, where: str) -> None:
    if not isinstance(value, str):
        raise PackError("%s: %s is not a string" % (_FILE, where))
    if value.startswith("\ufeff"):
        raise PackError("%s: %s begins with U+FEFF" % (_FILE, where))
    try:
        value.encode("utf-8", "strict")
    except UnicodeEncodeError as e:
        raise PackError(
            "%s: %s holds a lone surrogate at index %d" % (_FILE, where, e.start)
        ) from None


def _check_foreign_keys(db) -> None:
    violations = _run(db, "PRAGMA foreign_key_check", "checking foreign keys")
    tables = sorted({row[0] for row in violations.fetchall()})
    if not tables:
        return
    table = tables[0]
    address = _first_orphan(db, table)
    raise PackError(
        "%s: a row of %s at %s refers to a missing row" % (_FILE, table, address)
    )


def _first_orphan(db, table: str) -> str:
    if table not in _FOREIGN_KEYS:
        return "an unknown address"
    child, parent, key = _FOREIGN_KEYS[table]
    match = " AND ".join("p.%s = c.%s" % (k, c) for k, c in zip(key, child))
    row = _run(
        db,
        "SELECT %s FROM %s AS c WHERE NOT EXISTS (SELECT 1 FROM %s AS p WHERE %s) "
        "ORDER BY %s LIMIT 1"
        % (", ".join("c." + c for c in child), table, parent, match, ", ".join(child)),
        "locating a foreign key violation in " + table,
    ).fetchone()
    return "an unknown address" if row is None else ":".join(str(n) for n in row)


def _kind_name(kind) -> str:
    return kind if kind in ("juz", "hizb", "rub", "page") else "(unknown kind)"


def _run(db, sql: str, step: str, parameters=()):
    try:
        return db.execute(sql, parameters)
    except (sqlite3.Error, ValueError, OverflowError) as e:
        raise PackError(
            "%s: %s failed (%s)" % (_FILE, step, type(e).__name__)
        ) from None


def _remove(path: str) -> None:
    for name in (path,) + tuple(path + side for side in _SIDE_FILES):
        try:
            os.remove(name)
        except FileNotFoundError:
            pass
