"""`kfgqpc-measure`: the counts the plan for D-195 (the KFGQPC Hafs text as the base text) rests on.

Reads the KFGQPC file through `kfgqpc`, the table of known differences, the
KFGQPC font's cmap through `font`, and optionally Tanzil's text and metadata.
The report holds counts, addresses and code points written U+XXXX, never a
character of either text; nothing is changed, normalised or packed.

Tokens are the runs between U+0020; an empty run (a leading, trailing or
doubled space) is counted, not kept. The Uthmani tokens of an ayah are those of
`aya_text` without its ayah-end tail, which is the table's ayah_end rule (the
separator, U+00A0 or the one an address-listed rule names, then the ayah's own
number glyph); an ayah without that tail is counted and tokenised whole.
"""

from __future__ import annotations

import json
from collections import Counter, OrderedDict
from pathlib import Path

from . import digest, kfgqpc
from .errors import PackError, code_point
from .font import read_font
from .known_differences import read_table
from .tanzil_metadata import read_tanzil_metadata
from .tanzil_text import read_tanzil_text
from .tokens import is_letter

FORMAT = "holyquran-kfgqpc-measure"
PAUSE_MARKS = range(0x06D6, 0x06DC)
NO_BREAK_SPACE = "\u00a0"
SAJDA_SIGN = "\u06e9"
SPACE = " "
FIRST_ADDRESSES = 10
TOKEN_MAP_NOT_MEASURED = (
    "not measured: compare.py aligns code points (difflib over characters) and exposes no token-to-token map"
)


def run_measure(kfgqpc_path, font_path, table_path, profile, text_path=None, metadata_path=None):
    """Reads every input and returns the report with each input's SHA-256; the Tanzil text and metadata go together."""
    if (text_path is None) != (metadata_path is None):
        raise PackError("the Tanzil text and metadata go together")
    ayat, kfgqpc_sha256 = kfgqpc.read_kfgqpc_file(kfgqpc_path, profile.ayat)
    font_bytes = Path(font_path).read_bytes()
    font_info = read_font(font_bytes)
    table_bytes = Path(table_path).read_bytes()
    inputs = OrderedDict(
        [
            ("kfgqpc", OrderedDict([("file", kfgqpc.FILE_NAME), ("version", kfgqpc.VERSION), ("sha256", kfgqpc_sha256)])),
            ("font", OrderedDict([("family", _ascii(font_info.family)), ("sha256", font_info.sha256)])),
            ("table_sha256", digest.sha256_bytes(table_bytes)),
        ]
    )
    text = metadata = None
    if text_path is not None:
        text_bytes = Path(text_path).read_bytes()
        metadata_bytes = Path(metadata_path).read_bytes()
        text = read_tanzil_text(text_bytes)
        metadata = read_tanzil_metadata(metadata_bytes)
        inputs["tanzil"] = OrderedDict(
            [
                ("text_sha256", digest.sha256_bytes(text_bytes)),
                ("metadata_sha256", digest.sha256_bytes(metadata_bytes)),
            ]
        )
    report = OrderedDict([("format", FORMAT), ("inputs", inputs)])
    report.update(measure(ayat, font_info.code_points, read_table(table_bytes), text, metadata))
    return report


def measure(ayat, font_code_points, table, text=None, metadata=None):
    """The six measurements of the parsed KFGQPC ayat; Tanzil's parsed text and metadata are optional."""
    if table.ayah_end is None:
        raise PackError("known differences: the table has no ayah_end rule")
    bodies = [_body(aya, table) for aya in ayat]
    uthmani = [_tokens(body) for body, _ in bodies]
    emlaey = [_tokens(aya.emlaey) for aya in ayat]
    report = OrderedDict()
    report["ayat"] = len(ayat)
    report["ayah_end_tail"] = _tail_counts(ayat, bodies)
    report["tokens"] = OrderedDict(
        [
            ("uthmani", _token_totals(ayat, uthmani)),
            ("emlaey", _token_totals(ayat, emlaey)),
        ]
    )
    report["pause_marks_joined_to_letters"] = _pause_marks(ayat, uthmani)
    report["no_break_spaces"] = _no_break_spaces(ayat, bodies, table)
    report["missing_from_font"] = OrderedDict(
        [
            ("aya_text", _missing([aya.text for aya in ayat], font_code_points)),
            ("aya_text_emlaey", _missing([aya.emlaey for aya in ayat], font_code_points)),
        ]
    )
    report["emlaey_against_uthmani_tokens"] = _token_differences(ayat, uthmani, emlaey)
    report["sajda_sign"] = _sajdas(ayat, metadata)
    report["tanzil_token_map"] = _token_map(ayat, uthmani, text)
    return report


