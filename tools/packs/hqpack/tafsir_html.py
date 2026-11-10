"""One paragraph of a Zaydi-library page to passage text (D-185).

A closed tokenizer reads the paragraph's `html` (pages.jsonl, as the site
served it) into pieces, each an exact slice of the `html` and what the passage
text takes from it:

- the tags of `ALLOWED`, exactly as written there, nested in balance: none;
- a dark-red code span (`CODE_SPAN`) holding one table code: its approved
  phrase; holding U+FDFA, U+FDFB, U+FDFD, U+00B7 or a run of U+002E: itself;
- `&nbsp` at either edge of the paragraph: none;
- any other run of characters: itself.

Everything else is refused: another tag, attribute or style; `<sup>` and
`<hr>` until footnotes are built (D-189, task C); another entity, `&nbsp;`,
`&nbsp` inside the paragraph, or a stray `<`, `>` or `&`; U+FFFD and U+FEFF; an
unknown code; a table code outside its span or touching a letter. The pieces'
texts are joined, every run of ASCII white space becomes one U+0020, and
U+0020 is trimmed from the edges. Nothing else changes: no entity is decoded
and nothing is normalised.

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

# The site's paragraph and its spans (docs/content/ZIYDIA_LIBRARY.md,
# "Extracted data format", and the constants of tools/ziydia/ziydia_link.py).
P_OPEN = '<p style="margin-top:1px;margin-bottom:1px">'
P_CLOSE = "</p>"
SPANS = (
    '<span style="font-family:Ziydia-Bold">',  # emphasised lead-in words
    '<span style="color: #00AA00;font-family: Ziydia-Q;">',  # a Quran quotation
    '<span style="font-size: 0.8em;">',  # a bracketed ayah number
    '<span style="color: #be0000;">',  # the number opening an item
)
SPAN_CLOSE = "</span>"
CODE_SPAN = '<span style="color: #800000;">'  # an honorific code (dark red)
ALLOWED = (P_OPEN, P_CLOSE) + SPANS + (CODE_SPAN, SPAN_CLOSE)
NBSP = "&nbsp"
FOOTNOTE_TAGS = ("sup", "hr")

_ASCII_SPACE = " \t\n\r\f\v"
_WHITE = re.compile("[ \t\n\r\f\v]+")
_TAG_NAME = re.compile(r"</?([A-Za-z][A-Za-z0-9]*)")
_REFUSED = ("\ufffd", "\ufeff")


@dataclass(frozen=True)
class Piece:
    kind: str  # open, close, text, nbsp, code (a table code), kept (a kept code)
    source: str  # the exact slice of the html
    text: str  # what the passage text takes from it, before white space is collapsed


@dataclass(frozen=True)
class Paragraph:
    text: str  # empty when the paragraph holds nothing to show
    pieces: tuple
    replaced: Counter  # table code -> times replaced by its phrase


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
    text = assemble(pieces, where)
    check_regex_agrees(html, phrases, text, where)
    return Paragraph(
        text=text,
        pieces=tuple(pieces),
        replaced=Counter(p.source[len(CODE_SPAN)] for p in pieces if p.kind == "code"),
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
        if piece.text != _rule(piece, phrases):
            raise PackError("%s: piece %d is not converted by the rule (P1)" % (where, k))


_P_BODY = re.compile(re.escape(P_OPEN) + "(.*)" + re.escape(P_CLOSE), re.S)
_CODE_RE = re.compile(re.escape(CODE_SPAN) + "([^<]*)" + re.escape(SPAN_CLOSE))
_TAGS_RE = re.compile("|".join(re.escape(tag) for tag in SPANS + (SPAN_CLOSE,)))
_EDGES_RE = re.compile(r"\A(?:[ \t\n\r\f\v]|&nbsp)+|(?:[ \t\n\r\f\v]|&nbsp)+\Z")


def regex_text(html: str, phrases: dict):
    """The text by a second path that shares nothing with the tokenizer."""
    body = _P_BODY.fullmatch(html)
    if body is None:
        return None
    text = _CODE_RE.sub(lambda m: phrases.get(m.group(1), m.group(1)), body.group(1))
    text = _EDGES_RE.sub("", _TAGS_RE.sub("", text))
    return _WHITE.sub(" ", text).strip(" ")


def check_regex_agrees(html: str, phrases: dict, text: str, where: str) -> None:
    """P2."""
    if regex_text(html, phrases) != text:
        raise PackError("%s: the two conversions disagree (P2)" % where)


def _tag(html, at, open_tags, phrases, where):
    if html.startswith(P_OPEN, at) and not open_tags:
        open_tags.append("p")
        return at + len(P_OPEN), Piece("open", P_OPEN, "")
    if open_tags and html.startswith(P_CLOSE, at):
        if open_tags != ["p"]:
            raise PackError("%s: </p> at offset %d closes a <span>" % (where, at))
        open_tags.pop()
        return at + len(P_CLOSE), Piece("close", P_CLOSE, "")
    if open_tags and html.startswith(SPAN_CLOSE, at):
        if open_tags[-1] != "span":
            raise PackError("%s: </span> at offset %d has no <span>" % (where, at))
        open_tags.pop()
        return at + len(SPAN_CLOSE), Piece("close", SPAN_CLOSE, "")
    if open_tags and html.startswith(CODE_SPAN, at):
        return _code_span(html, at, phrases, where)
    for span in SPANS:
        if open_tags and html.startswith(span, at):
            open_tags.append("span")
            return at + len(span), Piece("open", span, "")
    name = _TAG_NAME.match(html, at)
    if name is None:
        raise PackError("%s: a stray < at offset %d" % (where, at))
    if name.group(1).lower() in FOOTNOTE_TAGS:
        raise PackError(
            "%s: <%s> at offset %d belongs to a footnote, refused until footnotes are built (D-189, task C)"
            % (where, name.group(1).lower(), at)
        )
    raise PackError("%s: unknown markup <%s> at offset %d" % (where, name.group(1).lower(), at))


def _code_span(html, at, phrases, where):
    start = at + len(CODE_SPAN)
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


def _rule(piece, phrases):
    if piece.kind == "text":
        return piece.source
    if piece.kind in ("code", "kept"):
        inner = piece.source[len(CODE_SPAN) : -len(SPAN_CLOSE)]
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
            before = "".join(texts[:k])[-1:]
            after = "".join(texts[k + 1 :])[:1]
            for c in before + after:
                if unicodedata.category(c)[0] in "LM":
                    raise PackError(
                        "%s: the code %s touches a letter (piece %d)" % (where, code_point(piece.source[len(CODE_SPAN)]), k)
                    )
