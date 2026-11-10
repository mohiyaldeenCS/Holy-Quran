"""The Zaydi-library inputs of a tafsir pack, read strictly and tied by their
hashes (docs/plans/B07_TAFSIR_PACK.md, "Inputs are tied by their hashes").

From the extraction (`<extraction>/book_<N>/`, tools/ziydia/ziydia_fetch.py):
`meta.json`, `state.json`, `pages.jsonl`. From the linker (`<links>/book_<N>/`,
tools/ziydia/ziydia_link.py): `passages.jsonl`, `report.json`, `compare.json`,
`sample.html`. And the reviewer's record (D-186). The builder reads the
linker's files and does not import its code; the few facts it needs of the
linker are copied here with their source. Messages name files, fields,
numbers and hashes only.
"""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from . import strict_json as sj
from .digest import sha256_bytes
from .errors import PackError, code_point
from .tafsir_database import BookFacts

SITE_BOOK_URL = "https://ziydia.com/book/%d"  # D-187

# ziydia_link.py PROFILES: the six books with a profile, and the kind of each.
LINKER_PROFILES = {
    183: "bracket_numbers",
    514: "text_and_commentary",
    276: "items",
    440: "footnote_references",
    473: "inner_numbers",
    471: "items",
}
# tools/ziydia/README.md, "What a line of passages.jsonl holds".
ENTRY_KINDS = ("passage", "unlinked", "heading", "text", "title_page", "ornament", "footnote")
# tools/ziydia/README.md, "What compare.json holds".
OUTCOMES = (
    "same",
    "same_but_for_spelling",
    "too_short_to_compare",
    "no_quotation",
    "in_a_neighbouring_ayah",
    "partly_found",
    "elsewhere_in_the_surah",
    "not_found",
    "range_not_usable",
)

# The book card's labels (ziydia_fetch.py parse_book) that a tafsir pack
# knows (D-187): any other label stops the build, an editor's among them.
_TITLE = "\u0627\u0644\u0643\u062a\u0627\u0628"
_AUTHOR = "\u0627\u0644\u0645\u0624\u0644\u0641"
PUBLISHER = "\u0627\u0644\u0646\u0627\u0634\u0631"
EDITION = "\u0627\u0644\u0637\u0628\u0639\u0629"
_PAGES = "\u0639\u062f\u062f \u0627\u0644\u0635\u0641\u062d\u0627\u062a"
CARD_LABELS = (_TITLE, _AUTHOR, PUBLISHER, EDITION, _PAGES)

_META_KEYS = ("id", "url", "title", "author", "date_added", "card")
_META_OPTIONAL = ("category", "author_id", "author_line", "category_id")
_RECORD_KEYS = ("book", "passages_sha256", "compare_sha256", "sample", "cleared", "excluded")
_SAMPLE_KEYS = ("reviewer", "date", "sample_sha256")
_MARK_KEYS = ("n", "reviewer", "date")
_PARAGRAPH = re.compile(r"<p\b[^>]*>.*?</p>", re.S)  # as ziydia_link.py PARA
_FACT_REFUSED = ("\n", "\ufeff", "\ufffd")


@dataclass(frozen=True)
class ReviewMark:
    n: int
    reviewer: str
    date: str


@dataclass(frozen=True)
class ReviewRecord:
    book: int
    passages_sha256: str
    compare_sha256: str
    sample: dict  # reviewer, date, sample_sha256
    cleared: dict  # n -> ReviewMark
    excluded: dict  # n -> ReviewMark
    sha256: str  # of the file's bytes


@dataclass(frozen=True)
class BookInputs:
    book: int
    facts: BookFacts
    url: str
    date_added: str
    pages: dict  # site page -> html
    pages_sha256: str
    entries: list  # the lines of passages.jsonl, in book order
    passages_sha256: str
    outcomes: dict  # n -> compare outcome, for every entry of kind passage
    compare_sha256: str


