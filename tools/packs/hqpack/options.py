"""`sources[].options` from a download URL (D-077), and the checks they imply.

The options chosen on the download page decide the bytes of the file (D-079),
so the pipeline checks that the file agrees with them.
"""

from __future__ import annotations

from urllib.parse import parse_qsl, urlsplit

from .errors import PackError, code_point

_TERMS = "agree"

# The code points each Tanzil option adds to the text when "true".
_OPTION_CODE_POINTS = {
    "rub": (0x06DE,),
    "sajdah": (0x06E9,),
    "marks": (0x06D6, 0x06D7, 0x06D8, 0x06D9, 0x06DA, 0x06DB, 0x06DC),
}


def options_from_url(url: str):
    query = urlsplit(url).query
    if not query:
        return None
    try:
        pairs = parse_qsl(
            query,
            keep_blank_values=True,
            strict_parsing=True,
            encoding="utf-8",
            errors="strict",
        )
    except (ValueError, UnicodeDecodeError):
        raise PackError("the source URL has a malformed query") from None
    options = {}
    seen = set()
    for name, value in pairs:
        if not name:
            raise PackError("the source URL has a query parameter with no name")
        if name in seen:
            raise PackError(
                "the source URL repeats the query parameter %s" % _printable(name)
            )
        seen.add(name)
        if name != _TERMS:
            options[name] = value
    return options or None


def _printable(name: str) -> str:
    if all(0x20 <= ord(c) <= 0x7E for c in name):
        return name
    return " ".join(code_point(c) for c in name)


def option_problems(options, texts) -> list:
    if options is None:
        return []
    checked = [name for name in options if name in _OPTION_CODE_POINTS]
    first, counts = _occurrences(
        texts, {cp for name in checked for cp in _OPTION_CODE_POINTS[name]}
    )
    problems = []
    for name in checked:
        value = options[name]
        code_points = _OPTION_CODE_POINTS[name]
        if value == "false":
            problems.extend(
                "option %s=false, but %s holds %s (%d in all)"
                % (name, first[cp], code_point(cp), counts[cp])
                for cp in code_points
                if cp in first
            )
        elif value == "true":
            if not any(cp in first for cp in code_points):
                problems.append(
                    "option %s=true, but no text holds any of %s"
                    % (name, ", ".join(code_point(cp) for cp in code_points))
                )
        else:
            problems.append(
                "option %s has a value other than true or false" % name
            )
    return problems


def _occurrences(texts, wanted: set):
    first = {}
    counts = {}
    for where, text in texts:
        for c in text:
            cp = ord(c)
            if cp in wanted:
                first.setdefault(cp, where)
                counts[cp] = counts.get(cp, 0) + 1
    return first, counts
