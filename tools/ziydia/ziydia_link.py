#!/usr/bin/env python3
"""
ziydia_link.py

Links the paragraphs of a book extracted by ziydia_fetch.py to ayat, using only
what the book itself prints: surah headings, ayah numbers in brackets after a
quotation, and the numbers that open a commentary paragraph. Nothing is inferred
from the wording of a quotation and no printed number is corrected. Every
paragraph is carried in the output exactly as it stands in the `html` field of
pages.jsonl; the only paragraphs left out are the lines that divide a page (the
rule of dashes of book 514, the line above the footnotes of book 473), and they
are counted.

Needs Python 3.8+ only. No extra packages.

USAGE
  py ziydia_link.py link 183
  py ziydia_link.py link 514
  py ziydia_link.py names 183 514          (surah names and ayah counts, as printed)
  py ziydia_link.py link 276 --surahs ziydia_links/surahs.json
  py ziydia_link.py link 471 --surahs ziydia_links/surahs.json
  py ziydia_link.py link 473 --surahs ziydia_links/surahs.json
  py ziydia_link.py link 440 --surahs ziydia_links/surahs.json
  py ziydia_link.py compare 183            (after linking 514; any linked book)
  py ziydia_link.py inspect 473            (markup inventory of any book)

  Options: --in DIR      folder written by ziydia_fetch.py   (default: ziydia_out)
           --out DIR     folder for the results              (default: ziydia_links)
           --surahs FILE table written by "names". Needed by 276, 471 and 440. With it,
                         183 and 473 also flag a number beyond the end of its surah.

OUTPUT (folder "ziydia_links/book_<id>"; it holds book text, keep it out of git)
  passages.jsonl  one passage per line: its surah, its ayah ranges, what the link
                  rests on, and its paragraphs with their pages
  report.json     counts, checks, and every point a reviewer must look at
  sample.html     a fixed sample of the linked passages, for the reviewer
  review.html     every passage the linker marked as needing review
  compare.json    written by "compare": the passages whose quotation was not
  compare.html    found in the ayat they are linked to, as book 514 prints them

Books with a profile: 183, 514, 276, 471, 473, 440.

EXIT CODE
  0  done; report.json may still list points for review
  2  stopped: a wrong command line, a missing or unreadable input, or a book that
     broke a rule of its profile (text outside paragraphs, a surah heading that
     cannot be read or is out of place, a paragraph lost). Nothing is guessed:
     fix the profile or the input.
"""

import argparse
import collections
import hashlib
import html as htmllib
import json
import os
import re
import sys

NUM = "[٠-٩]+"
SURAH = "سورة"

PARA = re.compile(r"<p\b[^>]*>.*?</p>", re.S)
HEADING_CLASS = 'class="border-r-4'
QUOTE_OPEN = '<span style="color: #00AA00;font-family: Ziydia-Q;">'
SPAN_EDGE = re.compile(r"<span\b[^>]*>|</span>")
# The site puts U+2063 between a quotation and the reference its editor added.
REF = re.compile(chr(0x2063) + r'<span style="font-size: 0\.8em;">(.*?)</span>', re.S)
REF_NEXT = re.compile(r"\}?" + REF.pattern, re.S)
PARAGRAPH_START = re.compile(r"<p\b[^>]*>(?:&nbsp;?|\s|\{)*")
ORNAMENT = re.compile(r"[\s*]+")
CODE = re.compile(r'<span\s+style="color: #800000;">(.)</span>', re.S)
RED_START = re.compile(
    r'<p\b[^>]*>(?:&nbsp;?|\s)*<span style="color: #be0000;">(.*?)</span>', re.S
)
TAG = re.compile(r"<[^>]+>")
ARABIC_LETTER = re.compile("[ء-يٮ-ۓۺ-ۿ]")
RULE = re.compile(r"(?:-\s*){20,}")
LABEL = re.compile(r"(?:الجزء\s*(\d+)\s*·\s*)?صفحة\s*(\d+)\s*")
NUMBER_LIST = re.compile(r"\(\s*(" + NUM + r"(?:\s*-\s*" + NUM + r")*)\s*\)")
RANGE = NUM + r"(?:\s*-\s*" + NUM + ")?"
NAMED_REF = re.compile(
    r"\[\s*([^\[\]:،٠-٩]+?)\s*[:،]?\s*(" + RANGE + r"(?:\s*،\s*" + RANGE + r")*)\s*،?\s*\]"
)
NAME_MARKS = re.compile("[ً-ْٰـ]")
FOOTNOTE_MARK = re.compile(r"\}?\s*" + chr(0x2063) + r"?\(" + chr(0x2063) + "?(" + NUM + r")\)")
MARK_IN_TEXT = re.compile(chr(0x2063) + r"\(" + chr(0x2063) + "?" + NUM + r"\)")
FOOTNOTE_REF = re.compile(SURAH + r"\s+([^،]+?)\s*،\s*الآية\s*(" + RANGE + r")\s*\.?")

# How each book prints its links. A book without a profile is not linked: run
# "inspect" on it, study the result, then add a profile and its tests.
PROFILES = {
    # Paragraph by paragraph; "(N) سورة <name>" headings; "[N]" after a quotation.
    183: {
        "kind": "bracket_numbers",
        "heading": r"\((" + NUM + r")\)\s*" + SURAH + r"\s+(.+)",
    },
    # The text of the surah above a rule of dashes, the commentary below it; a
    # commentary paragraph opens with "(N)" or "(N - M)".
    514: {
        "kind": "text_and_commentary",
        "front": ["تقديم", "مقدمة المؤلف"],
        "surah_prefix": SURAH + " ",
        "surahs": 114,
    },
    # Numbered items "[N]", each opening with a quotation and "[<surah>: N]";
    # "[N - سورة <name>]" headings (the word may be missing).
    276: {
        "kind": "items",
        "item": r"\[(" + NUM + r")\]",
        "numbered_heading": r"\[(" + NUM + r")\s*-\s*(?:" + SURAH + r"\s+)?(.+?)\s*\]",
    },
    # Numbered questions, each a heading "N - ... {quotation}(k)?"; footnote k of
    # the same page reads "سورة <name>، الآية N".
    440: {
        "kind": "footnote_references",
        "question": r"(" + NUM + r")\s*-",
    },
    # "تفسير غريب سورة <name>" headings in the order 1, 114, 113 ... 2; the ayah
    # number closes the quotation, inside it; footnotes below a line.
    473: {
        "kind": "inner_numbers",
        "surah_heading": r"(?:تفسير\s*)?(?:غريب\s*)?" + SURAH,
        "surahs": 114,
    },
    # Numbered questions "N -"; headings name the surah without its number.
    471: {
        "kind": "items",
        "item": r"(" + NUM + r")\s*-",
        "heading_prefixes": ["ومن سورة ", "تفسير سورة ", "تفسيرسورة ", "سورة "],
    },
}


class LinkError(Exception):
    """The input broke a rule that the linker never works around."""


Paragraph = collections.namedtuple("Paragraph", "html where alone")


def plain(fragment):
    """Text of a fragment, for reading keys only. Never stored."""
    text = TAG.sub("", fragment).replace("&nbsp;", " ").replace("&nbsp", " ")
    return re.sub(r"\s+", " ", htmllib.unescape(text)).strip()


def heading_key(html):
    """A heading's words without the site font's honorific codes."""
    return plain(CODE.sub("", html))


