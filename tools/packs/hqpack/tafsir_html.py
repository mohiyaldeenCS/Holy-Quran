"""One paragraph of a Zaydi-library page to passage text (D-185).

A closed tokenizer reads the paragraph's `html` (pages.jsonl, as the site
served it) into pieces, each an exact slice of the `html` and what the passage
text takes from it:

- the tags of `ALLOWED`, exactly as the site writes them (tools/packs/README.md,
  "The markup a paragraph may hold"), nested in balance, a `<div>` only
  where the books put it (`&nbsp`, the `<div>` holding one code span,
  `</p>`): none;
- a dark-red code span (`CODE_SPANS`) holding one table code: its approved
  phrase; holding U+FDFA, U+FDFB, U+FDFD, U+00B7 or a run of U+002E: itself;
- a footnote mark, `<sup style="color: #800000;">` holding `(` U+2063 N `)`
  with N in Arabic-Indic digits: its content, as printed (D-189);
- `&nbsp` at either edge of the paragraph: none;
- any other run of characters: itself.

A paragraph opens as a plain, a heading or a note paragraph
(`NOTE_OPEN`, the indented 0.8em paragraph below a page's footnote line).
Everything else is refused: another tag, attribute or style; a mark in a note
paragraph, or a `<sup>` that is not a mark; `<hr>`, which only the empty
separator paragraph holds (`SEPARATOR`, read by `tafsir_footnotes`);
another entity, `&nbsp;`, `&nbsp` inside the paragraph, or a stray `<`, `>` or
`&`; U+FFFD and U+FEFF; an unknown code; a table code outside its span or
touching a letter (format characters, category Cf, are passed over to find
the code's neighbours); a `<div>` anywhere else. The pieces' texts are joined, every run of
ASCII white space becomes one U+0020, and U+0020 is trimmed from the edges.
Nothing else changes: no entity is decoded and nothing is normalised.

Two proofs run on every paragraph: P1, the pieces rejoin the `html` exactly
and each piece's text is what the rule gives its slice; P2, an independent
path of regular expressions over the `html` gives the same text. (P3, the
paragraph is its page's, is `ziydia_inputs.check_on_page`; P4, the stored
text reads back equal, is the build's.) Messages name offsets, tag names and
code points only.
"""

from __future__ import annotations

import re
import unicodedata
from collections import Counter
from dataclasses import dataclass

from .errors import PackError, code_point
from .honorifics import DOT, KEPT_CODES

# The site's markup, each string exactly as pages.jsonl holds it, double
# spaces included (the markup of the eight books, tools/packs/README.md).
P_OPEN = '<p style="margin-top:1px;margin-bottom:1px">'
HEADING_OPEN = (
    '<p class="border-r-4 px-2"  style="border-radius: 0px 3px 3px 0px;font-family:Ziydia-Bold;color: #800000;">'
)
NOTE_OPEN = (
    '<p style="text-indent: -20px;padding-right: 20px;font-size: 0.8em;margin-top:1px;margin-bottom:1px;'
    'color:#464646;text-align: justify;">'
)
PARAGRAPH_OPENS = (P_OPEN, HEADING_OPEN, NOTE_OPEN)
P_CLOSE = "</p>"
SPANS = (
    '<span style="font-family:Ziydia-Bold">',  # emphasised lead-in words
    '<span style="color: #00AA00;font-family: Ziydia-Q;">',  # a Quran quotation
    '<span style="font-size: 0.8em;">',  # a bracketed ayah number
    '<span style="color: #be0000;">',  # the number opening an item
)
SPAN_CLOSE = "</span>"
CODE_SPANS = (
    '<span  style="color: #800000;">',  # an honorific code (dark red)
    '<span style="color: #800000;">',  # the same, as the site writes it around U+0023
)
DIV_OPEN = '<div style="text-align: center;">'
DIV_CLOSE = "</div>"
OPENS = PARAGRAPH_OPENS + SPANS + (DIV_OPEN,)
CLOSES = (P_CLOSE, SPAN_CLOSE, DIV_CLOSE)
ALLOWED = OPENS + CLOSES + CODE_SPANS
NBSP = "&nbsp"
MARK_OPEN = '<sup style="color: #800000;">'
MARK_CLOSE = "</sup>"
DIGITS = "[\\u0660-\\u0669]+"  # Arabic-Indic digits, as the books number their footnotes
MARK = re.compile("\\(\\u2063(" + DIGITS + ")\\)")
HR = (
    '<hr style="margin-top: 12px;margin-bottom: 12px;border: 0;height: 1px;'
    'background-image: -webkit-linear-gradient(left, transparent, rgba(0, 0, 0, 0.2), transparent);">'
)
SEPARATOR = NOTE_OPEN + HR + "</p>"  # the empty paragraph holding the footnote line

