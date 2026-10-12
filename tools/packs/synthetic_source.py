"""Writes a synthetic source for the pipeline's tests: a text file in Tanzil's
text XML form, a metadata file in the form of Tanzil's quran-data.xml, a mark
table and a build description.

Nothing here is Quran text. The words are Latin, and the one Arabic-script
phrase is plainly synthetic; every non-ASCII character is a \\u escape so that
no editor can recompose it.

    python3 synthetic_source.py <directory>
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

TEXT_FILE = "text.xml"
METADATA_FILE = "metadata.xml"
MARK_TABLE_FILE = "marks.json"
BUILD_FILE = "build.json"

TEXT_NOTICE = "\nSynthetic text source for tests. Not Quran text.\nVersion 1\n"
METADATA_NOTICE = "\nSynthetic metadata source for tests.\nVersion 1\n"

_OPENING = "Synthetic opening line"

# (name, basmala or None, ayat). Surah 1 ayah 4 is the synthetic phrase with a
# fatha, inside a leading space and two trailing spaces.
SYNTHETIC_SURAHS = (
    (
        "Synthetic surah one",
        _OPENING,
        (
            "Synthetic ayah one",
            "Synthetic \u06d6 two \u06e9",
            "\u06da Synthetic three",
            " \u0646\u064e\u0635 \u062a\u062c\u0631\u064a\u0628\u064a  ",
        ),
    ),
    (
        "Synthetic surah two",
        None,
        (
            "Synthetic  double  spaces",
            "Synthetic \u0640 \u06e5 tatweel-and-small-waw \u06d7",
            "Synthetic-pair joined \u06e9",
        ),
    ),
    (
        "Synthetic surah three",
        _OPENING,
        ("Synthetic last ayah",),
    ),
)

# (ayas, start, name, tname, ename, type, order, rukus), surah numbers by position.
SYNTHETIC_SURAS = (
    (4, 0, "Synthetic surah one", "Synthetic-One", "Synthetic One", "Meccan", 2, 1),
    (3, 4, "Synthetic surah two", "Synthetic-Two", "Synthetic Two", "Medinan", 1, 1),
    (1, 7, "Synthetic surah three", "Synthetic-Three", "Synthetic Three", "Meccan", 3, 1),
)
SYNTHETIC_JUZS = ((1, 1), (2, 1))
SYNTHETIC_QUARTERS = ((1, 1), (1, 2), (1, 3), (1, 4), (2, 1), (2, 2), (2, 3), (3, 1))
SYNTHETIC_MANZILS = ((1, 1),)
SYNTHETIC_RUKUS = ((1, 1), (2, 1), (3, 1))
SYNTHETIC_PAGES = ((1, 1), (1, 4), (2, 2), (3, 1))
SYNTHETIC_SAJDAS = ((1, 2, "recommended"), (2, 3, "obligatory"))

SYNTHETIC_MARK_CODE_POINTS = ("U+06D6", "U+06D7", "U+06DA", "U+06E9")

_DECLARATION = '<?xml version="1.0" encoding="utf-8" ?>'
_FORBIDDEN_IN_VALUES = ("&", "<", '"', "\t", "\n", "\r")


def synthetic_text_xml(surahs=SYNTHETIC_SURAHS, notice=TEXT_NOTICE) -> bytes:
    lines = [_DECLARATION, "<quran>"]
    for number, (name, basmala, ayat) in enumerate(surahs, 1):
        lines.append("  " + _start_tag("sura", (("index", number), ("name", name))))
        for aya, text in enumerate(ayat, 1):
            attributes = [("index", aya), ("text", text)]
            if aya == 1 and basmala is not None:
                attributes.append(("bismillah", basmala))
            lines.append("    " + _empty_tag("aya", attributes))
        lines.append("  </sura>")
    lines.append("</quran>")
    lines.extend(["", _comment(notice)])
    return _encode(lines)


def synthetic_metadata_xml(
    suras=SYNTHETIC_SURAS,
    juzs=SYNTHETIC_JUZS,
    quarters=SYNTHETIC_QUARTERS,
    manzils=SYNTHETIC_MANZILS,
    rukus=SYNTHETIC_RUKUS,
    pages=SYNTHETIC_PAGES,
    sajdas=SYNTHETIC_SAJDAS,
    notice=METADATA_NOTICE,
) -> bytes:
    lines = [
        _DECLARATION,
        _comment(notice),
        _start_tag(
            "quran",
            (("type", "metadata"), ("version", "1.0"), ("copyright", "Synthetic"),
             ("license", "synthetic")),
        ),
    ]
    sura_fields = ("ayas", "start", "name", "tname", "ename", "type", "order", "rukus")
    lines.extend(
        _group(
            "suras", "chapters", "sura",
            [tuple(zip(sura_fields, sura)) for sura in suras],
        )
    )
    for group, alias, element, points in (
        ("juzs", "juz", "juz", juzs),
        ("hizbs", "quarters", "quarter", quarters),
        ("manzils", "stations", "manzil", manzils),
        ("rukus", "sections", "ruku", rukus),
        ("pages", None, "page", pages),
    ):
        lines.extend(
            _group(group, alias, element, [(("sura", s), ("aya", a)) for s, a in points])
        )
    lines.extend(
        _group(
            "sajdas", None, "sajda",
            [(("sura", s), ("aya", a), ("type", t)) for s, a, t in sajdas],
        )
    )
    lines.append("</quran>")
    return _encode(lines)


def synthetic_mark_table() -> bytes:
    document = {"code_points": list(SYNTHETIC_MARK_CODE_POINTS)}
    return _json_bytes(document)


def synthetic_build_config(text_sha256: str, metadata_sha256: str) -> dict:
    return {
        "id": "synthetic-text",
        "version": 1,
        "changelog": [
            {
                "version": 1,
                "date": "2026-01-01",
                "summary": "Synthetic pack built from the synthetic source; not Quran text",
            }
        ],
        "riwaya": "synthetic",
        "edition": "synthetic-edition",
        "sources": {
            "text": _source(
                TEXT_FILE, text_sha256, 1, "Synthetic text source",
                "https://example.invalid/synthetic/text"
                "?marks=true&sajdah=true&rub=false&outType=xml&agree=true",
            ),
            "edition_map": _source(
                METADATA_FILE, metadata_sha256, 4, "Synthetic metadata source",
                "https://example.invalid/synthetic/metadata",
            ),
        },
        "mark_table": MARK_TABLE_FILE,
        "reviews": [
            {
                "reviewer": "synthetic reviewer",
                "date": "2026-01-01",
                "scope": "synthetic test data",
            }
        ],
    }


def write_synthetic_source(
    directory, text_xml=None, metadata_xml=None, mark_table=None, **config_overrides
) -> Path:
    """Writes the four files into [directory] and returns the build description's path."""
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    text_xml = synthetic_text_xml() if text_xml is None else text_xml
    metadata_xml = synthetic_metadata_xml() if metadata_xml is None else metadata_xml
    mark_table = synthetic_mark_table() if mark_table is None else mark_table
    (directory / TEXT_FILE).write_bytes(text_xml)
    (directory / METADATA_FILE).write_bytes(metadata_xml)
    (directory / MARK_TABLE_FILE).write_bytes(mark_table)
    config = synthetic_build_config(
        hashlib.sha256(text_xml).hexdigest(), hashlib.sha256(metadata_xml).hexdigest()
    )
    config.update(config_overrides)
    build = directory / BUILD_FILE
    build.write_bytes(_json_bytes(config))
    return build