def strip_wrapping(text):
    return text[1:-1].strip() if text.startswith("(") and text.endswith(")") else text


def name_key(name):
    """Lookup key of a surah name: no vowel marks, one form of alif."""
    name = NAME_MARKS.sub("", strip_wrapping(name.strip()))
    return re.sub("[أإآٱ]", "ا", name).strip()


def is_ornament(html):
    """A line of asterisks."""
    return bool(ORNAMENT.fullmatch(plain(html)))


def quotations(html):
    """(start, end, inner) of every quotation span, each read to its own closing tag."""
    found = []
    at = html.find(QUOTE_OPEN)
    while at != -1:
        depth, end = 1, None
        for edge in SPAN_EDGE.finditer(html, at + len(QUOTE_OPEN)):
            depth += -1 if edge.group() == "</span>" else 1
            if depth == 0:
                end = edge.end()
                found.append((at, end, html[at + len(QUOTE_OPEN):edge.start()]))
                break
        if end is None:
            raise LinkError("a quotation span is not closed: %r" % plain(html)[:40])
        at = html.find(QUOTE_OPEN, end)
    return found


def quotations_with_refs(html):
    """(inner, reference or None) per quotation; the reference is the one right after it."""
    pairs = []
    for _, end, inner in quotations(html):
        following = REF_NEXT.match(html, end)
        pairs.append((inner, following.group(1) if following else None))
    return pairs


def read_json(path):
    if not os.path.isfile(path):
        raise LinkError("missing file: %s" % path)
    with open(path, encoding="utf-8") as handle:
        try:
            return json.load(handle)
        except ValueError as error:
            raise LinkError("%s is not readable JSON: %s" % (path, error))


def load_pages(book_dir):
    path = os.path.join(book_dir, "pages.jsonl")
    if not os.path.isfile(path):
        raise LinkError("no pages.jsonl in %s" % book_dir)
    pages = []
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            try:
                page = json.loads(line)
            except ValueError as error:
                raise LinkError("pages.jsonl line %d is not readable: %s" % (number, error))
            if not (
                isinstance(page, dict)
                and str(page.get("url_page", "")).isdigit()
                and isinstance(page.get("page_label"), str)
                and isinstance(page.get("html", 0), (str, type(None)))
            ):
                raise LinkError("pages.jsonl line %d lacks a usable url_page, page_label or html" % number)
            pages.append(page)
    state_path = os.path.join(book_dir, "state.json")
    done = os.path.isfile(state_path) and bool(read_json(state_path).get("done"))
    return pages, done


def split_paragraphs(page):
    """The paragraphs of one page, in order. Everything must be inside one."""
    source = page["html"] or ""
    if chr(0xFFFD) in source:
        raise LinkError("page %s holds U+FFFD; fetch it again" % page["url_page"])
    rest = PARA.sub("", source).strip()
    if rest:
        raise LinkError("page %s has text outside paragraphs: %r" % (page["url_page"], rest[:60]))
    found = PARA.findall(source)
    if not found:
        raise LinkError("page %s has no paragraph" % page["url_page"])
    return found


def page_ref(page):
    """Where a page is, in the site and in print (the site prints the label)."""
    match = LABEL.fullmatch(page["page_label"].replace("\n", " ").strip())
    if not match:
        raise LinkError("page %s: label not understood: %r" % (page["url_page"], page["page_label"]))
    return {
        "site_page": int(page["url_page"]),
        "part": int(match.group(1)) if match.group(1) else 1,
        "printed_page": int(match.group(2)),
    }


def read_book(pages):
    """Each page as a list of Paragraph, and the page reference of every site page."""
    refs, book = {}, []
    for page in pages:
        ref = page_ref(page)
        if ref["site_page"] in refs:
            raise LinkError("site page %d comes twice" % ref["site_page"])
        refs[ref["site_page"]] = ref
        found = split_paragraphs(page)
        book.append([Paragraph(html, ref["site_page"], len(found) == 1) for html in found])
    return book, refs


def parse_bracket_number(text):
    match = re.fullmatch(r"\[(" + NUM + r")(?:\s*-\s*(" + NUM + r"))?\]", text)
    if not match:
        return None
    first = int(match.group(1))
    return [first, int(match.group(2)) if match.group(2) else first]


def parse_named_ref(text):
    """One surah name, then its ayah numbers: "[<name>: N]", "[<name>: N - M]",
    "[<name>: N، M]". The colon may be missing or a comma. A bracket that names
    two surahs, or holds anything else, is not read."""
    match = NAMED_REF.fullmatch(text)
    if not match:
        return None
    refs = []
    for part in re.split(r"\s*،\s*", match.group(2)):
        numbers = [int(found) for found in re.findall(NUM, part)]
        refs.append([numbers[0], numbers[-1]])
    return match.group(1).strip(), refs


class Result:
    def __init__(self, book, kind, page_refs):
        self.book = book
        self.kind = kind
        self.page_refs = page_refs
        self.passages = []
        self.notes = []
        self.counts = {}
        self.checks = {}
        self.surahs = {}
        self.dropped = []

    def note(self, kind, where, detail):
        self.notes.append({"kind": kind, "site_page": where, "detail": detail})

    def add(self, kind, surah, refs, basis, paragraph=None):
        passage = {
            "n": len(self.passages) + 1,
            "book": self.book,
            "kind": kind,
            "surah": surah,
            "refs": refs,
            "basis": basis,
            "paragraphs": [],
        }
        self.passages.append(passage)
        if paragraph is not None:
            self.put(passage, paragraph)
        return passage

    def put(self, passage, paragraph, carried=False, role=None):
        entry = dict(self.page_refs[paragraph.where])
        entry["html"] = paragraph.html
        if carried:
            entry["carried"] = True
        if role:
            entry["role"] = role
        passage["paragraphs"].append(entry)

    def flag(self, passage, reason):
        """Marks a link as one that a person must check before it is used."""
        reasons = passage.setdefault("review", [])
        if reason not in reasons:
            reasons.append(reason)


def first_page(passage):
    return passage["paragraphs"][0]["site_page"]


def flag_order(result, passages):
    """Flags where the first ayah number of a passage is lower than the one before.

    One of the two numbers is out of place. If the numbers around them show
    which, only that passage is flagged; otherwise both are.
    """
    firsts = [p["refs"][0][0] for p in passages]
    for i in range(1, len(passages)):
        if firsts[i] >= firsts[i - 1]:
            continue
        before = firsts[i - 2] if i >= 2 else None
        after = firsts[i + 1] if i + 1 < len(passages) else None
        # Would the order hold with this passage left out? And with the one before?
        without_current = after is None or firsts[i - 1] <= after
        without_previous = (before is None or before <= firsts[i]) and (
            after is None or firsts[i] <= after
        )
        if without_current and not without_previous:
            flagged = [passages[i]]
        elif without_previous and not without_current:
            flagged = [passages[i - 1]]
        else:
            flagged = [passages[i - 1], passages[i]]
        for passage in flagged:
            result.flag(passage, "ayah_number_out_of_order")
        result.note(
            "ayah_order_goes_back",
            first_page(passages[i]),
            "surah %s: %d after %d (passages %d and %d)"
            % (passages[i]["surah"], firsts[i], firsts[i - 1], passages[i - 1]["n"], passages[i]["n"]),
        )


