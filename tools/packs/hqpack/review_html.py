"""The HTML of the review page (review_page.py, D-178).

The frame, style and script are `review_page.html`; the Arabic labels are
`review_page.ar.json`, so that this file stays ASCII. A source text reaches the
page only through `parts`: three slices at token offsets, joined and compared
with the text before they are written, and escaped for HTML (`&`, `<`, `>`),
which the browser undoes. The data the script reads holds addresses, numbers
and code points only.
"""

from __future__ import annotations

import hashlib
import html
import json
import unicodedata
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path
from string import Template

from .errors import PackError, code_point
from .tokens import token_spans

EXAMPLES_B = 3
EXAMPLES_C = 5
DECISIONS_FORMAT = "holyquran-kfgqpc-review-decisions"
DECISIONS_VERSION = 1
CHOICES = ("agrees", "disagrees", "unchecked")
STORAGE_PREFIX = "holyquran-kfgqpc-review:"

_HERE = Path(__file__).resolve().parent
_ARABIC_DIGITS = {ord(d): 0x0660 + i for i, d in enumerate("0123456789")}


@dataclass(frozen=True)
class Page:
    report: dict
    sections: object
    surah_opening_quarters: tuple
    surah_names: dict
    inputs: dict
    fonts: tuple


def render(page):
    """The whole page as a string."""
    strings = _strings()
    items = []
    writer = _Writer(page, strings, items)
    body = "\n".join(
        (writer.section_a(), writer.section_b(), writer.section_c(), writer.section_d())
    )
    report = page.report
    data = OrderedDict(
        [
            ("decisions", OrderedDict([("format", DECISIONS_FORMAT), ("version", DECISIONS_VERSION)])),
            ("storage_key", storage_key(page.inputs)),
            ("inputs", page.inputs),
            ("items", items),
        ]
    )
    problems = ""
    if report["presentation_problems"] or report["table_problems"]:
        problems = '<p class="warning">%s</p>\n' % _escape(
            strings["problems"]
            % (_number(len(report["presentation_problems"])), _number(len(report["table_problems"])))
        )
    counts = strings["counts"] % tuple(
        _number(len(report[key]))
        for key in ("differences", "patterns", "page_differences", "juz_differences", "quarter_differences")
    )
    return Template((_HERE / "review_page.html").read_text(encoding="utf-8")).substitute(
        tanzil_font=page.fonts[0],
        kfgqpc_font=page.fonts[1],
        problems=problems,
        counts=_escape(counts),
        inputs="<br>\n".join("%s: %s" % (key, _escape(str(value))) for key, value in page.inputs.items()),
        sections=body,
        data=_script_json(data),
    )


def parts(text, start, end):
    """`text` cut at `start` and `end`: before, marked, after."""
    return text[:start], text[start:end], text[end:]


def marked_span(text, start, end):
    """The (start, end) to mark for the difference at [start, end) of `text`: from the
    word token that holds `start` or is the last before it, to the end of the last
    token the range overlaps or abuts. Tokens are those of tokens.token_spans, so
    the span starts and ends at a token boundary and never cuts a word."""
    low, high = start, end
    for token_start, token_end, is_word in token_spans(text):
        if is_word and token_start <= start:
            low = token_start
        if token_start <= end and start <= token_end:
            low = min(low, token_start)
            high = max(high, token_end)
    return low, high


def check_parts(pieces, text, where):
    if "".join(pieces) != text:
        raise PackError("the marked %s does not reconstitute its source text; the page is not written" % where)


def examples(places, count):
    """The first place at each of the first `count` addresses among `places`."""
    seen = []
    result = []
    for place in places:
        if place.address not in seen:
            seen.append(place.address)
            result.append(place)
            if len(result) == count:
                break
    return result


def storage_key(inputs):
    joined = "\n".join(["%s=%s" % (DECISIONS_FORMAT, DECISIONS_VERSION)] + ["%s=%s" % item for item in inputs.items()])
    return STORAGE_PREFIX + hashlib.sha256(joined.encode("ascii")).hexdigest()[:16]


def place_id(place, repeat):
    """Built from what the place is, not from its position, so that a saved choice never
    moves to another place when the page is rebuilt; `repeat` counts the earlier places
    of the ayah with the same word and sequences."""
    base = "A:hafs:%d:%d:%d:%s>%s" % (
        place.address + (place.word, _sequence_id(place.kfgqpc_sequence), _sequence_id(place.tanzil_sequence))
    )
    return base if repeat == 1 else "%s:%d" % (base, repeat)