def _source(file, sha256, registry_row, name, url) -> dict:
    return {
        "file": file,
        "file_sha256": sha256,
        "registry_row": registry_row,
        "name": name,
        "publisher": "Synthetic publisher",
        "url": url,
        "version": "1",
        "fetched_on": "2026-01-01",
        "trust_grade": "A",
        "licence": {
            "text": None,
            "permission_ref": "Synthetic permission %d" % registry_row,
            "allows_export": True,
        },
    }


def _group(name, alias, element, rows) -> list:
    attributes = (("alias", alias),) if alias is not None else ()
    lines = ["  " + _start_tag(name, attributes)]
    for index, row in enumerate(rows, 1):
        lines.append("    " + _empty_tag(element, (("index", index),) + tuple(row)))
    lines.append("  </%s>" % name)
    return lines


def _start_tag(name, attributes) -> str:
    return "<%s%s>" % (name, _attributes(attributes))


def _empty_tag(name, attributes) -> str:
    return "<%s%s />" % (name, _attributes(attributes))


def _attributes(attributes) -> str:
    parts = []
    for key, value in attributes:
        value = str(value)
        if any(c in value for c in _FORBIDDEN_IN_VALUES):
            raise ValueError("attribute %s holds a character the form forbids" % key)
        parts.append(' %s="%s"' % (key, value))
    return "".join(parts)


def _comment(notice: str) -> str:
    if "--" in notice or notice.endswith("-"):
        raise ValueError("a comment cannot hold -- or end with -")
    return "<!--%s-->" % notice


def _encode(lines) -> bytes:
    return ("\n".join(lines) + "\n").encode("utf-8")


def _json_bytes(document) -> bytes:
    return (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _main(argv) -> int:
    if len(argv) != 2:
        sys.stderr.write("usage: synthetic_source.py <directory>\n")
        return 2
    print(write_synthetic_source(argv[1]))
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