def flag_ranges(result, passage, ayat):
    """Flags a range that is not one, or that passes the surah's last ayah."""
    last = ayat.get(passage["surah"]) if ayat else None
    for first, end in passage["refs"]:
        if end < first or first < 1:
            result.flag(passage, "range_is_not_valid")
        elif last is not None and end > last:
            result.flag(passage, "ayah_beyond_the_end_of_the_surah")


# ----------------------------------------------------------------------------
# Book 183: the heading prints the surah number; a quotation is followed by the
# ayah number in brackets.


def link_bracket_numbers(book, profile, result, table):
    heading_re = re.compile(profile["heading"])
    surah = None
    current = None
    for paragraph in (p for page in book for p in page):
        if HEADING_CLASS in paragraph.html:
            key = heading_key(paragraph.html)
            match = heading_re.fullmatch(key)
            if not match:
                raise LinkError("page %d: heading not understood: %r" % (paragraph.where, key))
            if int(match.group(1)) != (surah or 0) + 1:
                raise LinkError("page %d: heading %r after surah %s" % (paragraph.where, key, surah))
            surah = int(match.group(1))
            result.surahs[surah] = {"name_in_book": match.group(2).strip(), "number": "printed"}
            result.add("heading", surah, [], "heading", paragraph)["heading"] = key
            current = None
            continue
        refs = []
        for raw in REF.findall(paragraph.html):
            ref = parse_bracket_number(plain(raw))
            if ref is None:
                result.note("bracket_is_not_a_number", paragraph.where, plain(raw))
            else:
                refs.append(ref)
        basis = "heading" if surah else "none"
        if refs and surah is not None:
            current = result.add("passage", surah, refs, "heading+number", paragraph)
            if any(b[0] < a[0] for a, b in zip(refs, refs[1:])):
                result.flag(current, "ayah_number_out_of_order")
        elif is_ornament(paragraph.html):
            result.add("ornament", surah, [], basis, paragraph)
            current = None
        elif current is not None and current["kind"] == "passage" and QUOTE_OPEN in paragraph.html:
            # It quotes something of its own and prints no number for it.
            current = result.add("unlinked", surah, [], basis, paragraph)
            result.note("quotation_without_a_number", paragraph.where, "passage %d" % current["n"])
        elif current is not None:
            result.put(current, paragraph, carried=current["kind"] == "passage")
        else:
            current = result.add("unlinked", surah, [], basis, paragraph)
    linked = [p for p in result.passages if p["kind"] == "passage"]
    for number in result.surahs:
        flag_order(result, [p for p in linked if p["surah"] == number])
    for passage in linked:
        flag_ranges(result, passage, table["ayat"] if table else None)
    result.checks["passages_with_more_than_one_number"] = sum(
        1 for p in linked if len(p["refs"]) > 1
    )


# ----------------------------------------------------------------------------
# Book 514: each page prints the text of the surah, then a rule of dashes, then
# the commentary. The text carries the ayah numbers; a commentary paragraph that
# opens with "(N)" or "(N - M)" starts the commentary on those ayat. Every surah
# starts on a new page, after a page that holds its title alone.


def text_numbers(html):
    """Ayah numbers printed inside a paragraph made of quotations only.

    Returns (numbers, words_follow_the_last_number), or None when the paragraph
    has any word outside its quotations.
    """
    quotes = quotations(html)
    if not quotes:
        return None
    outside, at = "", 0
    for start, end, _ in quotes:
        outside += html[at:start]
        at = end
    if re.sub(r"[{}\s]", "", plain(outside + html[at:])):
        return None
    joined = " ".join(plain(inner) for _, _, inner in quotes)
    numbers = [int(found) for found in re.findall(NUM, joined)]
    tail = re.split(NUM, joined)[-1]
    return numbers, bool(ARABIC_LETTER.search(tail))


