"""The manifest.json rules of a text pack (docs/CONTENT_PACKS.md), as the
app's strict parser applies them, for the independent verifier; and the
parts every kind shares (`read_checked`, `Fields`, the riwaya, changelog,
sources, files and reviews), which `verify_tafsir` uses."""

from __future__ import annotations

import datetime
import json
import math
import re

TEXT = "text.sqlite"
FORMAT_VERSION = 1
DIVISION_KINDS = ("juz", "hizb", "rub", "page")

_HASH = re.compile(r"[0-9a-f]{64}")
_DATE = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})")
_RIWAYA = re.compile(r"[a-z][a-z0-9_]*")
_SURAH_KEY = re.compile(r"[1-9][0-9]*")
_PRINTABLE = re.compile(r"[\x21-\x7e]{1,80}")

_MANIFEST_KEYS = (
    "format", "format_version", "id", "kind", "version", "changelog",
    "riwaya", "edition", "font", "sources", "files", "surah_sha256",
    "counts", "reviews",
)
_SOURCE_KEYS = (
    "role", "registry_row", "name", "publisher", "url", "version",
    "fetched_on", "file_sha256", "trust_grade", "options", "licence",
)
_COUNT_KEYS = ("surahs", "ayat", "words", "marks", "divisions", "sajdas")


def safe_name(name):
    """A name from the pack when it is printable ASCII, so that no message
    carries a value of the pack."""
    if _PRINTABLE.fullmatch(name):
        return name
    return "a name that is not printable ASCII"


class _Duplicate(ValueError):
    pass


class _NotFinite(ValueError):
    pass


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise _Duplicate()
        result[key] = value
    return result


def _refuse_constant(_):
    raise _NotFinite()


def _finite(literal):
    value = float(literal)
    if not math.isfinite(value):
        raise _NotFinite()
    return value


def read_manifest(path, problems):
    """The manifest when it parses with every rule met, else None."""
    return read_checked(path, problems, _manifest_problems)


def read_checked(path, problems, check):
    """The manifest when it parses strictly and `check(manifest, problems)`
    finds nothing, else None."""
    if not path.is_file():
        problems.append("manifest.json is missing")
        return None
    data = path.read_bytes()
    if data.startswith(b"\xef\xbb\xbf"):
        problems.append("manifest.json begins with a byte order mark")
        return None
    try:
        decoded = data.decode("utf-8")
    except UnicodeDecodeError as e:
        problems.append("manifest.json is not UTF-8 (byte %d)" % e.start)
        return None
    try:
        manifest = json.loads(
            decoded, object_pairs_hook=_pairs,
            parse_constant=_refuse_constant, parse_float=_finite)
    except _Duplicate:
        problems.append("manifest.json repeats a key in one object")
        return None
    except _NotFinite:
        problems.append("manifest.json holds NaN or Infinity")
        return None
    except json.JSONDecodeError as e:
        problems.append(
            "manifest.json is not JSON (line %d, column %d)"
            % (e.lineno, e.colno))
        return None
    found = []
    check(manifest, found)
    _bom_string_problems(manifest, "manifest", found)
    problems.extend(found)
    return None if found else manifest


def _bom_string_problems(value, path, problems):
    if isinstance(value, str):
        if value.startswith("\ufeff"):
            problems.append("%s begins with U+FEFF" % path)
    elif isinstance(value, dict):
        for key, item in value.items():
            if key.startswith("\ufeff"):
                problems.append("%s has a field that begins with U+FEFF" % path)
            _bom_string_problems(item, "%s.%s" % (path, safe_name(key)), problems)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            _bom_string_problems(item, "%s[%d]" % (path, index), problems)


BAD = object()


