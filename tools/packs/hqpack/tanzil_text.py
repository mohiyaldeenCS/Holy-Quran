"""The Tanzil text XML: `<quran><sura index name><aya index text [bismillah]/>`.

The basmala is the `bismillah` attribute of an ayah numbered 1, kept apart from
the ayah text. The one comment outside the root is the copyright notice.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from hqpack import strict_xml
from hqpack.errors import PackError
from hqpack.strict_xml import SourceValue


@dataclass(frozen=True)
class TextAya:
    surah: int
    number: int
    text: SourceValue
    basmala: Optional[SourceValue]


@dataclass(frozen=True)
class TextSura:
    index: int
    name: SourceValue
    ayat: list


@dataclass(frozen=True)
class TanzilText:
    suras: list
    notice: SourceValue


def read_tanzil_text(data: bytes) -> TanzilText:
    """Reads the file, refusing anything outside the form with a PackError."""
    try:
        return _read(data)
    except PackError as e:
        raise PackError("Tanzil text: %s" % e) from None


def _read(data):
    document = strict_xml.parse(data)
    root = document.root
    if root.name != "quran":
        raise PackError("a root element other than quran at byte %d" % root.offset)
    strict_xml.require_attributes(root, (), (), "quran")
    strict_xml.require_children(root, "sura", "quran")
    suras = [_sura(element, i) for i, element in enumerate(root.children, 1)]
    return TanzilText(suras=suras, notice=strict_xml.only_comment(document))


def _sura(element, index):
    where = "sura %d" % index
    strict_xml.require_attributes(element, ("index", "name"), (), where)
    _require_index(element, index, where)
    strict_xml.require_children(element, "aya", where)
    ayat = [_aya(child, index, n) for n, child in enumerate(element.children, 1)]
    return TextSura(index=index, name=element.attributes["name"], ayat=ayat)


def _aya(element, surah, number):
    where = "sura %d aya %d" % (surah, number)
    strict_xml.require_attributes(element, ("index", "text"), ("bismillah",), where)
    _require_index(element, number, where)
    if element.children:
        raise PackError(
            "an element inside %s at byte %d" % (where, element.children[0].offset)
        )
    basmala = element.attributes.get("bismillah")
    if basmala is not None and number != 1:
        raise PackError(
            "a bismillah attribute on %s at byte %d" % (where, basmala.offset)
        )
    return TextAya(
        surah=surah, number=number, text=element.attributes["text"], basmala=basmala
    )


def _require_index(element, expected, where):
    index = element.attributes["index"]
    if index.value != str(expected):
        raise PackError(
            "%s has an index other than %d at byte %d" % (where, expected, index.offset)
        )