class TextAndCommentary:
    def __init__(self, profile, result):
        self.profile = profile
        self.result = result
        self.surah = None
        self.heading = None
        self.closed = 0  # the last ayah number printed so far in the text of this surah
        self.inside_ayah = False  # words of the next ayah were printed; its number comes later
        self.first_text = False  # the next text paragraph is the first one of its surah
        self.commentary = None  # the passage that unnumbered commentary continues
        self.held = None  # a page of one line, until the next paragraph says what it is
        self.printed = {}
        self.openings = {}

    def link(self, book):
        for page in book:
            below = False
            for index, paragraph in enumerate(page):
                text = plain(paragraph.html)
                rule = RULE.match(text) if not below else None
                if rule:
                    below = True
                    text = text[rule.end():]
                    if not text:
                        self.result.dropped.append(paragraph.html)
                        continue
                if HEADING_CLASS in paragraph.html:
                    self.take_heading(paragraph, first_on_page=index == 0)
                elif paragraph.alone and not below and text_numbers(paragraph.html) is None:
                    self.release_held(False)
                    self.held = paragraph
                else:
                    self.release_held(False)
                    if self.surah is None:
                        self.take_front(paragraph)
                    elif below:
                        self.take_commentary(paragraph, text)
                    else:
                        self.take_text(paragraph)
        self.release_held(False)
        self.end_surah(book[-1][-1].where if book else None)
        if len(self.result.surahs) != self.profile["surahs"]:
            raise LinkError(
                "found %d surah headings, expected %d" % (len(self.result.surahs), self.profile["surahs"])
            )
        self.check()

    def release_held(self, before_surah_heading):
        held, self.held = self.held, None
        if held is None:
            return
        if before_surah_heading:
            self.result.add("title_page", None, [], "none", held)
        elif self.surah is None:
            self.take_front(held)
        else:
            self.result.note("paragraph_above_the_rule_is_not_a_quotation", held.where, "")
            self.result.add("unlinked", self.surah, [], "heading", held)

    def take_front(self, paragraph):
        if self.commentary is None:
            self.commentary = self.result.add("unlinked", None, [], "none")
        self.result.put(self.commentary, paragraph)

    def take_heading(self, paragraph, first_on_page):
        key = strip_wrapping(heading_key(paragraph.html))
        result, prefix = self.result, self.profile["surah_prefix"]
        if self.heading is not None and key == self.heading["heading"]:
            if first_page(self.heading) != paragraph.where:
                raise LinkError("page %d: heading printed again: %r" % (paragraph.where, key))
            self.release_held(False)
            result.put(self.heading, paragraph)
            return
        if self.surah is None and key in self.profile["front"]:
            self.release_held(False)
            self.heading = result.add("heading", None, [], "none", paragraph)
            self.heading["heading"] = key
            self.commentary = None
            return
        name = key[len(prefix):].strip()
        if not key.startswith(prefix) or not name:
            raise LinkError("page %d: heading not understood: %r" % (paragraph.where, key))
        if not first_on_page:
            raise LinkError("page %d: surah heading is not at the top: %r" % (paragraph.where, key))
        if any(info["name_in_book"] == name for info in result.surahs.values()):
            raise LinkError("page %d: surah heading printed again: %r" % (paragraph.where, key))
        if self.held is not None and strip_wrapping(plain(self.held.html)) != key:
            result.note("title_page_differs_from_the_heading", paragraph.where, key)
        self.release_held(True)
        self.end_surah(paragraph.where)
        self.surah = (self.surah or 0) + 1
        self.closed, self.inside_ayah, self.first_text = 0, False, True
        self.printed[self.surah] = []
        result.surahs[self.surah] = {"name_in_book": name, "number": "by order"}
        self.heading = result.add("heading", self.surah, [], "heading", paragraph)
        self.heading["heading"] = key
        self.commentary = None

    def end_surah(self, where):
        if self.surah is not None and self.inside_ayah:
            self.result.note(
                "surah_ends_inside_an_ayah", where, "surah %d after ayah %d" % (self.surah, self.closed)
            )

    def take_text(self, paragraph):
        result = self.result
        found = text_numbers(paragraph.html)
        if found is None:
            result.note("paragraph_above_the_rule_is_not_a_quotation", paragraph.where, "")
            result.add("unlinked", self.surah, [], "heading", paragraph)
            return
        numbers, tail = found
        block = result.add("text", self.surah, [], "printed_numbers")
        first_text, self.first_text = self.first_text, False
        if not numbers and first_text:
            # The line a surah opens with. It has no number of its own.
            result.put(block, paragraph, role="opening")
            digest = hashlib.sha256(paragraph.html.encode("utf-8")).hexdigest()
            self.openings.setdefault(digest, []).append(self.surah)
            return
        expected = self.closed + 1
        for number in numbers:
            if number != expected:
                result.note(
                    "text_number_out_of_sequence",
                    paragraph.where,
                    "surah %d: %d where %d was expected" % (self.surah, number, expected),
                )
            expected = number + 1
        self.printed[self.surah].extend(numbers)
        block["starts_inside_ayah"] = self.inside_ayah
        block["ends_inside_ayah"] = tail or not numbers
        if numbers:
            block["refs"] = [[numbers[0], numbers[-1] + 1 if tail else numbers[-1]]]
            self.closed, self.inside_ayah = numbers[-1], tail
        else:
            block["refs"] = [[self.closed + 1, self.closed + 1]]
            self.inside_ayah = True
        result.put(block, paragraph)

    def take_commentary(self, paragraph, text):
        """`text` is the paragraph's words after the rule, if the rule is joined to it."""
        result = self.result
        opening = NUMBER_LIST.match(text)
        if opening is None:
            if re.match(r"\(\s*\d", text):
                result.note("opening_number_not_understood", paragraph.where, text[:20])
            if is_ornament(paragraph.html):
                result.add("ornament", self.surah, [], "heading", paragraph)
                return
            if self.commentary is None:
                self.commentary = result.add("unlinked", self.surah, [], "heading")
            result.put(self.commentary, paragraph, carried=self.commentary["kind"] == "passage")
            return
        numbers = [int(found) for found in re.findall(NUM, opening.group(1))]
        self.commentary = result.add(
            "passage", self.surah, [[numbers[0], numbers[-1]]], "heading+number", paragraph
        )
        if len(numbers) > 2 and numbers != list(range(numbers[0], numbers[-1] + 1)):
            result.flag(self.commentary, "numbers_are_not_a_range")

    def check(self):
        result = self.result
        ayat = {}
        for number, numbers in self.printed.items():
            info = result.surahs[number]
            info["last_ayah_number"] = ayat[number] = max(numbers) if numbers else None
            if not numbers:
                result.note("surah_text_has_no_number", None, "surah %d" % number)
                continue
            missing = sorted(set(range(1, max(numbers) + 1)) - set(numbers))
            if missing:
                result.note(
                    "text_numbers_not_printed",
                    None,
                    "surah %d: %d of 1..%d, first %s" % (number, len(missing), max(numbers), missing[:5]),
                )
        check_commentary(result, ayat)
        with_opening = sorted(n for group in self.openings.values() for n in group)
        result.checks["opening_lines"] = {
            "surahs_with_one": len(with_opening),
            "surahs_without": sorted(set(result.surahs) - set(with_opening)),
            "different_lines": len(self.openings),
        }
        if len(self.openings) > 1:
            result.note("opening_lines_differ", None, "%d different lines" % len(self.openings))
        result.checks["title_pages"] = sum(1 for p in result.passages if p["kind"] == "title_page")


def check_commentary(result, ayat):
    """Checks the numbers that open commentary paragraphs, surah by surah."""
    linked = [p for p in result.passages if p["kind"] == "passage"]
    complete = 0
    for number in result.surahs:
        passages = [p for p in linked if p["surah"] == number]
        for passage in passages:
            flag_ranges(result, passage, ayat)
        flag_order(result, passages)
        last = ayat.get(number)
        covered = set()
        reached = 0
        valid = [p for p in passages if p["refs"][0][0] <= p["refs"][0][1]]
        for index, passage in enumerate(valid):
            first, end = passage["refs"][0]
            if index and valid[index - 1]["refs"][0][0] <= first <= valid[index - 1]["refs"][0][1]:
                result.note(
                    "ayah_opened_twice", first_page(passage), "surah %d: ayah %d" % (number, first)
                )
            covered.update(range(first, end + 1))
            reached = max(reached, end)
            following = valid[index + 1]["refs"][0][0] if index + 1 < len(valid) else (last or end) + 1
            if following > reached + 1:
                # Its unnumbered paragraphs may belong to the ayat that no number opens.
                result.flag(passage, "the_ayat_after_it_have_no_number")
        if last:
            missing = sorted(set(range(1, last + 1)) - covered)
            result.surahs[number]["ayat_without_commentary_number"] = missing
            if missing:
                result.note("ayat_not_opened_by_any_number", None, "surah %d: %s" % (number, missing[:12]))
            else:
                complete += 1
    result.checks["surahs_whose_every_ayah_is_opened"] = complete


# ----------------------------------------------------------------------------
# Book 473: the surahs come in the order 1, then 114 down to 2, each under a
# heading that holds the word for surah. A quotation closes with the number of
# its ayah, printed inside it. Footnotes follow a line at the foot of the page.


def above_and_below_the_line(page, result):
    """The paragraphs of a page before its footnote line, and the footnotes after it.

    The line itself, a paragraph that holds nothing else, is left out and counted.
    """
    body, footnotes, below = [], [], False
    for paragraph in page:
        if not below and "<hr" in paragraph.html:
            below = True
            if not plain(paragraph.html):
                result.dropped.append(paragraph.html)
                continue
        (footnotes if below else body).append(paragraph)
    return body, footnotes


def keep_footnotes(footnotes, result):
    if footnotes:
        passage = result.add("footnote", None, [], "none")
        for paragraph in footnotes:
            result.put(passage, paragraph)


def inner_numbers(inner):
    """(words, ayah number) for each number printed inside one quotation.

    A footnote mark that fell inside the quotation is not an ayah number.
    """
    parts = re.split("(" + NUM + ")", MARK_IN_TEXT.sub(" ", plain(inner)))
    return [(parts[i], int(parts[i + 1])) for i in range(0, len(parts) - 1, 2)]


