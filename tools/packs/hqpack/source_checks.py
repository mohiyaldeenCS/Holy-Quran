"""The build checks that compare the text file, the metadata file and the profile.

Each function raises PackError on the first rule broken, naming addresses and
numbers only. Nothing is computed into the pack here except what the review of
docs/CONTENT_PACKS.md allows: a hizb is every fourth quarter, by position (P2).
"""

from __future__ import annotations

import re

from .errors import PackError, code_point
from .profiles import DIVISION_KINDS

# P6: the source's two place values, by a fixed table.
REVELATION_PLACES = {"Meccan": "makki", "Medinan": "madani"}

SAJDA_SIGN = 0x06E9


def check_notice(notice, version, role):
    """The notice must name the source version the description claims, so a file of another version is refused."""
    pattern = r"Version %s(?!\.?[0-9])" % re.escape(version)
    if not re.search(pattern, notice.value):
        raise PackError(
            "sources.%s: the notice of the file does not name Version %s"
            % (role, version)
        )


def check_structure(profile, text, metadata):
    """Surah and ayah counts against the profile and the metadata, and the basmala rule (P4)."""
    if len(text.suras) != profile.surahs:
        raise PackError(
            "the text file has %d surahs, not %d" % (len(text.suras), profile.surahs)
        )
    if len(metadata.suras) != len(text.suras):
        raise PackError(
            "the metadata lists %d surahs, the text file has %d"
            % (len(metadata.suras), len(text.suras))
        )
    start = 0
    for sura, meta in zip(text.suras, metadata.suras):
        if meta.ayas != len(sura.ayat):
            raise PackError(
                "surah %d: the metadata gives %d ayat, the text file has %d"
                % (sura.index, meta.ayas, len(sura.ayat))
            )
        if meta.start != start:
            raise PackError(
                "surah %d: the metadata starts it after %d ayat, the text file after %d"
                % (sura.index, meta.start, start)
            )
        start += len(sura.ayat)
        has_basmala = sura.ayat[0].basmala is not None
        if has_basmala == (sura.index in profile.without_basmala):
            raise PackError(
                "surah %d %s a separate basmala, which the profile does not allow"
                % (sura.index, "has" if has_basmala else "lacks")
            )
    if start != profile.ayat:
        raise PackError("the text file has %d ayat, not %d" % (start, profile.ayat))


def revelation(metadata):
    """(place, order) per surah: place through REVELATION_PLACES, orders a permutation of 1..n (P6)."""
    places = []
    for meta in metadata.suras:
        place = REVELATION_PLACES.get(meta.type)
        if place is None:
            raise PackError(
                "surah %d: the metadata type is not one of %s"
                % (meta.index, ", ".join(sorted(REVELATION_PLACES)))
            )
        places.append(place)
    orders = [meta.order for meta in metadata.suras]
    if sorted(orders) != list(range(1, len(orders) + 1)):
        raise PackError(
            "the revelation orders of the metadata are not 1 to %d, each once"
            % len(orders)
        )
    return list(zip(places, orders))


def divisions(profile, metadata, ayah_counts):
    """The division rows (kind, number, surah, ayah) from the metadata's own lists (P2)."""
    quarters = metadata.quarters
    if len(quarters) % 4:
        raise PackError(
            "the metadata lists %d quarters, not a whole number of hizbs"
            % len(quarters)
        )
    lists = {
        "juz": metadata.juzs,
        "hizb": quarters[::4],
        "rub": quarters,
        "page": metadata.pages,
    }
    rows = []
    for kind in DIVISION_KINDS:
        points = lists[kind]
        if len(points) != profile.divisions[kind]:
            raise PackError(
                "the metadata gives %d %s units, not %d"
                % (len(points), kind, profile.divisions[kind])
            )
        check_points(kind, points, ayah_counts)
        if (points[0].sura, points[0].aya) != (1, 1):
            raise PackError("%s 1 does not start at 1:1" % kind)
        rows.extend(
            (kind, number, point.sura, point.aya)
            for number, point in enumerate(points, start=1)
        )
    check_points("manzil", metadata.manzils, ayah_counts)
    check_points("ruku", metadata.rukus, ayah_counts)
    return rows


def sajdas(metadata, ayah_counts):
    """The sajda rows (surah, ayah)."""
    check_points("sajda", metadata.sajdas, ayah_counts)
    return [(sajda.sura, sajda.aya) for sajda in metadata.sajdas]


def check_points(kind, points, ayah_counts):
    """Every point is an ayah of the text, each after the one before."""
    previous = None
    for number, point in enumerate(points, start=1):
        address = (point.sura, point.aya)
        if not 1 <= point.aya <= ayah_counts.get(point.sura, 0):
            raise PackError(
                "%s %d refers to %d:%d, not an ayah of the text" % ((kind, number) + address)
            )
        if previous is not None and address <= previous:
            raise PackError(
                "%s %d at %d:%d does not start after %s %d"
                % ((kind, number) + address + (kind, number - 1))
            )
        previous = address


def check_sajda_signs(options, sajda_rows, ayat):
    """With sajda signs in the text (D-079), the ayat holding U+06E9 are exactly the metadata's sajdas."""
    if not options or options.get("sajdah") != "true":
        return
    signed = {address for address, text in ayat if chr(SAJDA_SIGN) in text}
    listed = set(sajda_rows)
    for label, addresses in (
        ("hold %s but are not sajdas of the metadata", signed - listed),
        ("are sajdas of the metadata but do not hold %s", listed - signed),
    ):
        if addresses:
            raise PackError(
                "ayat %s %s"
                % (
                    ", ".join("%d:%d" % a for a in sorted(addresses)),
                    label % code_point(SAJDA_SIGN),
                )
            )


def check_font_coverage(font, texts):
    """Every code point of every ayah and basmala is in the font the text is paired with (PRD 9.1)."""
    missing = {}
    for where, text in texts:
        for c in text:
            if ord(c) not in font.code_points and ord(c) not in missing:
                missing[ord(c)] = where
    if missing:
        raise PackError(
            "the font lacks %s"
            % ", ".join(
                "%s (first in %s)" % (code_point(c), where)
                for c, where in sorted(missing.items())
            )
        )
