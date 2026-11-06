"""The Tanzil text against the KFGQPC Hafs text, character by character (PRD 9.4), and the page and juz of every ayah (P2).

Per ayah: the table's presentation rules are checked and removed from the
KFGQPC side, its equivalence rules applied to that side, and what remains is
compared code point by code point with the Tanzil ayah. The KFGQPC text is a
witness: nothing here reaches a pack. Nothing is normalised.

The report holds addresses, numbers and code points written U+XXXX, never a
character of either text; `encode_report` refuses any byte outside ASCII.
Every problem is collected, so one run shows them all; any problem fails.
"""

from __future__ import annotations

import difflib
import json
from collections import OrderedDict
from pathlib import Path

from . import digest, kfgqpc, source_checks
from .errors import PackError, code_point
from .known_differences import EVERY_AYAH, read_table
from .tokens import is_letter

FORMAT = "holyquran-kfgqpc-comparison"
CONTEXT = 2
FIRST_ADDRESSES = 3


def run_comparison(text, metadata, kfgqpc_path, table_path, profile, tanzil_sha256):
    """Reads the KFGQPC file and the table, compares, and returns the report with
    every input recorded; `tanzil_sha256` is {"text": hex, "metadata": hex}."""
    witness, kfgqpc_sha256 = kfgqpc.read_kfgqpc_file(kfgqpc_path, profile.ayat)
    table_bytes = Path(table_path).read_bytes()
    table = read_table(table_bytes)
    report = OrderedDict()
    report["format"] = FORMAT
    report["tanzil"] = OrderedDict(
        [("text_sha256", tanzil_sha256["text"]), ("metadata_sha256", tanzil_sha256["metadata"])]
    )
    report["kfgqpc"] = OrderedDict(
        [
            ("registry_row", kfgqpc.REGISTRY_ROW),
            ("file", kfgqpc.FILE_NAME),
            ("version", kfgqpc.VERSION),
            ("sha256", kfgqpc_sha256),
        ]
    )
    report["table"] = OrderedDict(
        [("version", table.version), ("sha256", digest.sha256_bytes(table_bytes))]
    )
    report.update(compare(text, metadata, witness, table))
    return report