def link_inner_numbers(book, profile, result, table):
    order = [1] + list(range(profile["surahs"], 1, -1))
    surah_heading = re.compile(profile["surah_heading"])
    names = table["names"] if table else {}
    surah = None
    current = None
    agree = unnumbered = 0
    for page in book:
        body, footnotes = above_and_below_the_line(page, result)
        for paragraph in body:
            html = paragraph.html
            if HEADING_CLASS in html:
                key = heading_key(html)
                if SURAH in key:
                    if not surah_heading.match(key):
                        raise LinkError("page %d: heading not understood: %r" % (paragraph.where, key))
                    if len(result.surahs) == len(order):
                        raise LinkError("page %d: one surah heading too many: %r" % (paragraph.where, key))
                    surah = order[len(result.surahs)]
                    name = key.split(SURAH, 1)[1].split(chr(0x2063))[0].strip(" :")
                    result.surahs[surah] = {"name_in_book": name, "number": "by order"}
                    known = names.get(name_key(name))
                    agree += known == surah
                    if known not in (None, surah):
                        result.note("heading_name_is_another_surah_in_the_table", paragraph.where, key)
                heading = result.add("heading", surah, [], "heading" if surah else "none", paragraph)
                heading["heading"] = key
                current = None
                continue
            basis = "heading" if surah else "none"
            refs = [[n, n] for _, _, inner in quotations(html) for _, n in inner_numbers(inner)]
            if refs and surah is not None:
                current = result.add("passage", surah, refs, "heading+number", paragraph)
                if any(b[0] < a[0] for a, b in zip(refs, refs[1:])):
                    result.flag(current, "ayah_number_out_of_order")
            elif is_ornament(html):
                result.add("ornament", surah, [], basis, paragraph)
            elif QUOTE_OPEN in html and surah is not None:
                # It quotes something and prints no number for it.
                current = result.add("unlinked", surah, [], basis, paragraph)
                unnumbered += 1
            elif current is not None:
                result.put(current, paragraph, carried=current["kind"] == "passage")
            else:
                current = result.add("unlinked", surah, [], basis, paragraph)
        keep_footnotes(footnotes, result)
    if len(result.surahs) != len(order):
        raise LinkError("found %d surah headings, expected %d" % (len(result.surahs), len(order)))
    linked = [p for p in result.passages if p["kind"] == "passage"]
    for number in result.surahs:
        flag_order(result, [p for p in linked if p["surah"] == number])
    for passage in linked:
        flag_ranges(result, passage, table["ayat"] if table else None)
    result.checks["headings_named_as_the_table_names_that_surah"] = agree
    result.checks["passages_with_more_than_one_number"] = sum(1 for p in linked if len(p["refs"]) > 1)
    result.checks["quotation_paragraphs_without_a_number"] = unnumbered


# ----------------------------------------------------------------------------
# Book 440: numbered questions. Each is a heading that quotes the words asked
# about; a footnote mark follows the quotation, and that footnote, on the same
# page, names the surah and the ayah.


def read_footnote_reference(paragraph, number, footnotes, names, result):
    """(surah, ayah ranges) that the footnote of a question's quotation gives."""
    html = paragraph.html
    mark = FOOTNOTE_MARK.match(plain(html[quotations(html)[0][1]:]))
    if mark is None:
        result.note("question_without_a_footnote_mark", paragraph.where, "question %d" % number)
        return None, []
    text = footnotes.get(int(mark.group(1)))
    reference = FOOTNOTE_REF.fullmatch(text) if text is not None else None
    if reference is None:
        kind = "footnote_not_on_the_page" if text is None else "footnote_not_understood"
        result.note(kind, paragraph.where, "question %d, footnote %s" % (number, mark.group(1)))
        return None, []
    surah = names.get(name_key(reference.group(1)))
    if surah is None:
        result.note("surah_name_not_in_the_table", paragraph.where, "question %d" % number)
        return None, []
    numbers = [int(n) for n in re.findall(NUM, reference.group(2))]
    return surah, [[numbers[0], numbers[-1]]]


def link_footnote_references(book, profile, result, table):
    question_re = re.compile(profile["question"])
    current = None
    last = None
    for page in book:
        body, footnotes = above_and_below_the_line(page, result)
        texts = {}
        for paragraph in footnotes:
            red = RED_START.match(paragraph.html)
            mark = NUMBER_LIST.fullmatch(plain(red.group(1))) if red else None
            if mark and "-" not in mark.group(1):
                if int(mark.group(1)) in texts:
                    raise LinkError("page %d: footnote %s comes twice" % (paragraph.where, mark.group(1)))
                texts[int(mark.group(1))] = plain(paragraph.html)[len(plain(red.group(1))):].strip()
        for paragraph in body:
            html = paragraph.html
            # A numbered heading with no quotation is a chapter of the introduction.
            asks = HEADING_CLASS in html and QUOTE_OPEN in html
            question = question_re.match(heading_key(html)) if asks else None
            if question:
                number = int(question.group(1))
                if last is not None and number != last + 1:
                    result.note("question_number_out_of_sequence", paragraph.where, "%d after %d" % (number, last))
                last = number
                surah, refs = read_footnote_reference(paragraph, number, texts, table["names"], result)
                current = result.add(
                    "passage" if refs else "unlinked", surah, refs, "footnote" if refs else "none", paragraph
                )
                current["item"] = number
                if refs:
                    flag_ranges(result, current, table["ayat"])
                    inside = [n for _, n in inner_numbers(quotations(html)[0][2])]
                    if inside and inside[-1] != refs[0][1]:
                        result.flag(current, "number_in_the_quotation_differs_from_the_footnote")
            elif HEADING_CLASS in html:
                result.add("heading", None, [], "none", paragraph)["heading"] = heading_key(html)
                current = None
            elif is_ornament(html):
                result.add("ornament", None, [], "none", paragraph)
            else:
                if current is None:
                    current = result.add("unlinked", None, [], "none")
                result.put(current, paragraph, carried="item" in current)
        keep_footnotes(footnotes, result)
    questions = [p for p in result.passages if "item" in p]
    result.checks["questions"] = len(questions)
    result.checks["questions_linked"] = sum(1 for p in questions if p["kind"] == "passage")


# ----------------------------------------------------------------------------
# Books 276 and 471: numbered items, each opening with a quotation followed by
# "[<surah name>: N]".


def read_item_heading(key, where, profile, names, last_number, result):
    """The surah a heading gives, or None. A numbered heading teaches its name."""
    if "numbered_heading" in profile:
        match = re.fullmatch(profile["numbered_heading"], key)
        if match:
            number, name = int(match.group(1)), match.group(2).strip()
            known = names.get(name_key(name))
            if number <= last_number:
                result.note("heading_number_does_not_rise", where, key)
                return None
            if known is not None and known != number:
                result.note("heading_number_differs_from_the_table", where, key)
                return None
            if known is None:
                names[name_key(name)] = number
                result.note("surah_name_taken_from_the_heading", where, key)
            result.surahs[number] = {"name_in_book": name, "number": "printed"}
            return number
    for prefix in profile.get("heading_prefixes", []):
        if key.startswith(prefix):
            name = key[len(prefix):].strip()
            surah = names.get(name_key(name))
            if surah is not None:
                result.surahs.setdefault(surah, {"name_in_book": name, "number": "from the table"})
                return surah
            break
    if SURAH in key:
        result.note("surah_heading_not_understood", where, key)
    return None


def read_item_reference(paragraph, number, names, result):
    """(surah, ayah ranges) from the first reference of an item, or (None, [])."""
    raw = [plain(found) for found in REF.findall(paragraph.html)]
    if not raw:
        result.note("item_without_a_reference", paragraph.where, "item %d" % number)
        return None, []
    parsed = parse_named_ref(raw[0])
    if parsed is None:
        result.note("reference_not_understood", paragraph.where, "item %d: %s" % (number, raw[0]))
        return None, []
    surah = names.get(name_key(parsed[0]))
    if surah is None:
        result.note("surah_name_not_in_the_table", paragraph.where, "item %d: %s" % (number, raw[0]))
        return None, []
    return surah, parsed[1]