class Fields:
    """A JSON object of the manifest, read field by field; a field of the
    wrong type or form adds a problem and reads as BAD."""

    def __init__(self, value, path, problems):
        self.value = value
        self.path = path
        self.problems = problems

    def problem(self, text):
        self.problems.append("%s %s" % (self.path, text))

    def field_problem(self, key, text):
        self.problems.append("%s.%s %s" % (self.path, key, text))

    def expect_keys(self, keys):
        for key in self.value:
            if key not in keys:
                self.problem("has unknown field %s" % safe_name(key))
        for key in keys:
            if key not in self.value:
                self.problem("lacks field %s" % key)

    def field(self, key, accept, kind):
        if key not in self.value:
            return BAD
        value = self.value[key]
        if accept(value):
            return value
        self.field_problem(key, "is not " + kind)
        return BAD

    def string(self, key):
        return self.field(key, lambda v: isinstance(v, str), "a string")

    def nullable_string(self, key):
        return self.field(
            key, lambda v: v is None or isinstance(v, str), "a string or null")

    def boolean(self, key):
        return self.field(key, lambda v: type(v) is bool, "a boolean")

    def integer(self, key):
        return self.field(key, lambda v: type(v) is int, "an integer")

    def count(self, key):
        return self._at_least(key, 0, "is negative")

    def positive(self, key):
        return self._at_least(key, 1, "is not positive")

    def _at_least(self, key, low, text):
        value = self.integer(key)
        if value is not BAD and value < low:
            self.field_problem(key, text)
            return BAD
        return value

    def hash(self, key):
        value = self.string(key)
        if value is not BAD and not _HASH.fullmatch(value):
            self.field_problem(key, "is not lowercase hex SHA-256")
            return BAD
        return value

    def date(self, key):
        value = self.string(key)
        if value is BAD:
            return value
        match = _DATE.fullmatch(value)
        if match is None:
            self.field_problem(key, "is not YYYY-MM-DD")
            return BAD
        try:
            datetime.date(*(int(group) for group in match.groups()))
        except ValueError:
            self.field_problem(key, "is not a calendar date")
            return BAD
        return value

    def object(self, key):
        value = self.field(key, lambda v: isinstance(v, dict), "an object")
        if value is BAD:
            return None
        return Fields(value, "%s.%s" % (self.path, key), self.problems)

    def nullable_object(self, key):
        value = self.field(
            key, lambda v: v is None or isinstance(v, dict),
            "an object or null")
        if value is BAD or value is None:
            return value
        return Fields(value, "%s.%s" % (self.path, key), self.problems)

    def objects(self, key):
        items = self.field(key, lambda v: isinstance(v, list), "a list")
        if items is BAD:
            return None
        objects = []
        for index, item in enumerate(items):
            where = "%s.%s[%d]" % (self.path, key, index)
            if isinstance(item, dict):
                objects.append(Fields(item, where, self.problems))
            else:
                self.problems.append("%s is not an object" % where)
        return objects


def _manifest_problems(manifest, problems):
    if not isinstance(manifest, dict):
        problems.append("manifest.json is not a JSON object")
        return
    if manifest.get("format") != "holyquran-pack":
        problems.append("manifest.format is not holyquran-pack")
    version = manifest.get("format_version")
    if type(version) is not int or version != FORMAT_VERSION:
        problems.append(
            "manifest.format_version is not %d, the format version this "
            "verifier knows" % FORMAT_VERSION)
        return
    root = Fields(manifest, "manifest", problems)
    root.expect_keys(_MANIFEST_KEYS)
    kind = root.string("kind")
    if kind is not BAD and kind != "text":
        root.field_problem("kind", "is not a known kind")
    riwaya_problems(root, "text")
    root.string("id")
    root.positive("version")
    root.string("edition")
    changelog_problems(root)
    font = root.object("font")
    if font is not None:
        font.expect_keys(("family", "version", "sha256"))
        font.string("family")
        font.string("version")
        font.hash("sha256")
    sources_problems(root, "text", ("text", "edition_map"))
    files_problems(root, "text", TEXT)
    surahs = _counts_problems(root.object("counts"))
    _surah_sha256_problems(root.object("surah_sha256"), surahs)
    review_problems(root)


def changelog_problems(root):
    for change in root.objects("changelog") or ():
        change.expect_keys(("version", "date", "summary"))
        change.positive("version")
        change.date("date")
        change.string("summary")