def compare(text, metadata, witness, table):
    """The comparison of the parsed Tanzil text and metadata with the parsed KFGQPC ayat under `table`."""
    tanzil = [(aya.surah, aya.number, aya.text.value) for sura in text.suras for aya in sura.ayat]
    _check_addresses(tanzil, witness)
    ayah_counts = {sura.index: len(sura.ayat) for sura in text.suras}
    for kind, points in (("juz", metadata.juzs), ("quarter", metadata.quarters), ("page", metadata.pages)):
        source_checks.check_points(kind, points, ayah_counts)
        if not points or (points[0].sura, points[0].aya) != (1, 1):
            raise PackError("the metadata's %s list does not start at 1:1" % kind)
    for rule in table.equivalences:
        if rule.applies_to != EVERY_AYAH:
            for address in rule.applies_to:
                if not 1 <= address[1] <= ayah_counts.get(address[0], 0):
                    raise PackError(
                        "known differences: rule %s applies to hafs:%d:%d, not an ayah of the text"
                        % ((rule.id,) + address)
                    )

    juz_of = _unit_of(metadata.juzs, tanzil)
    page_of = _unit_of(metadata.pages, tanzil)
    quarter_starts = {(p.sura, p.aya) for p in metadata.quarters}
    applied = {rule.id: 0 for rule in _rules(table)}
    applied_at = {rule.id: set() for rule in table.equivalences}
    presentation_problems = []
    differences = []
    patterns = OrderedDict()
    page_differences = []
    juz_differences = []
    signed = set()

    for (surah, number, tanzil_text), aya in zip(tanzil, witness):
        address = (surah, number)
        label = "hafs:%d:%d" % address
        side = aya.text
        if table.ayah_end is not None:
            side = _ayah_end(table.ayah_end, side, number, label, presentation_problems, applied)
        if table.quarter_start is not None:
            rule = table.quarter_start
            opening = chr(rule.code_points["sign"]) + chr(rule.code_points["separator"])
            if side.startswith(opening):
                side = side[len(opening):]
                signed.add(address)
                applied[rule.id] += 1
        side = _equivalences(table.equivalences, side, address, applied, applied_at)
        if side != tanzil_text:
            _differences(label, side, tanzil_text, differences, patterns)
        for kind, found, expected, problems in (
            ("page", aya.page, page_of[address], page_differences),
            ("juz", aya.juz, juz_of[address], juz_differences),
        ):
            if found != expected:
                problems.append(
                    OrderedDict([("address", label), ("kfgqpc", found), ("tanzil_metadata", expected)])
                )

    if table.quarter_start is not None:
        rule = table.quarter_start
        for addresses, problem in (
            (signed - quarter_starts, "opens with the quarter sign but is not a quarter start of the metadata"),
            (quarter_starts - signed, "is a quarter start of the metadata but does not open with the quarter sign"),
        ):
            for address in sorted(addresses):
                presentation_problems.append(
                    _problem("hafs:%d:%d" % address, rule.id, problem, ())
                )

    table_problems = []
    for rule in table.equivalences:
        if rule.applies_to == EVERY_AYAH:
            if not applied[rule.id]:
                table_problems.append(
                    OrderedDict([("rule", rule.id), ("problem", "applied in no ayah")])
                )
        else:
            for address in rule.applies_to:
                if address not in applied_at[rule.id]:
                    table_problems.append(
                        OrderedDict(
                            [("rule", rule.id), ("address", "hafs:%d:%d" % address), ("problem", "not applied in this listed ayah")]
                        )
                    )

    pattern_list = sorted(
        patterns.items(), key=lambda item: (-item[1]["count"], item[0])
    )
    report = OrderedDict()
    report["ayat"] = len(tanzil)
    report["rules"] = [
        OrderedDict(
            [
                ("id", rule.id),
                ("kind", rule.kind),
                ("applies_to", _scope(rule.applies_to)),
                ("approved_by", rule.approved_by),
                ("applied", applied[rule.id]),
            ]
        )
        for rule in _rules(table)
    ]
    report["presentation_problems"] = presentation_problems
    report["table_problems"] = table_problems
    report["differences"] = differences
    report["patterns"] = [
        OrderedDict(
            [
                ("kfgqpc", _code_points(key[0])),
                ("tanzil", _code_points(key[1])),
                ("count", value["count"]),
                ("first", value["first"]),
            ]
        )
        for key, value in pattern_list
    ]
    report["page_differences"] = page_differences
    report["juz_differences"] = juz_differences
    report["passed"] = not any(
        (presentation_problems, table_problems, differences, page_differences, juz_differences)
    )
    return report


def summary(report):
    """One ASCII line of counts."""
    return (
        "ayat %d, undocumented differences %d in %d patterns, presentation problems %d, "
        "table problems %d, page differences %d, juz differences %d"
        % (
            report["ayat"],
            len(report["differences"]),
            len(report["patterns"]),
            len(report["presentation_problems"]),
            len(report["table_problems"]),
            len(report["page_differences"]),
            len(report["juz_differences"]),
        )
    )


def encode_report(report):
    """The report as JSON, one list entry per line, refused if any byte is outside ASCII."""
    lines = ["{"]
    items = list(report.items())
    for index, (key, value) in enumerate(items):
        end = "," if index < len(items) - 1 else ""
        if isinstance(value, list) and value:
            lines.append("  %s: [" % _compact(key))
            lines.extend(
                "    %s%s" % (_compact(item), "," if i < len(value) - 1 else "")
                for i, item in enumerate(value)
            )
            lines.append("  ]" + end)
        else:
            lines.append("  %s: %s%s" % (_compact(key), _compact(value), end))
    lines.append("}")
    data = "\n".join(lines) + "\n"
    if not data.isascii():
        raise PackError("the comparison report holds a character outside ASCII; it is not written")
    return data.encode("ascii")


def _check_addresses(tanzil, witness):
    if len(tanzil) != len(witness):
        raise PackError(
            "the Tanzil text has %d ayat, the KFGQPC file %d" % (len(tanzil), len(witness))
        )
    for (surah, number, _), aya in zip(tanzil, witness):
        if (surah, number) != (aya.surah, aya.number):
            raise PackError(
                "KFGQPC id %d is %d:%d where the Tanzil text has %d:%d"
                % (aya.id, aya.surah, aya.number, surah, number)
            )