_ASCII_SPACE = " \t\n\r\f\v"
_WHITE = re.compile("[ \t\n\r\f\v]+")
_TAG_NAME = re.compile(r"</?([A-Za-z][A-Za-z0-9]*)")
_REFUSED = ("\ufffd", "\ufeff")


@dataclass(frozen=True)
class Piece:
    kind: str  # open, close, text, nbsp, code (a table code), kept (a kept code), mark (a footnote mark)
    source: str  # the exact slice of the html
    text: str  # what the passage text takes from it, before white space is collapsed


@dataclass(frozen=True)
class Paragraph:
    text: str  # empty when the paragraph holds nothing to show
    pieces: tuple
    replaced: Counter  # table code -> times replaced by its phrase
    note: bool  # a note paragraph, below a page's footnote line
    marks: tuple  # the N of each footnote mark, as printed, in order


def convert_paragraph(html: str, phrases: dict, where: str) -> Paragraph:
    """`phrases` maps each one-character table code to its approved phrase."""
    if not isinstance(html, str):
        raise PackError("%s: the html is not a string" % where)
    for c in _REFUSED:
        at = html.find(c)
        if at >= 0:
            raise PackError("%s holds %s at offset %d" % (where, code_point(c), at))
    pieces = tokenize(html, phrases, where)
    check_rejoins(html, pieces, phrases, where)
    _check_codes(pieces, phrases, where)
    if pieces[0].source == NOTE_OPEN and any(p.kind == "mark" for p in pieces):
        raise PackError("%s: a footnote mark stands in a note paragraph" % where)
    _check_divs(pieces, where)
    text = assemble(pieces, where)
    check_regex_agrees(html, phrases, text, where)
    return Paragraph(
        text=text,
        pieces=tuple(pieces),
        replaced=Counter(_code_inner(p.source) for p in pieces if p.kind == "code"),
        note=pieces[0].source == NOTE_OPEN,
        marks=tuple(MARK.fullmatch(p.text).group(1) for p in pieces if p.kind == "mark"),
    )


def tokenize(html: str, phrases: dict, where: str) -> list:
    pieces, open_tags, at = [], [], 0
    while at < len(html):
        if not open_tags and pieces:
            raise PackError("%s: something follows </p> at offset %d" % (where, at))
        c = html[at]
        if c == "<":
            at, piece = _tag(html, at, open_tags, phrases, where)
        elif not open_tags:
            raise PackError("%s: text before the paragraph's <p> at offset %d" % (where, at))
        elif c == "&":
            at, piece = _entity(html, at, where)
        elif c == ">":
            raise PackError("%s: a stray > at offset %d" % (where, at))
        else:
            at, piece = _text_run(html, at)
        pieces.append(piece)
    if not pieces:
        raise PackError("%s: the html is empty" % where)
    if open_tags:
        raise PackError("%s: %d tags are not closed" % (where, len(open_tags)))
    return pieces


def assemble(pieces, where: str) -> str:
    shown = [k for k, p in enumerate(pieces) if p.text.strip(_ASCII_SPACE)]
    first, last = (shown[0], shown[-1]) if shown else (len(pieces), -1)
    for k, piece in enumerate(pieces):
        if piece.kind == "nbsp" and first < k < last:
            raise PackError("%s: &nbsp inside the paragraph, not at an edge (piece %d)" % (where, k))
    return _WHITE.sub(" ", "".join(p.text for p in pieces)).strip(" ")


def check_rejoins(html: str, pieces, phrases: dict, where: str) -> None:
    """P1: the pieces are the html cut up, and each one's text follows from its slice."""
    if "".join(p.source for p in pieces) != html:
        raise PackError("%s: the pieces do not rejoin the html (P1)" % where)
    for k, piece in enumerate(pieces):
        if not _slice_fits(piece) or piece.text != _rule(piece, phrases):
            raise PackError("%s: piece %d is not converted by the rule (P1)" % (where, k))