def read_review_record(data: bytes) -> ReviewRecord:
    """The reviewer's record of one book (ASCII JSON, no text)."""
    try:
        record = sj.fields(sj.load(data, ascii_only=True), _RECORD_KEYS, "the record")
        sample = sj.fields(record["sample"], _SAMPLE_KEYS, "sample")
        return ReviewRecord(
            book=sj.positive_int(record["book"], "book"),
            passages_sha256=sj.sha256(record["passages_sha256"], "passages_sha256"),
            compare_sha256=sj.sha256(record["compare_sha256"], "compare_sha256"),
            sample={
                "reviewer": _name(sample["reviewer"], "sample.reviewer"),
                "date": sj.date(sample["date"], "sample.date"),
                "sample_sha256": sj.sha256(sample["sample_sha256"], "sample.sample_sha256"),
            },
            cleared=_marks(record["cleared"], "cleared"),
            excluded=_marks(record["excluded"], "excluded"),
            sha256=sha256_bytes(data),
        )
    except PackError as error:
        raise PackError("review record: %s" % error) from None


def read_book_inputs(extraction, links, book: int, pages_sha256: str, passages_sha256: str, review: ReviewRecord):
    """Every file of the book, refused unless each hash link holds."""
    source = Path(extraction) / ("book_%d" % book)
    linked = Path(links) / ("book_%d" % book)
    pages_bytes = _read(source / "pages.jsonl")
    passages_bytes = _read(linked / "passages.jsonl")
    compare_bytes = _read(linked / "compare.json")
    _same(sha256_bytes(pages_bytes), pages_sha256, "pages.jsonl", "the description's pages_sha256")
    _same(sha256_bytes(passages_bytes), passages_sha256, "passages.jsonl", "the description's passages_sha256")
    compare_sha256 = sha256_bytes(compare_bytes)
    _check_report(_json(linked / "report.json"), book, pages_sha256, passages_sha256)
    compare = _json_bytes(compare_bytes, "compare.json")
    _check_compare(compare, book, passages_sha256)
    _check_review(review, book, passages_sha256, compare_sha256, sha256_bytes(_read(linked / "sample.html")))
    state = _json(source / "state.json")
    if not isinstance(state, dict) or state.get("done") is not True:
        raise PackError("book_%d/state.json does not say done: the extraction is not complete" % book)
    meta = _json(source / "meta.json")
    facts, url, date_added = _meta(meta, book)
    entries = _entries(passages_bytes, book)
    outcomes = _outcomes(compare, entries)
    _check_marks(review, entries)
    return BookInputs(
        book=book,
        facts=facts,
        url=url,
        date_added=date_added,
        pages=_pages(pages_bytes, book),
        pages_sha256=pages_sha256,
        entries=entries,
        passages_sha256=passages_sha256,
        outcomes=outcomes,
        compare_sha256=compare_sha256,
    )


class PageParagraphs:
    """P3: each paragraph a passage carries is one of its page's paragraphs in
    pages.jsonl, each page paragraph used at most once."""

    def __init__(self, pages: dict):
        self._pages = pages
        self._left = {}

    def take(self, site_page, html: str, where: str) -> None:
        if site_page not in self._left:
            if site_page not in self._pages:
                raise PackError("%s: site page %s is not in pages.jsonl (P3)" % (where, site_page))
            self._left[site_page] = Counter(page_paragraphs(self._pages[site_page], site_page))
        left = self._left[site_page]
        if left[html] < 1:
            raise PackError("%s is not a paragraph of site page %d in pages.jsonl (P3)" % (where, site_page))
        left[html] -= 1


def page_paragraphs(html: str, site_page: int) -> list:
    found = _PARAGRAPH.findall(html)
    if _PARAGRAPH.sub("", html).strip(" \t\n\r\f\v") or not found:
        raise PackError("site page %d is not a sequence of paragraphs" % site_page)
    return found


