"""The editor's footnotes, appended to their passage (D-189).

A page of books 165, 440, 473 and 514 that has footnotes ends with an empty
separator paragraph holding the footnote line (`tafsir_html.SEPARATOR`) and
the note paragraphs below it (`NOTE_OPEN`). A mark, `(` U+2063 N `)` in a
`<sup>`, stays in the passage text as printed; its note is the note paragraph
on the same page whose text opens with `(N)`, with the unnumbered note
paragraphs that follow it up to the next numbered one. After a passage's body
the notes of its marks follow in the marks' order, each paragraph joined by
U+000A like any other. Nothing else is added.

Marks and notes pair one to one per page. Checked on every page where a
shipped passage has a mark, and on the page after one whose last note it
uses, these stop the build (`Case`): an unnumbered note paragraph opening a
page (it may continue the previous page's last note); a number repeated among
a page's marks or notes, or among a passage's marks; a mark without its note
or a note without its mark; a footnote-line paragraph that is not the empty
separator; and a page laid out otherwise (a note above the line, something
else below it, a second line, a note or the line carried as a passage's own
paragraph). The review record settles a case only by excluding the entries
it names, which holds them out (D-186); nothing else is added to the record.

The P2 proof is extended to the passage: `regex_passage_text` rebuilds each
passage from the html by a second path that shares nothing with the
tokenizer or with this module's grouping. Messages name the book, site
pages, numbers and entries only.
"""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass

from .errors import PackError
from .tafsir_html import DIGITS, MARK_CLOSE, MARK_OPEN, NOTE_OPEN, SEPARATOR, regex_text
from .ziydia_inputs import page_paragraphs

KINDS = (
    "unnumbered_note_opens_page",
    "number_repeated_on_page",
    "number_repeated_in_passage",
    "mark_without_note",
    "note_without_mark",
    "separator_not_empty",
    "page_layout",
)
_LINE = re.compile(r"<hr\b", re.I)
_PAGE_MARK = re.compile(re.escape(MARK_OPEN) + "\\(\\u2063(" + DIGITS + ")\\)" + re.escape(MARK_CLOSE))
_NOTE_NUMBER = re.compile(re.escape(NOTE_OPEN) + "(?:<span [^>]*>|&nbsp|[ \\t\\n\\r\\f\\v])*\\((" + DIGITS + ")\\)")


@dataclass(frozen=True)
class Case:
    kind: str  # one of KINDS
    site_page: int
    number: str  # the N as printed, or "" when the case has none
    entries: tuple  # the shipped entries a reviewer would exclude to settle it


@dataclass(frozen=True)
class PageNotes:
    marks: Counter  # N -> marks above the line
    notes: dict  # N -> the note's paragraphs (html), numbered one first
    order: tuple  # the notes' N in page order
    problems: tuple  # (kind, N) found in the page alone


def read_page(html: str, site_page: int) -> PageNotes:
    paragraphs = page_paragraphs(html, site_page)
    problems = []
    lines = [k for k, p in enumerate(paragraphs) if _LINE.search(p)]
    for k in lines:
        if paragraphs[k] != SEPARATOR:
            problems.append(("separator_not_empty", ""))
    if len(lines) > 1:
        problems.append(("page_layout", ""))
    cut = lines[0] if lines else len(paragraphs)
    body, below = paragraphs[:cut], paragraphs[cut + 1 :]
    marks = Counter(n for p in body for n in _PAGE_MARK.findall(p))
    if any(p.startswith(NOTE_OPEN) for p in body):
        problems.append(("page_layout", ""))
    notes, order, current = {}, [], None
    for paragraph in below:
        if not paragraph.startswith(NOTE_OPEN) or "<sup" in paragraph:
            problems.append(("page_layout", ""))
            continue
        number = _NOTE_NUMBER.match(paragraph)
        if number is not None:
            current = number.group(1)
            if current in notes:
                problems.append(("number_repeated_on_page", current))
            else:
                notes[current], order = [], order + [current]
            notes[current].append(paragraph)
        elif current is None:
            problems.append(("unnumbered_note_opens_page", ""))
        else:
            notes[current].append(paragraph)
    return PageNotes(marks, {n: tuple(p) for n, p in notes.items()}, tuple(order), tuple(problems))


