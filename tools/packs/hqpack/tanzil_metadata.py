"""Tanzil's quran-data.xml: surah facts, divisions and sajdas.

The structure is that of the published file; anything else is refused. The
build, not this reader, maps the surah `type` and checks the lists against
the text.
"""

from __future__ import annotations

from dataclasses import dataclass

from hqpack import strict_xml
from hqpack.errors import PackError
from hqpack.strict_xml import SourceValue


@dataclass(frozen=True)
class MetaSura:
    index: int
    ayas: int
    start: int
    name: SourceValue
    tname: SourceValue
    ename: SourceValue
    type: str
    order: int
    rukus: int


@dataclass(frozen=True)
class Point:
    index: int
    sura: int
    aya: int


@dataclass(frozen=True)
class MetaSajda:
    index: int
    sura: int
    aya: int
    type: str


@dataclass(frozen=True)
class TanzilMetadata:
    suras: list
    juzs: list
    quarters: list
    manzils: list
    rukus: list
    pages: list
    sajdas: list
    notice: SourceValue


_ROOT_ATTRIBUTES = ("type", "version", "copyright", "license")
_CONTAINERS = (
    ("suras", "sura"),
    ("juzs", "juz"),
    ("hizbs", "quarter"),
    ("manzils", "manzil"),
    ("rukus", "ruku"),
    ("pages", "page"),
    ("sajdas", "sajda"),
)
_SURA_ATTRIBUTES = (
    "index", "ayas", "start", "name", "tname", "ename", "type", "order", "rukus",
)
_POINT_ATTRIBUTES = ("index", "sura", "aya")
_SAJDA_ATTRIBUTES = ("index", "sura", "aya", "type")
_SAJDA_TYPES = ("recommended", "obligatory")
_DIGITS = frozenset("0123456789")


def read_tanzil_metadata(data: bytes) -> TanzilMetadata:
    """Reads the file, refusing anything outside the form with a PackError."""
    try:
        return _read(data)
    except PackError as e:
        raise PackError("Tanzil metadata: %s" % e) from None


def _read(data):
    document = strict_xml.parse(data)
    root = document.root
    if root.name != "quran":
        raise PackError("a root element other than quran at byte %d" % root.offset)
    strict_xml.require_attributes(root, (), _ROOT_ATTRIBUTES, "quran")
    _require_containers(root)
    lists = []
    for container, (name, item) in zip(root.children, _CONTAINERS):
        strict_xml.require_attributes(container, (), ("alias",), name)
        strict_xml.require_children(container, item, name)
        lists.append(
            [_item(element, item, i) for i, element in enumerate(container.children, 1)]
        )
    suras, juzs, quarters, manzils, rukus, pages, sajdas = lists
    return TanzilMetadata(
        suras=suras,
        juzs=juzs,
        quarters=quarters,
        manzils=manzils,
        rukus=rukus,
        pages=pages,
        sajdas=sajdas,
        notice=strict_xml.only_comment(document),
    )


def _require_containers(root):
    expected = [name for name, _ in _CONTAINERS]
    names = [child.name for child in root.children]
    for child in root.children:
        if child.name not in expected:
            raise PackError(
                "an element %s inside quran at byte %d" % (child.name, child.offset)
            )
    for name in expected:
        count = names.count(name)
        if count != 1:
            raise PackError("%d %s elements inside quran, not one" % (count, name))
    if names != expected:
        raise PackError("the containers inside quran are not in the published order")


def _item(element, item, index):
    where = "%s %d" % (item, index)
    if item == "sura":
        return _sura(element, index, where)
    if item == "sajda":
        return _sajda(element, index, where)
    strict_xml.require_attributes(element, _POINT_ATTRIBUTES, (), where)
    _require_leaf_and_index(element, index, where)
    return Point(
        index=index,
        sura=_integer(element, "sura", 1, where),
        aya=_integer(element, "aya", 1, where),
    )


def _sura(element, index, where):
    strict_xml.require_attributes(element, _SURA_ATTRIBUTES, (), where)
    _require_leaf_and_index(element, index, where)
    attributes = element.attributes
    return MetaSura(
        index=index,
        ayas=_integer(element, "ayas", 1, where),
        start=_integer(element, "start", 0, where),
        name=attributes["name"],
        tname=attributes["tname"],
        ename=attributes["ename"],
        type=attributes["type"].value,
        order=_integer(element, "order", 1, where),
        rukus=_integer(element, "rukus", 1, where),
    )


def _sajda(element, index, where):
    strict_xml.require_attributes(element, _SAJDA_ATTRIBUTES, (), where)
    _require_leaf_and_index(element, index, where)
    kind = element.attributes["type"]
    if kind.value not in _SAJDA_TYPES:
        raise PackError("%s has an unknown type at byte %d" % (where, kind.offset))
    return MetaSajda(
        index=index,
        sura=_integer(element, "sura", 1, where),
        aya=_integer(element, "aya", 1, where),
        type=kind.value,
    )


def _require_leaf_and_index(element, index, where):
    if element.children:
        raise PackError(
            "an element inside %s at byte %d" % (where, element.children[0].offset)
        )
    if _integer(element, "index", 1, where) != index:
        raise PackError(
            "%s has an index other than %d at byte %d"
            % (where, index, element.attributes["index"].offset)
        )


def _integer(element, name, minimum, where):
    """An ASCII decimal without sign or leading zeros, at least [minimum]."""
    source = element.attributes[name]
    text = source.value
    plain = set(text) <= _DIGITS and (text == "0" or not text.startswith("0"))
    if not plain or int(text) < minimum:
        raise PackError(
            "%s: %s is not a decimal integer >= %d at byte %d"
            % (where, name, minimum, source.offset)
        )
    return int(text)