def opens_with_reference(html):
    """Does the paragraph open with a quotation that its own reference follows?"""
    start = PARAGRAPH_START.match(html).end()
    first = quotations(html)[:1]
    return bool(first) and first[0][0] == start and REF_NEXT.match(html, first[0][1]) is not None


def link_items(book, profile, result, table):
    item_re = re.compile(profile["item"])
    names = dict(table["names"])
    heading_surah = None
    last_heading_number = 0
    last_item = None
    restart_allowed = True
    current = None
    for paragraph in (p for page in book for p in page):
        basis = "heading" if heading_surah else "none"
        if HEADING_CLASS in paragraph.html:
            key = heading_key(paragraph.html)
            heading_surah = read_item_heading(
                key, paragraph.where, profile, names, last_heading_number, result
            )
            if "numbered_heading" in profile and heading_surah:
                last_heading_number = heading_surah
            heading = result.add("heading", heading_surah, [], "heading" if heading_surah else "none", paragraph)
            heading["heading"] = key
            current, restart_allowed = None, True
            continue
        red = RED_START.match(paragraph.html)
        item = item_re.fullmatch(plain(red.group(1))) if red else None
        if item is None:
            if is_ornament(paragraph.html):
                result.add("ornament", heading_surah, [], basis, paragraph)
                continue
            if current is None:
                current = result.add("unlinked", heading_surah, [], basis)
            result.put(current, paragraph, carried="item" in current)
            if current["kind"] == "passage" and opens_with_reference(paragraph.html):
                # It opens as an item does, with a quotation and its reference.
                result.flag(current, "carried_paragraph_opens_with_its_own_reference")
            continue
        number = int(item.group(1))
        restarts = number == 1 and restart_allowed
        if last_item is not None and number != last_item + 1 and not restarts:
            result.note("item_number_out_of_sequence", paragraph.where, "%d after %d" % (number, last_item))
        last_item, restart_allowed = number, False
        surah, refs = read_item_reference(paragraph, number, names, result)
        if not refs:
            current = result.add("unlinked", heading_surah, [], basis, paragraph)
        else:
            agrees = heading_surah == surah
            current = result.add(
                "passage", surah, refs, "heading+reference" if agrees else "reference", paragraph
            )
            flag_ranges(result, current, table["ayat"])
            if heading_surah is not None and not agrees:
                result.flag(current, "reference_names_another_surah_than_the_heading")
        current["item"] = number
    items = [p for p in result.passages if "item" in p]
    result.checks["items"] = len(items)
    result.checks["items_linked"] = sum(1 for p in items if p["kind"] == "passage")
    result.checks["items_linked_by_heading_and_reference"] = sum(
        1 for p in items if p["basis"] == "heading+reference"
    )


# ----------------------------------------------------------------------------


RESULT_FILES = [
    "passages.jsonl", "report.json", "sample.html", "review.html", "compare.json", "compare.html",
]


def load_table(path):
    table = read_json(path)
    try:
        return {
            "names": dict(table["names"]),
            "ayat": {int(number): int(count) for number, count in table["ayat"].items()},
        }
    except (KeyError, TypeError, ValueError, AttributeError):
        raise LinkError("%s is not a table written by names" % path)


def run_link(book, in_dir, out_dir, table_path=None):
    profile = PROFILES.get(book)
    if profile is None:
        raise LinkError("book %d has no profile; run inspect on it first" % book)
    book_dir = os.path.join(in_dir, "book_%d" % book)
    folder = os.path.join(out_dir, "book_%d" % book)
    pages, done = load_pages(book_dir)
    for name in RESULT_FILES:
        # A run that stops must not leave an earlier run's files to be taken for its own.
        if os.path.isfile(os.path.join(folder, name)):
            os.remove(os.path.join(folder, name))
    paragraphs, page_refs = read_book(pages)
    result = Result(book, profile["kind"], page_refs)
    if not done:
        result.note("extraction_not_marked_complete", None, "state.json does not say done")
    table = load_table(table_path) if table_path else None
    if profile["kind"] == "bracket_numbers":
        link_bracket_numbers(paragraphs, profile, result, table)
    elif profile["kind"] == "text_and_commentary":
        TextAndCommentary(profile, result).link(paragraphs)
    elif profile["kind"] == "inner_numbers":
        link_inner_numbers(paragraphs, profile, result, table)
    elif table is None:
        raise LinkError("book %d needs --surahs (the table written by names)" % book)
    elif profile["kind"] == "footnote_references":
        link_footnote_references(paragraphs, profile, result, table)
    else:
        link_items(paragraphs, profile, result, table)
    finish(result, paragraphs)
    inputs = {
        "pages_sha256": file_sha256(os.path.join(book_dir, "pages.jsonl")),
        "surahs_table_sha256": file_sha256(table_path) if table_path else None,
    }
    write_result(result, folder, inputs)
    return result


def usable(passage):
    return passage["kind"] == "passage" and "review" not in passage


def finish(result, book):
    """Proves that no paragraph was lost, doubled or changed, then counts."""
    given = collections.Counter(p.html for page in book for p in page)
    kept = collections.Counter(e["html"] for p in result.passages for e in p["paragraphs"])
    if any(re.search(r"\w", plain(html)) for html in result.dropped):
        raise LinkError("a paragraph that holds words was left out as a dividing line")
    if given != kept + collections.Counter(result.dropped):
        raise LinkError(
            "paragraphs differ between input and output: %d in, %d out, %d rules dropped"
            % (sum(given.values()), sum(kept.values()), len(result.dropped))
        )
    by_kind = collections.Counter(p["kind"] for p in result.passages)
    linked = [p for p in result.passages if p["kind"] == "passage"]
    unlinked = [p for p in result.passages if p["kind"] == "unlinked"]
    result.counts = {
        "pages": len(book),
        "paragraphs": sum(given.values()),
        "rules_dropped": len(result.dropped),
        "passages_by_kind": dict(sorted(by_kind.items())),
        "linked_passages": len(linked),
        "linked_passages_needing_review": sum(1 for p in linked if not usable(p)),
        "paragraphs_in_linked_passages": sum(len(p["paragraphs"]) for p in linked),
        "paragraphs_carried": sum(
            1 for p in linked for entry in p["paragraphs"] if entry.get("carried")
        ),
        "surahs_with_a_linked_passage": len({p["surah"] for p in linked}),
        "paragraphs_linked_to_a_surah_only": sum(
            len(p["paragraphs"]) for p in unlinked if p["surah"] is not None
        ),
        "paragraphs_with_no_link": sum(len(p["paragraphs"]) for p in unlinked if p["surah"] is None),
        "notes": len(result.notes),
    }


def write_json(path, value):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=1, sort_keys=True)
        handle.write("\n")