def _alternatives(tags):
    return "(?:%s)" % "|".join(re.escape(tag) for tag in tags)


_P_BODY = re.compile(_alternatives(PARAGRAPH_OPENS) + "(.*)" + re.escape(P_CLOSE), re.S)
_CODE_RE = re.compile(_alternatives(CODE_SPANS) + "([^<]*)" + re.escape(SPAN_CLOSE))
_MARK_RE = re.compile(re.escape(MARK_OPEN) + "([^<]*)" + re.escape(MARK_CLOSE))
_TAGS_RE = re.compile(_alternatives(SPANS + (SPAN_CLOSE, DIV_OPEN, DIV_CLOSE)))
_EDGES_RE = re.compile(r"\A(?:[ \t\n\r\f\v]|&nbsp)+|(?:[ \t\n\r\f\v]|&nbsp)+\Z")


def regex_text(html: str, phrases: dict):
    """The text by a second path that shares nothing with the tokenizer."""
    body = _P_BODY.fullmatch(html)
    if body is None:
        return None
    text = _CODE_RE.sub(lambda m: phrases.get(m.group(1), m.group(1)), body.group(1))
    text = _MARK_RE.sub(lambda m: m.group(1), text)
    text = _EDGES_RE.sub("", _TAGS_RE.sub("", text))
    return _WHITE.sub(" ", text).strip(" ")


def check_regex_agrees(html: str, phrases: dict, text: str, where: str) -> None:
    """P2."""
    if regex_text(html, phrases) != text:
        raise PackError("%s: the two conversions disagree (P2)" % where)


def _tag(html, at, open_tags, phrases, where):
    for opening in PARAGRAPH_OPENS:
        if not open_tags and html.startswith(opening, at):
            open_tags.append("p")
            return at + len(opening), Piece("open", opening, "")
    if open_tags and html.startswith(P_CLOSE, at):
        if open_tags != ["p"]:
            raise PackError("%s: </p> at offset %d closes a <%s>" % (where, at, open_tags[-1]))
        open_tags.pop()
        return at + len(P_CLOSE), Piece("close", P_CLOSE, "")
    for closing, name in ((SPAN_CLOSE, "span"), (DIV_CLOSE, "div")):
        if open_tags and html.startswith(closing, at):
            if open_tags[-1] != name:
                raise PackError("%s: </%s> at offset %d has no <%s>" % (where, name, at, name))
            open_tags.pop()
            return at + len(closing), Piece("close", closing, "")
    if open_tags and html.startswith(DIV_OPEN, at):
        if open_tags != ["p"]:
            raise PackError("%s: the <div> at offset %d is not directly inside the paragraph" % (where, at))
        open_tags.append("div")
        return at + len(DIV_OPEN), Piece("open", DIV_OPEN, "")
    for span in CODE_SPANS:
        if open_tags and html.startswith(span, at):
            return _code_span(html, at, span, phrases, where)
    if open_tags and html.startswith(MARK_OPEN, at):
        return _mark(html, at, where)
    for span in SPANS:
        if open_tags and html.startswith(span, at):
            open_tags.append("span")
            return at + len(span), Piece("open", span, "")
    name = _TAG_NAME.match(html, at)
    if name is None:
        raise PackError("%s: a stray < at offset %d" % (where, at))
    if name.group(1).lower() == "hr":
        raise PackError("%s: <hr> at offset %d; the footnote line stands only in its empty paragraph" % (where, at))
    raise PackError("%s: unknown markup <%s> at offset %d" % (where, name.group(1).lower(), at))


def _code_span(html, at, span, phrases, where):
    start = at + len(span)
    end = html.find(SPAN_CLOSE, start)
    if end < 0:
        raise PackError("%s: the code span at offset %d is not closed" % (where, at))
    inner = html[start:end]
    if inner in phrases:
        kind = "code"
    elif inner in KEPT_CODES or (inner and inner.strip(DOT) == ""):
        kind = "kept"
    elif len(inner) == 1:
        raise PackError("%s: the code %s at offset %d is not in the honorific table" % (where, code_point(inner), at))
    else:
        raise PackError("%s: the code span at offset %d holds %d characters, not a code" % (where, at, len(inner)))
    stop = end + len(SPAN_CLOSE)
    return stop, Piece(kind, html[at:stop], phrases.get(inner, inner))