def card_id(section, card):
    return "%s:%s>%s" % (section, _sequence_id(card.kfgqpc), _sequence_id(card.tanzil))


class _Writer:
    def __init__(self, page, strings, items):
        self.page = page
        self.s = strings
        self.items = items

    def section_a(self):
        repeats = {}
        blocks = []
        for place in self.page.sections.a:
            key = (place.address, place.word, place.kfgqpc_sequence, place.tanzil_sequence)
            repeats[key] = repeats.get(key, 0) + 1
            item_id = place_id(place, repeats[key])
            self.items.append(
                OrderedDict(
                    [
                        ("id", item_id),
                        ("section", "A"),
                        ("address", _address(place.address)),
                        ("word", place.word),
                        ("in_mark", place.in_mark),
                        ("kfgqpc", _code_points(place.kfgqpc_sequence)),
                        ("tanzil", _code_points(place.tanzil_sequence)),
                    ]
                )
            )
            blocks.append(self.place(place, self.choice(item_id)))
        return self.section("A", "section_a", "question_a", blocks)

    def section_b(self):
        return self.cards("B", "section_b", "question_b", self.page.sections.b, EXAMPLES_B)

    def section_c(self):
        return self.cards("C", "section_c", "question_c", self.page.sections.c, EXAMPLES_C)

    def cards(self, section, title, question, cards, count):
        blocks = []
        for card in cards:
            item_id = card_id(section, card)
            shown = examples(card.places, count)
            self.items.append(
                OrderedDict(
                    [
                        ("id", item_id),
                        ("section", section),
                        ("kfgqpc", _code_points(card.kfgqpc)),
                        ("tanzil", _code_points(card.tanzil)),
                        ("count", len(card.places)),
                        ("examples", [_address(p.address) for p in shown]),
                    ]
                )
            )
            blocks.append(
                '<article class="card" id="%s">\n<h3>%s: %s</h3>\n%s\n<p class="label">%s</p>\n%s\n%s\n</article>'
                % (
                    _attribute(item_id),
                    _escape(self.s["count"]),
                    _number(len(card.places)),
                    self.code_points(card.kfgqpc, card.tanzil),
                    _escape(self.s["examples"]),
                    "\n".join(self.place(p, "") for p in shown),
                    self.choice(item_id),
                )
            )
        return self.section(section, title, question, blocks)

    def section_d(self):
        report = self.page.report
        tables = [
            self.division_table("pages", "page", report["page_differences"], lambda d: (d["kfgqpc"], d["tanzil_metadata"])),
            self.division_table("juzs", "juz", report["juz_differences"], lambda d: (d["kfgqpc"], d["tanzil_metadata"])),
            self.division_table(
                "quarters",
                "quarter",
                report["quarter_differences"],
                lambda d: (d["kfgqpc_quarter_start"], d["tanzil_quarter_start"]),
            ),
        ]
        openings = [
            {"address": _address(address), "kfgqpc": False, "tanzil_metadata": True}
            for address in self.page.surah_opening_quarters
        ]
        tables.append(
            '<p class="question">%s</p>\n%s'
            % (
                _escape(self.s["openings_question"]),
                self.division_table(
                    "openings", "surah_opening_quarter", openings, lambda d: (d["kfgqpc"], d["tanzil_metadata"])
                ),
            )
        )
        return self.section("D", "section_d", "question_d", tables, always=True)

    def division_table(self, title, kind, rows, values):
        body = []
        for row in rows:
            kfgqpc_value, tanzil_value = values(row)
            item_id = "D:%s:%s" % (kind, row["address"])
            self.items.append(
                OrderedDict(
                    [
                        ("id", item_id),
                        ("section", "D"),
                        ("kind", kind),
                        ("address", row["address"]),
                        ("kfgqpc", kfgqpc_value),
                        ("tanzil_metadata", tanzil_value),
                    ]
                )
            )
            body.append(
                '<tr id="%s"><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'
                % (
                    _attribute(item_id),
                    self.address_html(_parse_address(row["address"])),
                    self.value(kfgqpc_value),
                    self.value(tanzil_value),
                    self.choice(item_id),
                )
            )
        heading = '<h3>%s (%s)</h3>' % (_escape(self.s[title]), _number(len(rows)))
        if not body:
            return '%s\n<p>%s</p>' % (heading, _escape(self.s["empty"]))
        return '%s\n<table>\n<tr><th>%s</th><th>%s</th><th>%s</th><th>%s</th></tr>\n%s\n</table>' % (
            heading,
            _escape(self.s["address"]),
            _escape(self.s["kfgqpc_value"]),
            _escape(self.s["tanzil_value"]),
            _escape(self.s["decision"]),
            "\n".join(body),
        )

    def section(self, section, title, question, blocks, always=False):
        content = "\n".join(blocks) if blocks or always else "<p>%s</p>" % _escape(self.s["empty"])
        return '<section id="section-%s">\n<h2>%s</h2>\n<p class="question">%s</p>\n%s\n</section>' % (
            section,
            _escape(self.s[title]),
            _escape(self.s[question]),
            content,
        )

    def place(self, place, choice):
        where = _address(place.address)
        return '<div class="place">\n<h3>%s &#x2014; %s</h3>\n%s\n%s\n%s\n%s\n</div>' % (
            self.address_html(place.address),
            _escape(self.word(place)),
            self.source_text("tanzil", place.tanzil_text, place.tanzil, where),
            self.source_text("kfgqpc", place.kfgqpc_text, place.kfgqpc, where),
            self.code_points(place.kfgqpc_sequence, place.tanzil_sequence),
            choice,
        )

    def source_text(self, source, text, difference, where):
        start, end = marked_span(text, *difference)
        pieces = parts(text, start, end)
        check_parts(pieces, text, "%s text of %s" % (source, where))
        return (
            '<div class="label">%s</div>\n<p class="text %s" lang="ar" dir="rtl" data-source="%s" data-address="%s">'
            "%s<mark>%s</mark>%s</p>"
            % ((_escape(self.s[source]), source, source, where) + tuple(_escape(p) for p in pieces))
        )

    def code_points(self, kfgqpc_sequence, tanzil_sequence):
        return '<div class="code-points">\n%s\n%s\n</div>' % (
            self.code_point_list("tanzil_code_points", tanzil_sequence),
            self.code_point_list("kfgqpc_code_points", kfgqpc_sequence),
        )

    def code_point_list(self, label, sequence):
        if not sequence:
            entries = '<li dir="rtl">%s</li>' % _escape(self.s["nothing"])
        else:
            entries = "\n".join("<li>%s %s</li>" % (code_point(c), _unicode_name(c)) for c in sequence)
        return '<div><div class="label">%s</div>\n<ul>\n%s\n</ul></div>' % (_escape(self.s[label]), entries)

    def choice(self, item_id):
        name = _attribute(item_id)
        options = "\n".join(
            '<label><input type="radio" name="%s" value="%s"%s> %s</label>'
            % (name, value, " checked" if value == "unchecked" else "", _escape(self.s[value]))
            for value in CHOICES
        )
        return (
            '<fieldset class="choice" data-id="%s">\n<legend>%s</legend>\n%s\n'
            '<textarea aria-label="%s" placeholder="%s"></textarea>\n</fieldset>'
            % (name, _escape(self.s["decision"]), options, _attribute(self.s["note"]), _attribute(self.s["note"]))
        )

    def address_html(self, address):
        surah, ayah = address
        return '%s %s (%s)%s %s %s <span class="address">%s</span>' % (
            _escape(self.s["surah"]),
            _escape(self.page.surah_names[surah]),
            _number(surah),
            "\u060c",
            _escape(self.s["ayah"]),
            _number(ayah),
            _address(address),
        )

    def word(self, place):
        if place.word == 0:
            return self.s["before_first_word"]
        label = self.s["mark_after_word"] if place.in_mark else self.s["word"]
        return "%s %s" % (label, _number(place.word))

    def value(self, value):
        if value is True:
            return _escape(self.s["quarter_start"])
        if value is False:
            return _escape(self.s["no_quarter_start"])
        return _number(value)


def _strings():
    return json.loads((_HERE / "review_page.ar.json").read_bytes().decode("utf-8"))


def _escape(value):
    return html.escape(value, quote=False)


def _attribute(value):
    return html.escape(value, quote=True)


def _number(value):
    return str(value).translate(_ARABIC_DIGITS)


def _address(address):
    return "hafs:%d:%d" % address


def _parse_address(label):
    _, surah, ayah = label.split(":")
    return int(surah), int(ayah)


def _code_points(sequence):
    return [code_point(c) for c in sequence]


def _sequence_id(sequence):
    return ".".join(code_point(c) for c in sequence)


def _unicode_name(c):
    return unicodedata.name(c, "(no name in Unicode %s)" % unicodedata.unidata_version)


def _script_json(value):
    """JSON in ASCII, with `<` escaped so that nothing in it can close the script element."""
    return json.dumps(value, ensure_ascii=True, separators=(",", ":")).replace("<", "\\u003c")