def write_result(result, folder, inputs):
    os.makedirs(folder, exist_ok=True)
    passages_path = os.path.join(folder, "passages.jsonl")
    with open(passages_path, "w", encoding="utf-8", newline="\n") as handle:
        for passage in result.passages:
            handle.write(json.dumps(passage, ensure_ascii=False, sort_keys=True) + "\n")
    by_kind = collections.Counter(note["kind"] for note in result.notes)
    write_json(os.path.join(folder, "report.json"), {
        "book": result.book,
        "profile": result.kind,
        "input": inputs,
        "counts": result.counts,
        "checks": result.checks,
        "notes_by_kind": dict(sorted(by_kind.items())),
        "notes": result.notes,
        "surahs": {str(k): v for k, v in sorted(result.surahs.items())},
        "passages_sha256": file_sha256(passages_path),
    })
    clear = [p for p in result.passages if usable(p)]
    step = max(1, len(clear) // 60)
    chosen = clear[::step][:60]
    write_page(
        os.path.join(folder, "sample.html"),
        "Book %d: %d of %d linked passages, every %d-th, the same on every run."
        % (result.book, len(chosen), len(clear), step),
        chosen,
    )
    flagged = [p for p in result.passages if "review" in p]
    write_page(
        os.path.join(folder, "review.html"),
        "Book %d: all %d passages whose link the linker could not trust." % (result.book, len(flagged)),
        flagged,
    )


def file_sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def write_page(path, lead, passages, labels=None):
    """A page for the reviewer. The paragraphs are the site's own markup."""
    rows = []
    for passage in passages:
        checks = list(passage.get("review", []))
        if labels:
            checks.append(labels[passage["n"]])
        refs = ", ".join(str(a) if a == b else "%d-%d" % (a, b) for a, b in passage["refs"])
        first = passage["paragraphs"][0]
        body = "\n".join(
            '<div class="%s">%s</div>' % ("c" if entry.get("carried") else "p", entry["html"])
            for entry in passage["paragraphs"]
        )
        rows.append(
            "<section><h2>#%d &middot; surah %s &middot; ayah %s &middot; %s%s &middot; part %s,"
            " printed page %s (site page %s)</h2>%s"
            '<p class="tick">&#9744; correct&nbsp;&nbsp; &#9744; wrong: &hellip;&hellip;</p></section>'
            % (
                passage["n"], passage["surah"], refs, passage["basis"],
                " &middot; CHECK: " + ", ".join(checks) if checks else "",
                first["part"], first["printed_page"], first["site_page"], body,
            )
        )
    page = (
        '<!doctype html>\n<html lang="ar" dir="rtl"><head><meta charset="utf-8">'
        "<title>Linking review</title><style>"
        "body{font-family:serif;max-width:900px;margin:24px auto;line-height:2}"
        "h2{font:600 14px sans-serif;direction:ltr;text-align:left;background:#eee;padding:6px}"
        "section{border-bottom:1px solid #999;margin-bottom:18px}"
        ".c{border-right:4px solid #c80;padding-right:8px}"
        ".tick,.lead{direction:ltr;text-align:left;font:14px sans-serif}"
        "</style></head><body>\n"
        '<p class="lead">%s The text is as extracted: the site font\'s honorific codes show as'
        " single symbols. A bar on the right marks a paragraph that follows a numbered one and"
        " has no number of its own.</p>\n%s\n</body></html>\n" % (lead, "\n".join(rows))
    )
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(page)


# ----------------------------------------------------------------------------
# A check on the links, never a way of making them: is the quotation a link rests
# on found in the ayat it is linked to, as the text of book 514 prints them? It
# reads the paragraph that opens a passage, not the ones carried after it.

TEXT_BOOK = 514
WEAK_LETTERS = set("اويىءأإآؤئ")
CONFIRMED = ["same", "same_but_for_spelling"]
NOT_COMPARED = ["too_short_to_compare", "no_quotation"]
NOT_CONFIRMED = ["in_a_neighbouring_ayah", "partly_found", "elsewhere_in_the_surah", "not_found"]
OUTCOMES = CONFIRMED + NOT_COMPARED + NOT_CONFIRMED


def letters(text):
    """The Arabic letters of a text, for comparing only. Never stored."""
    text = re.sub("[ٱأإآ]", "ا", text)
    return "".join(ch for ch in text if "ء" <= ch <= "ي" and ch != "ـ")


def strong_letters(text):
    """Letters without the ones that spelling conventions add, drop or swap."""
    return "".join("ت" if ch == "ة" else ch for ch in letters(text) if ch not in WEAK_LETTERS)


def quotation_fragments(inner):
    """The pieces of one quotation span that are long enough to compare.

    Words between "}" and "{" inside the span are the author's, and "..." marks
    words he left out.
    """
    pieces = re.findall(r"\{([^{}]*)\}", "{" + plain(inner) + "}")
    parts = [part for piece in pieces for part in re.split(r"\.\.\.|…", piece)]
    return [part for part in parts if len(strong_letters(part)) >= 4]


def printed_text(passages):
    """Ayah texts and opening lines as the text book prints them, in memory only."""
    ayat, openings, pending = {}, {}, {}
    for passage in passages:
        if passage["kind"] != "text":
            continue
        surah = passage["surah"]
        for entry in passage["paragraphs"]:
            joined = " ".join(plain(inner) for _, _, inner in quotations(entry["html"]))
            if entry.get("role") == "opening":
                openings[surah] = joined
                continue
            words = pending.get(surah, "")
            for part in re.split("(" + NUM + ")", joined):
                if re.fullmatch(NUM, part):
                    key = (surah, int(part))
                    ayat[key] = ayat.get(key, "") + words
                    words = ""
                else:
                    words += " " + part
            pending[surah] = words
    return ayat, openings


def compare_quotation(fragments, surah, refs, ayat, openings):
    """One of OUTCOMES, and the ayat where the quotation was found instead."""
    if not fragments:
        return "too_short_to_compare", []

    def text_of(pad):
        parts = []
        for first, end in refs:
            if first - pad <= 1:
                parts.append(openings.get(surah, ""))
            parts.extend(ayat.get((surah, n), "") for n in range(first - pad, end + pad + 1))
        return " ".join(parts)

    here = text_of(0)
    if all(letters(f) in letters(here) for f in fragments):
        return "same", []
    found = [strong_letters(f) in strong_letters(here) for f in fragments]
    if all(found):
        return "same_but_for_spelling", []
    if all(strong_letters(f) in strong_letters(text_of(1)) for f in fragments):
        return "in_a_neighbouring_ayah", []
    if any(found):
        return "partly_found", []
    first = strong_letters(fragments[0])
    elsewhere = sorted(
        n for (s, n), text in ayat.items() if s == surah and first in strong_letters(text)
    )
    return ("elsewhere_in_the_surah" if elsewhere else "not_found"), elsewhere


def quotations_to_compare(passage, kind):
    """(quotation, ayah ranges) for each quotation a passage's links rest on."""
    opening = passage["paragraphs"][0]["html"]
    pairs = quotations_with_refs(opening)
    if kind == "inner_numbers":
        return [(words, [[n, n]]) for inner, _ in pairs for words, n in inner_numbers(inner)]
    if kind in ("text_and_commentary", "footnote_references"):
        return [(pairs[0][0], passage["refs"])] if pairs else []
    if kind == "items":
        # Every quotation of the item up to its first reference; the reference
        # must follow one of them directly.
        first_ref = REF.search(opening)
        upto = [index for index, (_, raw) in enumerate(pairs) if raw is not None][:1]
        if not upto or pairs[upto[0]][1] != first_ref.group(1):
            return []
        return [(inner, passage["refs"]) for inner, _ in pairs[:upto[0] + 1]]
    numbered = [(inner, parse_bracket_number(plain(raw))) for inner, raw in pairs if raw is not None]
    return [(inner, [ref]) for inner, ref in numbered if ref]


def read_passages(out_dir, book):
    path = os.path.join(out_dir, "book_%d" % book, "passages.jsonl")
    if not os.path.isfile(path):
        raise LinkError("book %d is not linked yet: no %s" % (book, path))
    with open(path, encoding="utf-8") as handle:
        return [json.loads(line) for line in handle]


def compare_passage(passage, kind, ayat, openings):
    """The worst outcome among the quotations a passage's links rest on."""
    worst, found_at = "no_quotation", []
    for position, (inner, refs) in enumerate(quotations_to_compare(passage, kind)):
        outcome, where = compare_quotation(
            quotation_fragments(inner), passage["surah"], refs, ayat, openings
        )
        if position == 0 or OUTCOMES.index(outcome) > OUTCOMES.index(worst):
            worst, found_at = outcome, where
    return worst, found_at


def run_compare(book, out_dir):
    if book not in PROFILES:
        raise LinkError("book %d has no profile" % book)
    ayat, openings = printed_text(read_passages(out_dir, TEXT_BOOK))
    passages = read_passages(out_dir, book)
    counts = {outcome: 0 for outcome in OUTCOMES}
    counts.update(range_not_usable=0, flagged_by_the_linker_and_confirmed=0)
    listed, labels = [], {}
    for passage in passages:
        if passage["kind"] != "passage":
            continue
        if any(end < first for first, end in passage["refs"]):
            counts["range_not_usable"] += 1
            continue
        outcome, found_at = compare_passage(passage, PROFILES[book]["kind"], ayat, openings)
        counts[outcome] += 1
        counts["flagged_by_the_linker_and_confirmed"] += outcome in CONFIRMED and "review" in passage
        if outcome in NOT_CONFIRMED:
            listed.append({
                "n": passage["n"], "site_page": first_page(passage), "surah": passage["surah"],
                "refs": passage["refs"], "outcome": outcome, "found_at": found_at[:8],
            })
            where = " at ayah %s" % ", ".join(str(n) for n in found_at[:8]) if found_at else ""
            labels[passage["n"]] = outcome + where
    folder = os.path.join(out_dir, "book_%d" % book)
    write_json(os.path.join(folder, "compare.json"), {
        "book": book,
        "passages_sha256": file_sha256(os.path.join(folder, "passages.jsonl")),
        "text_from_book": TEXT_BOOK,
        "text_passages_sha256": file_sha256(
            os.path.join(out_dir, "book_%d" % TEXT_BOOK, "passages.jsonl")
        ),
        "counts": counts,
        "not_confirmed": listed,
    })
    write_page(
        os.path.join(folder, "compare.html"),
        "Book %d: the %d linked passages whose quotation was not found in the ayat they are"
        " linked to, as book %d prints them." % (book, len(listed), TEXT_BOOK),
        [p for p in passages if p["n"] in labels],
        labels,
    )
    return counts


def run_names(books, out_dir):
    """Surah names and ayah counts as the linked books print them."""
    names, ayat, sources = {}, {}, []
    for book in books:
        surahs = read_json(os.path.join(out_dir, "book_%d" % book, "report.json"))["surahs"]
        if len(surahs) != 114:
            raise LinkError("book %d does not have 114 surah headings" % book)
        sources.append("book %d (surah numbers %s)" % (book, surahs["1"]["number"]))
        for number, info in surahs.items():
            key = name_key(info["name_in_book"])
            if names.setdefault(key, int(number)) != int(number):
                raise LinkError(
                    "%r is surah %d in one book and %s in book %d"
                    % (info["name_in_book"], names[key], number, book)
                )
            count = info.get("last_ayah_number")
            if count and ayat.setdefault(number, count) != count:
                raise LinkError("surah %s has two ayah counts" % number)
    path = os.path.join(out_dir, "surahs.json")
    write_json(path, {"sources": sources, "names": names, "ayat": ayat})
    return path


def run_inspect(book, in_dir):
    pages, done = load_pages(os.path.join(in_dir, "book_%d" % book))
    headings, refs, starts, codes = [], {}, {}, {}
    paragraphs = quotes = numbered = in_headings = rules = loose = 0
    for page in pages:
        source = page["html"] or ""
        loose += bool(PARA.sub("", source).strip())
        for paragraph in PARA.findall(source):
            paragraphs += 1
            rules += bool(RULE.match(plain(paragraph)))
            is_heading = HEADING_CLASS in paragraph
            if is_heading:
                headings.append(heading_key(paragraph))
            for _, _, inner in quotations(paragraph):
                quotes += 1
                numbered += bool(re.search(NUM, inner))
                in_headings += is_heading
            for raw in REF.findall(paragraph):
                shape = re.sub(NUM, "N", re.sub(r"[^\[\]:\-٠-٩ ،]+", "W", plain(raw)))
                refs[shape] = refs.get(shape, 0) + 1
            red = RED_START.match(paragraph)
            opening = NUMBER_LIST.match(plain(paragraph))
            start = plain(red.group(1)) if red else (opening.group(0) if opening else "")
            if start and not is_heading:
                shape = re.sub(NUM, "N", start)
                starts[shape] = starts.get(shape, 0) + 1
            for code in CODE.findall(paragraph):
                codes[code] = codes.get(code, 0) + 1

    def ranked(table, limit=None):
        return sorted(table.items(), key=lambda item: -item[1])[:limit]

    say("book %d: %d pages, extraction complete: %s" % (book, len(pages), done))
    say("paragraphs %d, headings %d, pages with text outside paragraphs %d, rules of dashes %d"
        % (paragraphs, len(headings), loose, rules))
    say("quotations %d (%d of them in headings), with a number inside %d" % (quotes, in_headings, numbered))
    say("references after a quotation: %s" % ranked(refs, 12))
    say("paragraphs opening with a red span or a number: %s" % ranked(starts, 12))
    say("single-character dark-red spans, headings included: %s"
        % ["U+%04X x%d" % (ord(c), n) for c, n in ranked(codes)])
    say("first headings: %s" % headings[:8])
    say("last headings: %s" % headings[-4:])


def say(text):
    sys.stdout.write(text + "\n")
    sys.stdout.flush()


def discard_further_output():
    os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())