def review_problems(root):
    for review in root.objects("reviews") or ():
        review.expect_keys(("reviewer", "date", "scope"))
        review.string("reviewer")
        review.date("date")
        review.string("scope")


def riwaya_problems(root, kind):
    riwaya = root.nullable_string("riwaya")
    if riwaya is None:
        root.field_problem("riwaya", "of a %s pack is null" % kind)
    elif riwaya is not BAD and not _RIWAYA.fullmatch(riwaya):
        root.field_problem("riwaya", "is not of the form ^[a-z][a-z0-9_]*$")


def sources_problems(root, kind, roles):
    """`roles[0]` is the role a pack of `kind` must name."""
    sources = root.objects("sources")
    if sources is None:
        return
    if not root.value["sources"]:
        root.field_problem("sources", "is empty")
    found = []
    for source in sources:
        source.expect_keys(_SOURCE_KEYS)
        role = source.string("role")
        if role is not BAD and role not in roles:
            source.field_problem("role", "is not " + " or ".join(roles))
        found.append(role)
        source.positive("registry_row")
        for key in ("name", "publisher", "url", "version"):
            source.string(key)
        source.date("fetched_on")
        source.hash("file_sha256")
        grade = source.string("trust_grade")
        if grade is not BAD and grade not in ("A", "B", "C"):
            source.field_problem("trust_grade", "is not A, B or C")
        _options_problems(source.nullable_object("options"))
        _licence_problems(source.object("licence"))
    if sources and roles[0] not in found:
        root.field_problem(
            "sources", "of a %s pack has no %s source" % (kind, roles[0]))


def _options_problems(options):
    if options is None or options is BAD:
        return
    if not options.value:
        options.problem("is empty; use null")
    for key, value in options.value.items():
        if key == "":
            options.problem("has an empty option name")
        elif type(value) not in (str, int, float, bool):
            options.field_problem(
                safe_name(key), "is not a string, number or boolean")


def _licence_problems(licence):
    if licence is None:
        return
    licence.expect_keys(("text", "permission_ref", "notice", "allows_export"))
    text = licence.nullable_string("text")
    permission = licence.nullable_string("permission_ref")
    if text is None and permission is None:
        licence.problem("has neither text nor permission_ref")
    licence.nullable_string("notice")
    licence.boolean("allows_export")


def files_problems(root, kind, data_file):
    files = root.objects("files")
    if files is None:
        return
    names = []
    for file in files:
        file.expect_keys(("name", "sha256", "bytes"))
        name = file.string("name")
        if name is not BAD and (
                name in ("", ".") or "/" in name or "\\" in name
                or ".." in name):
            file.field_problem("name", "is not a bare file name")
            name = BAD
        names.append(name)
        file.hash("sha256")
        file.count("bytes")
    if len(root.value["files"]) != 1 or names != [data_file]:
        root.field_problem(
            "files", "of a %s pack is not exactly %s" % (kind, data_file))


def _counts_problems(counts):
    """counts.surahs, or BAD."""
    if counts is None:
        return BAD
    counts.expect_keys(_COUNT_KEYS)
    surahs = counts.count("surahs")
    for key in _COUNT_KEYS[1:4] + ("sajdas",):
        counts.count(key)
    divisions = counts.object("divisions")
    if divisions is not None:
        divisions.expect_keys(DIVISION_KINDS)
        for kind in DIVISION_KINDS:
            divisions.count(kind)
    return surahs


def _surah_sha256_problems(digests, surahs):
    if digests is None:
        return
    numbers = set()
    for key in digests.value:
        if surahs is not BAD and (
                not _SURAH_KEY.fullmatch(key) or int(key) > surahs):
            digests.problem("has unknown field %s" % safe_name(key))
            continue
        digests.hash(key)
        if _SURAH_KEY.fullmatch(key):
            numbers.add(int(key))
    if surahs is BAD or len(numbers) == surahs:
        return
    first = next(n for n in range(1, surahs + 1) if n not in numbers)
    digests.problem(
        "lacks field %d (%d of the keys 1 to %d are missing)"
        % (first, surahs - len(numbers), surahs))