def _unit_of(points, tanzil):
    """The unit number of every ayah: the last point at or before it."""
    starts = [(p.sura, p.aya) for p in points]
    result = {}
    unit = 0
    for surah, number, _ in tanzil:
        while unit < len(starts) and starts[unit] <= (surah, number):
            unit += 1
        result[(surah, number)] = unit
    return result


def _ayah_end(rule, side, number, label, problems, applied):
    separator = chr(rule.code_points["separator"])
    expected = rule.code_points["first_number_glyph"] + number - 1
    if side.endswith(separator + chr(expected)):
        applied[rule.id] += 1
        return side[:-2]
    found = side[-2:]
    if len(found) == 2 and found[0] == separator:
        glyph = ord(found[1]) - rule.code_points["first_number_glyph"] + 1
        problem = "ends with the number glyph %s, not %s for ayah %d" % (
            code_point(found[1]),
            code_point(expected),
            number,
        )
        if glyph >= 1:
            problem += " (it is the glyph of ayah %d)" % glyph
    else:
        problem = "does not end with %s and the number glyph %s" % (
            code_point(separator),
            code_point(expected),
        )
    problems.append(_problem(label, rule.id, problem, found))
    return side


def _equivalences(rules, side, address, applied, applied_at):
    """One pass from left to right; at each position the first listed rule that matches wins."""
    active = [
        (rule, "".join(chr(c) for c in rule.code_points["kfgqpc"]), "".join(chr(c) for c in rule.code_points["tanzil"]))
        for rule in rules
        if rule.applies_to == EVERY_AYAH or address in rule.applies_to
    ]
    if not active:
        return side
    out = []
    index = 0
    while index < len(side):
        for rule, kfgqpc_sequence, tanzil_sequence in active:
            if side.startswith(kfgqpc_sequence, index):
                out.append(tanzil_sequence)
                index += len(kfgqpc_sequence)
                applied[rule.id] += 1
                applied_at[rule.id].add(address)
                break
        else:
            out.append(side[index])
            index += 1
    return "".join(out)


def _differences(label, side, tanzil_text, differences, patterns):
    words = _word_numbers(tanzil_text)
    matcher = difflib.SequenceMatcher(None, side, tanzil_text, autojunk=False)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        word, in_mark = words[j1]
        differences.append(
            OrderedDict(
                [
                    ("address", label),
                    ("word", word),
                    ("in_mark", in_mark),
                    ("kfgqpc", _context(side, i1, i2)),
                    ("tanzil", _context(tanzil_text, j1, j2)),
                ]
            )
        )
        key = (side[i1:i2], tanzil_text[j1:j2])
        entry = patterns.setdefault(key, {"count": 0, "first": []})
        entry["count"] += 1
        if label not in entry["first"] and len(entry["first"]) < FIRST_ADDRESSES:
            entry["first"].append(label)


def _word_numbers(text):
    """For each index 0..len(text): (word number, in a mark token) of the token there, or of the last one before it (D-083)."""
    result = []
    current = (0, False)
    word = 0
    index = 0
    while index < len(text):
        if text[index] == " ":
            result.append(current)
            index += 1
            continue
        end = index
        while end < len(text) and text[end] != " ":
            end += 1
        if any(is_letter(ord(c)) for c in text[index:end]):
            word += 1
            current = (word, False)
        else:
            current = (word, True)
        result.extend([current] * (end - index))
        index = end
    result.append(current)
    return result


def _context(text, start, end):
    return OrderedDict(
        [
            ("before", _code_points(text[max(0, start - CONTEXT):start])),
            ("sequence", _code_points(text[start:end])),
            ("after", _code_points(text[end:end + CONTEXT])),
        ]
    )


def _problem(label, rule_id, problem, found):
    return OrderedDict(
        [("address", label), ("rule", rule_id), ("problem", problem), ("found", _code_points(found))]
    )


def _rules(table):
    return [r for r in (table.ayah_end, table.quarter_start) if r is not None] + list(table.equivalences)


def _scope(applies_to):
    if isinstance(applies_to, tuple):
        return ["hafs:%d:%d" % address for address in applies_to]
    return applies_to


def _code_points(text):
    return [code_point(c) for c in text]


def _compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(", ", ": "))