def main(argv):
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    parser = argparse.ArgumentParser(
        prog="ziydia_link.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("command", choices=["link", "names", "compare", "inspect"])
    parser.add_argument("books", type=int, nargs="+", metavar="book")
    parser.add_argument("--in", dest="in_dir", default="ziydia_out")
    parser.add_argument("--out", dest="out_dir", default="ziydia_links")
    parser.add_argument("--surahs", dest="table")
    args = parser.parse_args(argv[1:])
    if args.command != "names" and len(args.books) != 1:
        parser.error("%s takes one book" % args.command)
    book = args.books[0]
    try:
        if args.command == "inspect":
            run_inspect(book, args.in_dir)
        elif args.command == "names":
            say("wrote %s" % run_names(args.books, args.out_dir))
        elif args.command == "compare":
            say("book %d: %s" % (book, json.dumps(run_compare(book, args.out_dir))))
        else:
            result = run_link(book, args.in_dir, args.out_dir, args.table)
            say("book %d: %s" % (book, json.dumps(result.counts, ensure_ascii=False)))
            say("checks: %s" % json.dumps(result.checks, ensure_ascii=False))
            kinds = collections.Counter(note["kind"] for note in result.notes)
            say("notes: %s" % (dict(sorted(kinds.items())) or "none"))
    except BrokenPipeError:
        # Whoever was reading the output stopped reading; the run itself is sound.
        discard_further_output()
        return 0
    except (LinkError, OSError) as error:
        say("STOPPED: %s" % error)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