def notes_of_marks(shipped_marks: dict, pages: dict):
    """`shipped_marks` maps each shipped entry's n to its marks [(site_page, N)].
    Returns {(site_page, N): note paragraphs} for those marks, and the cases."""
    on_page = {}
    for n, marks in shipped_marks.items():
        for site_page, number in marks:
            on_page.setdefault(site_page, {}).setdefault(number, []).append(n)
    found, cases, following = {}, [], sorted(pages)
    for site_page in sorted(on_page):
        shipped = on_page[site_page]
        entries = tuple(sorted({n for ns in shipped.values() for n in ns}))
        page = read_page(pages[site_page], site_page)
        cases += [Case(kind, site_page, number, entries) for kind, number in page.problems]
        for number, count in sorted(page.marks.items()):
            if count > 1:
                cases.append(Case("number_repeated_on_page", site_page, number, entries))
            if number not in page.notes:
                cases.append(Case("mark_without_note", site_page, number, entries))
        for number in page.order:
            if number not in page.marks:
                cases.append(Case("note_without_mark", site_page, number, entries))
        for number in shipped:
            if number in page.notes:
                found[(site_page, number)] = page.notes[number]
        if page.order and page.order[-1] in shipped:
            later = following.index(site_page) + 1
            if later < len(following):
                after = following[later]
                if ("unnumbered_note_opens_page", "") in read_page(pages[after], after).problems:
                    owners = tuple(sorted(shipped[page.order[-1]]))
                    cases.append(Case("unnumbered_note_opens_page", after, "", owners))
    return found, cases


def repeated_in_passages(groups, shipped_marks: dict) -> list:
    """A number repeated among the marks of one passage (its merged entries),
    naming the entries of the passage that carry that number."""
    cases = []
    for group in groups:
        seen = set()
        for entry in group:
            for site_page, number in shipped_marks.get(entry.n, ()):
                if number in seen:
                    carriers = tuple(e.n for e in group if any(m == number for _, m in shipped_marks.get(e.n, ())))
                    cases.append(Case("number_repeated_in_passage", site_page, number, carriers))
                seen.add(number)
    return cases


def refuse(book: int, cases) -> None:
    if not cases:
        return
    cases = sorted(set(cases), key=lambda c: (c.site_page, c.number, c.kind, c.entries))
    by_kind = Counter(c.kind for c in cases)
    raise PackError(
        "book %d: %d footnote cases stop the build (%s); the review record settles one only by excluding its "
        "entries: %s"
        % (
            book,
            len(cases),
            ", ".join("%s %d" % (kind, by_kind[kind]) for kind in KINDS if by_kind[kind]),
            "; ".join(
                "site page %d%s %s (entries %s)"
                % (c.site_page, " N %d" % int(c.number) if c.number else "", c.kind, ", ".join(map(str, c.entries)))
                for c in cases[:40]
            ),
        )
    )


_SUP = re.compile(r"<sup[^>]*>\(\u2063([^)<]*)\)</sup>")
_NOTE = re.compile(re.escape(NOTE_OPEN) + ".*?</p>", re.S)
_OPENING_NUMBER = re.compile("\\((" + DIGITS + ")\\)")


def regex_passage_text(paragraphs, pages: dict, phrases: dict) -> list:
    """P2 for a whole passage: `paragraphs` are its body's (site_page, html) in
    order. Returns its paragraph texts, body then notes, by regular
    expressions over the html alone."""
    texts = [regex_text(html, phrases) for _, html in paragraphs]
    notes_by_page = {}
    for site_page, html in paragraphs:
        for number in _SUP.findall(html):
            if site_page not in notes_by_page:
                notes_by_page[site_page] = _notes_by_regex(pages[site_page], phrases)
            texts += notes_by_page[site_page].get(number, [])
    return [t for t in texts if t]


def _notes_by_regex(page_html: str, phrases: dict) -> dict:
    notes, current = {}, None
    for html in _NOTE.findall(page_html.partition(SEPARATOR)[2]):
        text = regex_text(html, phrases)
        opening = _OPENING_NUMBER.match(text or "")
        if opening is not None:
            current = opening.group(1)
        notes.setdefault(current, []).append(text)
    return notes
