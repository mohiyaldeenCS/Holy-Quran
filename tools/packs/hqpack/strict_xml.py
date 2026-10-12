"""A byte-level reader of the closed XML subset both Tanzil files use.

Every value is the exact bytes between its quotes, decoded strictly. Anything
a conforming XML parser would change (references, white space inside a value,
CDATA) or that lies outside the subset is refused, never rewritten, which is
why the standard library's XML parsers are not used.
"""

from __future__ import annotations

from dataclasses import dataclass
from hqpack.errors import PackError, code_point


@dataclass(frozen=True)
class SourceValue:
    """A value as stored in the file: its text, byte offset and byte length."""

    value: str
    offset: int
    length: int


@dataclass(frozen=True)
class Element:
    """An element: attributes in file order and child elements."""

    name: str
    attributes: dict
    children: list
    offset: int


@dataclass(frozen=True)
class Document:
    """The root element and the comments outside it, in file order."""

    root: Element
    comments: list


_SPACE = b" \t\n\r"
_LETTERS = frozenset(range(0x61, 0x7B))
_DECLARATION_ORDER = ("version", "encoding", "standalone")
_BOM = b"\xef\xbb\xbf"


def parse(data: bytes) -> Document:
    """Reads [data], refusing anything outside the subset with a PackError."""
    return _Reader(data).document()


def require_attributes(element, required, optional, where):
    """Refuses a missing attribute of [required] or one in neither set."""
    for name in element.attributes:
        if name not in required and name not in optional:
            raise PackError(
                "an unknown attribute %s on %s at byte %d"
                % (name, where, element.offset)
            )
    for name in required:
        if name not in element.attributes:
            raise PackError(
                "%s without the %s attribute at byte %d" % (where, name, element.offset)
            )


def require_children(element, name, where):
    """Refuses an element with no children or with a child other than [name]."""
    if not element.children:
        raise PackError(
            "%s without %s elements at byte %d" % (where, name, element.offset)
        )
    for child in element.children:
        if child.name != name:
            raise PackError(
                "an element %s inside %s at byte %d" % (child.name, where, child.offset)
            )


def only_comment(document):
    """The one comment outside the root element; refuses any other count."""
    if len(document.comments) != 1:
        raise PackError(
            "%d comments outside the root element, not exactly one"
            % len(document.comments)
        )
    return document.comments[0]


def _fail(what, at):
    raise PackError("XML: %s at byte %d" % (what, at))


def _is_xml_char(c):
    return (
        c in (0x09, 0x0A, 0x0D)
        or 0x20 <= c <= 0xD7FF
        or 0xE000 <= c <= 0xFFFD
        or 0x10000 <= c <= 0x10FFFF
    )