def _read(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except OSError:
        raise PackError("%s cannot be read" % path) from None


def _json(path: Path):
    return _json_bytes(_read(path), "%s/%s" % (path.parent.name, path.name))


def _json_bytes(data: bytes, name: str):
    try:
        return sj.load(data)
    except PackError as error:
        raise PackError("%s: %s" % (name, error)) from None


def _same(found: str, expected: str, name: str, what: str) -> None:
    if found != expected:
        raise PackError("%s has SHA-256 %s; %s is %s" % (name, found, what, expected))


def _check_report(report, book, pages_sha256, passages_sha256):
    if not isinstance(report, dict) or report.get("book") != book:
        raise PackError("report.json is not the linker's report of book %d" % book)
    if LINKER_PROFILES.get(book) is None or report.get("profile") != LINKER_PROFILES[book]:
        raise PackError("report.json: book %d is not linked with one of the linker's six profiles" % book)
    given = report.get("input")
    found = given.get("pages_sha256") if isinstance(given, dict) else None
    if found != pages_sha256:
        raise PackError("report.json: input.pages_sha256 is not the hash of pages.jsonl")
    if report.get("passages_sha256") != passages_sha256:
        raise PackError("report.json: passages_sha256 is not the hash of passages.jsonl")


def _check_compare(compare, book, passages_sha256):
    if not isinstance(compare, dict) or compare.get("book") != book:
        raise PackError("compare.json is not the comparison of book %d" % book)
    if compare.get("passages_sha256") != passages_sha256:
        raise PackError("compare.json: passages_sha256 is not the hash of passages.jsonl")


def _check_review(review, book, passages_sha256, compare_sha256, sample_sha256):
    if review.book != book:
        raise PackError("review record: book is %d, not %d" % (review.book, book))
    if review.passages_sha256 != passages_sha256:
        raise PackError("review record: passages_sha256 is not the hash of passages.jsonl")
    if review.compare_sha256 != compare_sha256:
        raise PackError("review record: compare_sha256 is not the hash of compare.json")
    if review.sample["sample_sha256"] != sample_sha256:
        raise PackError("review record: sample.sample_sha256 is not the hash of sample.html")


def _meta(meta, book):
    meta = sj.fields(meta, _META_KEYS, "meta.json", optional=_META_OPTIONAL)
    if meta["id"] != book or type(meta["id"]) is not int:
        raise PackError("meta.json: id is not %d" % book)
    url = SITE_BOOK_URL % book
    if meta["url"] != url:
        raise PackError("meta.json: url is not %s" % url)
    date_added = _fact(meta["date_added"], "meta.json date_added")
    if not (date_added.isascii() and date_added.isprintable()):
        raise PackError("meta.json: date_added is not printable ASCII")
    card = meta["card"]
    if not isinstance(card, list):
        raise PackError("meta.json: card is not a list")
    values = {}
    for index, line in enumerate(card):
        where = "meta.json card[%d]" % index
        sj.fields(line, ("label", "value"), where)
        if line["label"] not in CARD_LABELS:
            raise PackError("%s: the label is not one the tafsir pack knows (D-187)" % where)
        if line["label"] in values:
            raise PackError("%s: the label repeats" % where)
        values[line["label"]] = _fact(line["value"], where + " value")
    facts = BookFacts(
        title=_fact(meta["title"], "meta.json title"),
        author=_fact(meta["author"], "meta.json author"),
        publisher=values.get(PUBLISHER),
        edition=values.get(EDITION),
        editor=None,
    )
    return facts, url, date_added


def _fact(value, where):
    if not isinstance(value, str) or not value:
        raise PackError("%s is empty" % where)
    if value[0].isspace() or value[-1].isspace():
        raise PackError("%s has spaces at its edges" % where)
    for c in _FACT_REFUSED:
        if c in value:
            raise PackError("%s holds %s" % (where, code_point(c)))
    return value


def _pages(data: bytes, book: int) -> dict:
    pages = {}
    for number, line in enumerate(_lines(data, "pages.jsonl"), 1):
        where = "pages.jsonl line %d" % number
        page = _line(line, where)
        if page.get("book") != book:
            raise PackError("%s is not a page of book %d" % (where, book))
        site_page = page.get("url_page")
        if not (isinstance(site_page, str) and site_page.isascii() and site_page.isdigit()):
            raise PackError("%s: url_page is not a site page number" % where)
        if not isinstance(page.get("url"), str) or not page["url"].startswith(SITE_BOOK_URL % book + "/"):
            raise PackError("%s: url is not a page of %s" % (where, SITE_BOOK_URL % book))
        html = page.get("html")
        if not isinstance(html, str):
            raise PackError("%s: html is not a string" % where)
        for c in ("\ufffd", "\ufeff"):
            if c in html:
                raise PackError("%s: html holds %s; fetch the page again" % (where, code_point(c)))
        if int(site_page) in pages:
            raise PackError("%s: site page %s comes twice" % (where, site_page))
        pages[int(site_page)] = html
    if not pages:
        raise PackError("pages.jsonl holds no page")
    return pages


def _entries(data: bytes, book: int) -> list:
    entries = []
    for number, line in enumerate(_lines(data, "passages.jsonl"), 1):
        where = "passages.jsonl line %d" % number
        entry = _line(line, where)
        if entry.get("n") != number or type(entry.get("n")) is not int:
            raise PackError("%s: n is not %d" % (where, number))
        if entry.get("book") != book:
            raise PackError("%s is not an entry of book %d" % (where, book))
        if entry.get("kind") not in ENTRY_KINDS:
            raise PackError("%s: the kind is not one the linker writes" % where)
        surah = entry.get("surah")
        if surah is not None and (type(surah) is not int or surah < 1):
            raise PackError("%s: surah is not a surah number or null" % where)
        _refs(entry.get("refs"), where)
        review = entry.get("review")
        if review is not None and not (isinstance(review, list) and review and all(isinstance(r, str) for r in review)):
            raise PackError("%s: review is not a list of flags" % where)
        paragraphs = entry.get("paragraphs")
        if not isinstance(paragraphs, list) or not paragraphs:
            raise PackError("%s has no paragraph" % where)
        for index, paragraph in enumerate(paragraphs, 1):
            if (
                not isinstance(paragraph, dict)
                or type(paragraph.get("site_page")) is not int
                or not isinstance(paragraph.get("html"), str)
            ):
                raise PackError("%s: paragraph %d has no site_page or html" % (where, index))
        entries.append(entry)
    return entries


def _refs(refs, where):
    if not isinstance(refs, list):
        raise PackError("%s: refs is not a list" % where)
    for ref in refs:
        if not (isinstance(ref, list) and len(ref) == 2 and all(type(a) is int for a in ref)):
            raise PackError("%s: a ref is not [first, last]" % where)


def _outcomes(compare, entries) -> dict:
    outcomes = compare.get("outcomes")
    if not isinstance(outcomes, dict):
        raise PackError("compare.json has no outcomes; run ziydia_link.py compare again (Task A)")
    linked = {str(e["n"]) for e in entries if e["kind"] == "passage"}
    if set(outcomes) != linked:
        raise PackError(
            "compare.json: outcomes cover %d entries, not the %d of kind passage" % (len(outcomes), len(linked))
        )
    for key, outcome in outcomes.items():
        if outcome not in OUTCOMES:
            raise PackError("compare.json: the outcome of %s is not one the linker writes" % key)
    return {int(key): outcome for key, outcome in outcomes.items()}


def _check_marks(review, entries):
    for name, marks in (("cleared", review.cleared), ("excluded", review.excluded)):
        for n in sorted(marks):
            entry = entries[n - 1] if n <= len(entries) else None
            if entry is None:
                raise PackError("review record: %s names %d, which passages.jsonl lacks" % (name, n))
            if entry["kind"] != "passage" and not (entry["kind"] == "unlinked" and entry["surah"] is not None):
                raise PackError("review record: %s names %d, an entry that never ships" % (name, n))


def _lines(data: bytes, name: str):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise PackError("%s is not UTF-8 at byte %d" % (name, error.start)) from None
    if text.startswith("\ufeff"):
        raise PackError("%s starts with a byte order mark" % name)
    lines = text.split("\n")
    if lines[-1] != "":
        raise PackError("%s does not end with a line break" % name)
    return [line[:-1] if line.endswith("\r") else line for line in lines[:-1]]


def _line(line: str, where: str) -> dict:
    try:
        value = sj.loads(line)
    except PackError as error:
        raise PackError("%s: %s" % (where, error)) from None
    if not isinstance(value, dict):
        raise PackError("%s is not an object" % where)
    return value


def _marks(value, where):
    if not isinstance(value, list):
        raise PackError("%s is not a list" % where)
    marks = {}
    for index, mark in enumerate(value):
        at = "%s[%d]" % (where, index)
        sj.fields(mark, _MARK_KEYS, at)
        n = sj.positive_int(mark["n"], at + ".n")
        if n in marks:
            raise PackError("%s.n %d repeats" % (at, n))
        marks[n] = ReviewMark(n, _name(mark["reviewer"], at + ".reviewer"), sj.date(mark["date"], at + ".date"))
    return marks


def _name(value, where):
    value = sj.string(value, where)
    if value[0].isspace() or value[-1].isspace():
        raise PackError("%s has spaces at its edges" % where)
    return value