def _mark(html, at, where):
    start = at + len(MARK_OPEN)
    end = html.find(MARK_CLOSE, start)
    if end < 0 or MARK.fullmatch(html[start:end]) is None:
        raise PackError("%s: the <sup> at offset %d is not a footnote mark (U+2063 N)" % (where, at))
    stop = end + len(MARK_CLOSE)
    return stop, Piece("mark", html[at:stop], html[start:end])


def _entity(html, at, where):
    if html.startswith(NBSP + ";", at):
        raise PackError("%s: &nbsp; at offset %d is not the site's &nbsp" % (where, at))
    if html.startswith(NBSP, at):
        return at + len(NBSP), Piece("nbsp", NBSP, "")
    raise PackError("%s: a stray & or an entity other than &nbsp at offset %d" % (where, at))


def _text_run(html, at):
    end = at
    while end < len(html) and html[end] not in "<&>":
        end += 1
    return end, Piece("text", html[at:end], html[at:end])


def _code_inner(source):
    for span in CODE_SPANS:
        if source.startswith(span) and source.endswith(SPAN_CLOSE) and len(source) >= len(span) + len(SPAN_CLOSE):
            return source[len(span) : -len(SPAN_CLOSE)]
    return None


def _slice_fits(piece):
    """P1: each piece's slice is one its kind may have."""
    if piece.kind == "open":
        return piece.source in OPENS
    if piece.kind == "close":
        return piece.source in CLOSES
    if piece.kind == "nbsp":
        return piece.source == NBSP
    if piece.kind in ("code", "kept"):
        inner = _code_inner(piece.source)
        return inner is not None and "<" not in inner
    if piece.kind == "text":
        return piece.source != "" and not any(c in piece.source for c in "<&>")
    if piece.kind == "mark":
        inner = piece.source[len(MARK_OPEN) : -len(MARK_CLOSE)]
        return (
            piece.source.startswith(MARK_OPEN) and piece.source.endswith(MARK_CLOSE) and MARK.fullmatch(inner) is not None
        )
    return False


def _rule(piece, phrases):
    if piece.kind == "text":
        return piece.source
    if piece.kind == "mark":
        return piece.source[len(MARK_OPEN) : -len(MARK_CLOSE)]
    if piece.kind in ("code", "kept"):
        inner = _code_inner(piece.source)
        return phrases.get(inner, inner)
    return ""


def _check_codes(pieces, phrases, where):
    texts = [p.text for p in pieces]
    for k, piece in enumerate(pieces):
        if piece.kind == "text":
            for c in piece.source:
                if c in phrases:
                    raise PackError("%s: the code %s stands outside its span (piece %d)" % (where, code_point(c), k))
        elif piece.kind == "code":
            before = _neighbour(reversed("".join(texts[:k])))
            after = _neighbour("".join(texts[k + 1 :]))
            for c in before + after:
                if unicodedata.category(c)[0] in "LM":
                    raise PackError(
                        "%s: the code %s touches a letter (piece %d)" % (where, code_point(_code_inner(piece.source)), k)
                    )


def _neighbour(characters) -> str:
    """The first character that is not a format character (Cf), or nothing."""
    for c in characters:
        if unicodedata.category(c) != "Cf":
            return c
    return ""


def _check_divs(pieces, where):
    """A <div> only where the eight books put it: in a plain paragraph, after
    `&nbsp`, holding one code span, and followed by `</p>`. Anywhere else its
    words could run into the words around it."""
    for k, piece in enumerate(pieces):
        if piece.kind == "open" and piece.source == DIV_OPEN and not _div_in_place(pieces, k):
            raise PackError(
                "%s: the <div> (piece %d) is not &nbsp, then a <div> holding one code span, then </p>" % (where, k)
            )


def _div_in_place(pieces, k):
    if pieces[0].source != P_OPEN or k + 4 != len(pieces):
        return False
    before, inner, close, end = pieces[k - 1], pieces[k + 1], pieces[k + 2], pieces[k + 3]
    return before.kind == "nbsp" and inner.kind in ("code", "kept") and close.source == DIV_CLOSE and end.source == P_CLOSE