class _Reader:
    def __init__(self, data):
        self._data = data
        self._at = 0
        self._comments = []

    def document(self):
        if self._data.startswith(_BOM):
            _fail("a byte order mark", 0)
        try:
            self._data.decode("utf-8", "strict")
        except UnicodeDecodeError as e:
            _fail("malformed UTF-8", e.start)
        if self._data.startswith(b"<?xml"):
            self._declaration()
        self._misc()
        root = self._root()
        self._misc()
        if self._at != len(self._data):
            _fail("content after the root element", self._at)
        return Document(root=root, comments=list(self._comments))

    def _starts(self, prefix, at=None):
        return self._data.startswith(prefix, self._at if at is None else at)

    def _byte(self, at=None):
        at = self._at if at is None else at
        return self._data[at] if at < len(self._data) else None

    def _skip_space(self):
        start = self._at
        while self._at < len(self._data) and self._data[self._at] in _SPACE:
            self._at += 1
        return self._at > start

    def _declaration(self):
        self._at = 5
        if self._byte() is None or self._byte() not in _SPACE:
            _fail("a processing instruction", 0)
        attributes, _ = self._attributes("the XML declaration", declaration=True)
        names = list(attributes)
        if names != [n for n in _DECLARATION_ORDER if n in attributes]:
            _fail("an XML declaration with unknown or misordered attributes", 0)
        version = attributes.get("version")
        if version is None or version.value != "1.0":
            _fail("an XML declaration without version 1.0", 0)
        encoding = attributes.get("encoding")
        if encoding is not None and encoding.value.lower() != "utf-8":
            _fail("an XML declaration naming an encoding other than UTF-8", 0)
        standalone = attributes.get("standalone")
        if standalone is not None and standalone.value not in ("yes", "no"):
            _fail("an XML declaration with an invalid standalone", 0)

    def _misc(self):
        while True:
            self._skip_space()
            if self._starts(b"<!--"):
                self._comments.append(self._comment())
            elif self._starts(b"<?"):
                _fail("a processing instruction", self._at)
            elif self._starts(b"<!"):
                _fail("a DOCTYPE or markup declaration", self._at)
            else:
                return

    def _comment(self):
        start = self._at + 4
        end = self._data.find(b"--", start)
        if end < 0:
            _fail("an unterminated comment", self._at)
        if self._byte(end + 2) != 0x3E:
            _fail('"--" inside a comment', end)
        self._at = end + 3
        return self._value(start, end, "a comment")

    def _root(self):
        if self._at >= len(self._data):
            _fail("no root element", self._at)
        if not self._starts(b"<"):
            _fail("character data outside the root element", self._at)
        root, empty = self._start_tag()
        if empty:
            return root
        stack = [root]
        while stack:
            self._skip_space()
            parent = stack[-1]
            if self._starts(b"</"):
                self._end_tag(parent)
                stack.pop()
            elif self._starts(b"<"):
                self._refuse_markup(parent)
                child, empty = self._start_tag()
                parent.children.append(child)
                if not empty:
                    stack.append(child)
            else:
                self._refuse_content(parent)
        return root

    def _refuse_markup(self, parent):
        if self._starts(b"<!--"):
            _fail("a comment inside the root element", self._at)
        if self._starts(b"<![CDATA["):
            _fail("a CDATA section inside %s" % parent.name, self._at)
        if self._starts(b"<!"):
            _fail("a markup declaration inside %s" % parent.name, self._at)
        if self._starts(b"<?"):
            _fail("a processing instruction inside %s" % parent.name, self._at)

    def _refuse_content(self, parent):
        if self._at >= len(self._data):
            _fail("an unterminated element %s" % parent.name, parent.offset)
        if self._starts(b"&"):
            _fail("a reference inside %s" % parent.name, self._at)
        _fail("character data inside %s" % parent.name, self._at)

    def _name(self, what, followers):
        start = self._at
        while self._byte() in _LETTERS:
            self._at += 1
        following = self._byte()
        if self._at == start or (
            following is not None
            and following not in _SPACE
            and following not in followers
        ):
            _fail("%s that is not lowercase ASCII letters" % what, start)
        return self._data[start : self._at].decode("ascii")

    def _start_tag(self):
        offset = self._at
        self._at += 1
        name = self._name("an element name", b"/>")
        attributes, empty = self._attributes("element %s" % name)
        element = Element(name=name, attributes=attributes, children=[], offset=offset)
        return element, empty

    def _end_tag(self, element):
        start = self._at
        self._at += 2
        name = self._name("an end tag name", b">")
        if name != element.name:
            _fail("an end tag that does not match %s" % element.name, start)
        self._skip_space()
        if self._byte() != 0x3E:
            _fail("a malformed end tag of %s" % element.name, self._at)
        self._at += 1

    def _attributes(self, where, declaration=False):
        found = {}
        while True:
            spaced = self._skip_space()
            if self._at >= len(self._data):
                _fail("an unterminated tag of %s" % where, self._at)
            if declaration:
                if self._starts(b"?>"):
                    self._at += 2
                    return found, True
            elif self._starts(b"/>"):
                self._at += 2
                return found, True
            elif self._starts(b">"):
                self._at += 1
                return found, False
            start = self._at
            if not spaced:
                _fail("an unexpected byte in the tag of %s" % where, start)
            name = self._name("an attribute name", b"=")
            if name in found:
                _fail("a repeated attribute %s in %s" % (name, where), start)
            self._skip_space()
            if self._byte() != 0x3D:
                _fail("an attribute without = in %s" % where, self._at)
            self._at += 1
            self._skip_space()
            found[name] = self._quoted(where)

    def _quoted(self, where):
        quote = self._byte()
        if quote not in (0x22, 0x27):
            _fail("an unquoted attribute value in %s" % where, self._at)
        start = self._at + 1
        for i in range(start, len(self._data)):
            byte = self._data[i]
            if byte == quote:
                self._at = i + 1
                return self._value(start, i, where)
            if byte == 0x26:
                _fail("a reference in an attribute of %s" % where, i)
            if byte == 0x3C:
                _fail('"<" in an attribute of %s' % where, i)
            if byte in (0x09, 0x0A, 0x0D):
                _fail("a tab or line break in an attribute of %s" % where, i)
            if byte < 0x20:
                _fail("a control character in an attribute of %s" % where, i)
        _fail("an unterminated attribute value in %s" % where, start)

    def _value(self, start, end, where) -> SourceValue:
        source = self._data[start:end]
        if not source:
            _fail("an empty value in %s" % where, start)
        if source.startswith(_BOM):
            _fail("a value beginning with U+FEFF in %s" % where, start)
        try:
            value = source.decode("utf-8", "strict")
        except UnicodeDecodeError as e:
            _fail("malformed UTF-8 in %s" % where, start + e.start)
        offset = start
        for c in value:
            if not _is_xml_char(ord(c)):
                _fail("the character %s in %s" % (code_point(c), where), offset)
            offset += len(c.encode("utf-8"))
        return SourceValue(value=value, offset=start, length=end - start)

