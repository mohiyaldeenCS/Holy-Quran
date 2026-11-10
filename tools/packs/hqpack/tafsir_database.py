"""`tafsir.sqlite` of format v2 (docs/CONTENT_PACKS.md, "Tafsir pack").

One book row and its passages. A surah-level passage (D-184) is the reserved
range `first_ayah = last_ayah = 0`; the table's CHECK admits that range or an
ayah range from 1, nothing else. Every text is bound as the Python str it was
given, so sqlite3 stores its exact UTF-8 bytes. Errors name the step, a
passage number and a column only, never a value.
"""

from __future__ import annotations

import pathlib
import sqlite3
from contextlib import closing
from dataclasses import dataclass

from .database import check_text, create_new, remove_partial, run, set_header
from .errors import PackError

FORMAT_VERSION = 2
SURAH_LEVEL = 0  # first_ayah and last_ayah of a surah-level passage

_FILE = "tafsir.sqlite"

# The DDL of docs/CONTENT_PACKS.md without its comments, in its table order.
_SCHEMA = (
    """CREATE TABLE book (
  title     TEXT NOT NULL,
  author    TEXT NOT NULL,
  publisher TEXT,
  edition   TEXT,
  editor    TEXT
) STRICT""",
    """CREATE TABLE passage (
  number     INTEGER PRIMARY KEY,
  surah      INTEGER NOT NULL,
  first_ayah INTEGER NOT NULL,
  last_ayah  INTEGER NOT NULL,
  text       TEXT NOT NULL,
  UNIQUE (surah, first_ayah),
  CHECK (surah >= 1 AND ((first_ayah = 0 AND last_ayah = 0) OR (first_ayah >= 1 AND last_ayah >= first_ayah)))
) STRICT""",
)

_FACTS = ("title", "author", "publisher", "edition", "editor")
_REQUIRED = ("title", "author")


@dataclass(frozen=True)
class BookFacts:
    title: str
    author: str
    publisher: str | None
    edition: str | None
    editor: str | None


@dataclass(frozen=True)
class PassageRow:
    number: int
    surah: int
    first_ayah: int  # SURAH_LEVEL for a surah-level passage
    last_ayah: int
    text: str


@dataclass(frozen=True)
class StoredTafsirTexts:
    book: dict  # column -> bytes, or None for NULL
    passages: dict  # number -> bytes


def write_tafsir_database(path, book: BookFacts, passages) -> None:
    """Writes a new `tafsir.sqlite` at `path`; refuses an existing path."""
    passages = list(passages)
    if not passages:
        raise PackError("%s: there is no passage" % _FILE)
    path = create_new(path, _FILE)
    try:
        with closing(sqlite3.connect(path, isolation_level=None)) as db:
            set_header(db, FORMAT_VERSION, _FILE)
            for number, statement in enumerate(_SCHEMA, 1):
                _run(db, statement, "creating table %d of %d" % (number, len(_SCHEMA)))
            _run(db, "BEGIN", "beginning the transaction")
            _insert_book(db, book)
            for passage in passages:
                _insert_passage(db, passage)
            _run(db, "COMMIT", "committing")
            _run(db, "VACUUM", "vacuum")
    except BaseException:
        remove_partial(path)
        raise


def read_tafsir_texts(path) -> StoredTafsirTexts:
    """The book's facts and every passage's text as the bytes stored."""
    uri = pathlib.Path(path).absolute().as_uri() + "?mode=ro&immutable=1"
    try:
        with closing(sqlite3.connect(uri, uri=True)) as db:
            books = db.execute(
                "SELECT %s FROM book" % ", ".join("CAST(%s AS BLOB)" % c for c in _FACTS)
            ).fetchall()
            passages = db.execute(
                "SELECT number, CAST(text AS BLOB) FROM passage ORDER BY number"
            ).fetchall()
    except sqlite3.Error as e:
        raise PackError(
            "%s: reading the stored texts failed (%s)" % (_FILE, type(e).__name__)
        ) from None
    if len(books) != 1:
        raise PackError("%s: book has %d rows, not 1" % (_FILE, len(books)))
    return StoredTafsirTexts(
        book={c: None if v is None else bytes(v) for c, v in zip(_FACTS, books[0])},
        passages={number: bytes(text) for number, text in passages},
    )


def _insert_book(db, book: BookFacts) -> None:
    values = []
    for column in _FACTS:
        value = getattr(book, column)
        if value is not None or column in _REQUIRED:
            check_text(value, "book." + column, _FILE)
        values.append(value)
    _run(db, "INSERT INTO book VALUES (?, ?, ?, ?, ?)", "inserting the book", values)


def _insert_passage(db, passage: PassageRow) -> None:
    for field in ("number", "surah", "first_ayah", "last_ayah"):
        if type(getattr(passage, field)) is not int:
            raise PackError("%s: a passage's %s is not an integer" % (_FILE, field))
    where = "passage %d" % passage.number
    check_text(passage.text, where, _FILE)
    _run(
        db,
        "INSERT INTO passage VALUES (?, ?, ?, ?, ?)",
        "inserting %s (surah %d, ayat %d..%d)"
        % (where, passage.surah, passage.first_ayah, passage.last_ayah),
        (passage.number, passage.surah, passage.first_ayah, passage.last_ayah, passage.text),
    )


def _run(db, sql, step, parameters=()):
    return run(db, sql, step, parameters, _FILE)