def encode_report(report):
    """Two-space indent, a final line break; refuses any byte outside ASCII."""
    data = (json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if not data.isascii():
        raise PackError("the measurement report holds a byte outside ASCII")
    return data


def lines(report):
    """The summary the command prints: counts only."""
    pause = report["pause_marks_joined_to_letters"]
    spaces = report["no_break_spaces"]
    missing = report["missing_from_font"]
    emlaey = report["emlaey_against_uthmani_tokens"]
    sajda = report["sajda_sign"]
    token_map = report["tanzil_token_map"]
    return [
        "ayat %d, ayah-end tail missing %d" % (report["ayat"], report["ayah_end_tail"]["missing"]),
        "pause marks joined to letters: tokens %d, ayat %d" % (pause["tokens"], pause["ayat"]),
        "no-break spaces: total %d, at the ayah end %d, at a quarter opening %d, elsewhere %d"
        % (spaces["total"], spaces["at_ayah_end"], spaces["at_quarter_opening"], spaces["elsewhere"]["count"]),
        "code points missing from the font: aya_text %d, aya_text_emlaey %d"
        % (len(missing["aya_text"]), len(missing["aya_text_emlaey"])),
        "emlaey token counts differ in %d ayat" % emlaey["ayat_differing"],
        "U+06E9 ayat %d, Tanzil sajdas %s" % (sajda["kfgqpc_ayat"], sajda["tanzil"]),
        "token map: %s" % (token_map if isinstance(token_map, str) else token_map["map"]),
    ]


def _body(aya, table):
    rule = table.ayah_end_rule_at((aya.surah, aya.number)) or table.ayah_end
    glyph = table.ayah_end.code_points["first_number_glyph"] + aya.number - 1
    tail = chr(rule.code_points["separator"]) + chr(glyph)
    if aya.text.endswith(tail):
        return aya.text[: -len(tail)], tail[0]
    return aya.text, None


def _tokens(text):
    return text.split(SPACE)


def _words(tokens):
    return [t for t in tokens if t]


def _tail_counts(ayat, bodies):
    missing = [_address(aya) for aya, (_, separator) in zip(ayat, bodies) if separator is None]
    return OrderedDict([("missing", len(missing)), ("first", missing[:FIRST_ADDRESSES])])


def _token_totals(ayat, tokens):
    with_empty = [_address(aya) for aya, runs in zip(ayat, tokens) if "" in runs]
    return OrderedDict(
        [
            ("tokens", sum(len(_words(runs)) for runs in tokens)),
            ("ayat_with_empty_runs", len(with_empty)),
            ("first", with_empty[:FIRST_ADDRESSES]),
        ]
    )


def _pause_marks(ayat, tokens):
    per_mark = Counter()
    joined = 0
    standalone = 0
    places = []
    for aya, runs in zip(ayat, tokens):
        found = False
        for token in runs:
            marks = [c for c in token if ord(c) in PAUSE_MARKS]
            if not marks:
                continue
            if any(is_letter(ord(c)) for c in token):
                joined += 1
                found = True
                per_mark.update(code_point(c) for c in marks)
            else:
                standalone += 1
        if found:
            places.append(_address(aya))
    return OrderedDict(
        [
            ("tokens", joined),
            ("ayat", len(places)),
            ("per_mark", OrderedDict(sorted(per_mark.items()))),
            ("standalone_mark_tokens", standalone),
            ("first", places[:FIRST_ADDRESSES]),
        ]
    )


def _no_break_spaces(ayat, bodies, table):
    quarter = table.quarter_start
    opening = None
    if quarter is not None:
        opening = chr(quarter.code_points["sign"]) + chr(quarter.code_points["separator"])
    total = at_end = at_opening = 0
    elsewhere = Counter()
    for aya, (body, separator) in zip(ayat, bodies):
        count = aya.text.count(NO_BREAK_SPACE)
        total += count
        end = 1 if separator == NO_BREAK_SPACE else 0
        start = opening.count(NO_BREAK_SPACE) if opening is not None and body.startswith(opening) else 0
        at_end += end
        at_opening += start
        if count - end - start:
            elsewhere[_address(aya)] = count - end - start
    places = list(elsewhere)
    return OrderedDict(
        [
            ("total", total),
            ("at_ayah_end", at_end),
            ("at_quarter_opening", at_opening),
            (
                "elsewhere",
                OrderedDict(
                    [("count", sum(elsewhere.values())), ("ayat", len(places)), ("first", places[:FIRST_ADDRESSES])]
                ),
            ),
        ]
    )


def _missing(texts, font_code_points):
    occurrences = Counter()
    in_ayat = Counter()
    for text in texts:
        absent = [ord(c) for c in text if ord(c) not in font_code_points]
        occurrences.update(absent)
        in_ayat.update(set(absent))
    return [
        OrderedDict([("code_point", code_point(cp)), ("occurrences", occurrences[cp]), ("ayat", in_ayat[cp])])
        for cp in sorted(occurrences)
    ]


def _token_differences(ayat, uthmani, emlaey):
    histogram = Counter()
    differing = []
    for aya, a, b in zip(ayat, uthmani, emlaey):
        difference = len(_words(b)) - len(_words(a))
        histogram[difference] += 1
        if difference:
            differing.append(_address(aya))
    return OrderedDict(
        [
            ("histogram_emlaey_minus_uthmani", _histogram(histogram)),
            ("ayat_differing", len(differing)),
            ("first", differing[:FIRST_ADDRESSES]),
        ]
    )


def _sajdas(ayat, metadata):
    marked = [(aya.surah, aya.number) for aya in ayat if SAJDA_SIGN in aya.text]
    repeated = sum(1 for aya in ayat if aya.text.count(SAJDA_SIGN) > 1)
    result = OrderedDict(
        [
            ("kfgqpc_ayat", len(marked)),
            ("kfgqpc_ayat_with_more_than_one", repeated),
            ("kfgqpc_addresses", [_label(a) for a in marked]),
        ]
    )
    if metadata is None:
        result["tanzil"] = "not measured: no Tanzil metadata given"
        return result
    listed = [(s.sura, s.aya) for s in metadata.sajdas]
    both = set(marked) & set(listed)
    result["tanzil"] = len(listed)
    result["both"] = len(both)
    result["kfgqpc_only"] = [_label(a) for a in marked if a not in both]
    result["tanzil_only"] = [_label(a) for a in listed if a not in both]
    return result


def _token_map(ayat, uthmani, text):
    if text is None:
        return TOKEN_MAP_NOT_MEASURED
    tanzil = [aya for sura in text.suras for aya in sura.ayat]
    if [(a.surah, a.number) for a in tanzil] != [(a.surah, a.number) for a in ayat]:
        raise PackError("the Tanzil text and the KFGQPC file do not hold the same ayah addresses")
    histogram = Counter()
    differing = []
    for aya, own, theirs in zip(ayat, uthmani, tanzil):
        difference = len(_words(_tokens(theirs.text.value))) - len(_words(own))
        histogram[difference] += 1
        if difference:
            differing.append(_address(aya))
    return OrderedDict(
        [
            ("map", TOKEN_MAP_NOT_MEASURED),
            ("histogram_tanzil_minus_kfgqpc_tokens", _histogram(histogram)),
            ("ayat_where_counts_differ", len(differing)),
            ("first", differing[:FIRST_ADDRESSES]),
        ]
    )


def _histogram(counter):
    return OrderedDict(("%+d" % k if k else "0", counter[k]) for k in sorted(counter))


def _address(aya):
    return _label((aya.surah, aya.number))


def _label(address):
    return "hafs:%d:%d" % address


def _ascii(value):
    return "".join(c if " " <= c <= "~" else code_point(c) for c in value)
