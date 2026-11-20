"""The pipeline: a text source file and its metadata file to a verified, unsigned text pack.

Order (PRD 9.3): hash and read the sources, run every build check, write into
a temporary directory, read every stored text back against the source bytes,
digest the stored bytes, write the manifest, run the independent verifier,
and only then move the pack to `<out>/<id>/<version>/`. Any failure leaves
nothing behind. Signing is a separate step (signing.py, D-080).

The text source is Tanzil's text XML, stored in format 1, or KFGQPC's
hafsData file when the description's text source is its registry row 2
(D-195, D-198): stored as published, in the proposed format 3, its
presentation in spans of their own cut by the table of known differences.
Tanzil's metadata stays the source of surah facts, sajdas and divisions,
and Tanzil's text is the witness of the comparison (D-198 Q1). No hafs pack
is built from the KFGQPC text while its rights row is incomplete (D-198 Q3).
"""

from __future__ import annotations

import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from . import compare, database, digest, manifest, source_checks
from . import kfgqpc as kfgqpc_file
from .config import read_build_config
from .errors import PackError, code_point
from .font import read_font
from .git_tree import git_tree
from .known_differences import presentation, read_table
from .mark_table import read_mark_table
from .options import option_problems, options_from_url
from .profiles import DIVISION_KINDS, profile_for
from .tanzil_metadata import read_tanzil_metadata
from .tanzil_text import read_tanzil_text
from .tokens import presented_spans, spans
from .verify import verify_pack

TEXT_FILE = "text.sqlite"
MANIFEST_FILE = "manifest.json"
FONT_FAMILY = "Amiri Quran"
# D-198 Q5: a KFGQPC text's basmala is this ayah between its presentation spans.
BASMALA_AYAH = (1, 1)


@dataclass(frozen=True)
class BuildResult:
    directory: Path
    sqlite_version: str
    counts: dict
    text_sha256: str
    manifest_sha256: str
    surah_sha256: dict


@dataclass(frozen=True)
class _Source:
    """What a text source gives the writer: its rows, the manifest's
    sources, and per surah the source bytes every stored text must equal."""

    format_version: int
    surah_rows: list
    division_rows: list
    sajda_rows: list
    sources: list
    font: object
    marks: frozenset
    presentation: object
    expected: list  # [(surah, name bytes, basmala bytes or None, [(ayah, bytes)])]


def build_pack(config_path, font_path, out_root, unapproved=False, kfgqpc=None, table=None, tanzil_text=None):
    """Builds the pack; `unapproved` builds a test copy (D-165), the one case
    that skips the KFGQPC comparison and nothing else. `kfgqpc` and `table`
    are the KFGQPC Hafs file and the table of known differences, given
    exactly when the profile needs the comparison. A KFGQPC text always
    takes the table, for its presentation rules, and `tanzil_text`, the
    Tanzil text XML, as the witness exactly when the profile compares."""
    sqlite_version = database.require_sqlite()
    config = read_build_config(config_path)
    profile = profile_for(config.riwaya, config.pack_id, unapproved)
    compares = profile.needs_kfgqpc_comparison and not unapproved
    from_kfgqpc = config.text.registry_row == kfgqpc_file.REGISTRY_ROW
    if from_kfgqpc:
        _check_kfgqpc_inputs(config, unapproved, compares, kfgqpc, table, tanzil_text)
    else:
        _check_tanzil_inputs(config, unapproved, compares, kfgqpc, table, tanzil_text, out_root)
    out_root = Path(out_root)
    destination = out_root / config.pack_id / str(config.version)
    if destination.exists():
        raise PackError("%s exists; a pack version is never rebuilt in place" % destination)
    if from_kfgqpc:
        source = _kfgqpc_source(config, profile, compares, font_path, table, tanzil_text)
    else:
        source = _tanzil_source(config, profile, compares, font_path, kfgqpc, table)

    out_root.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=".build-", dir=str(out_root)))
    try:
        directory = work / config.pack_id / str(config.version)
        directory.mkdir(parents=True)
        text_file = directory / TEXT_FILE
        database.write_text_database(
            text_file, source.surah_rows, source.division_rows, source.sajda_rows, source.format_version
        )
        surah_sha256 = _read_back(text_file, source.expected)
        counts = _counts(source)
        text_sha256 = digest.sha256_file(text_file)
        font = source.font
        manifest_bytes = manifest.encode_manifest(
            manifest.build_manifest(
                pack_id=config.pack_id,
                version=config.version,
                changelog=config.changelog,
                riwaya=config.riwaya,
                edition=config.edition,
                font={"family": font.family, "version": font.version, "sha256": font.sha256},
                sources=source.sources,
                text_sha256=text_sha256,
                text_bytes=text_file.stat().st_size,
                surah_sha256=surah_sha256,
                counts=counts,
                reviews=config.reviews,
                format_version=source.format_version,
            )
        )
        (directory / MANIFEST_FILE).write_bytes(manifest_bytes)
        report = verify_pack(
            directory, mark_code_points=source.marks, font=font, presentation=source.presentation
        )
        if report.problems:
            raise PackError(
                "the built pack fails verification: " + "; ".join(report.problems[:20])
            )
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.rename(str(directory), str(destination))
    finally:
        shutil.rmtree(str(work), ignore_errors=True)
    return BuildResult(
        directory=destination,
        sqlite_version=sqlite_version,
        counts=counts,
        text_sha256=text_sha256,
        manifest_sha256=digest.sha256_bytes(manifest_bytes),
        surah_sha256=surah_sha256,
    )


def _check_tanzil_inputs(config, unapproved, compares, kfgqpc, table, tanzil_text, out_root):
    given = (kfgqpc is not None, table is not None)
    if unapproved:
        _check_test_copy(config, out_root)
    if compares and given != (True, True):
        raise PackError(
            "riwaya %s needs the character-by-character comparison with the "
            "KFGQPC text and the page-list comparison (PRD 9.4, "
            "docs/CONTENT_PACKS.md P2); give the KFGQPC file and the table of "
            "known differences (--kfgqpc, --table)" % config.riwaya
        )
    if not compares and given != (False, False):
        raise PackError(
            "this build does not run the KFGQPC comparison (riwaya %s%s); "
            "it takes no KFGQPC file or table"
            % (config.riwaya, ", unapproved test copy" if unapproved else "")
        )
    if tanzil_text is not None:
        raise PackError(
            "the text source is the Tanzil text; a Tanzil text is given only as the "
            "witness of a KFGQPC text (sources.text of registry row %d)" % kfgqpc_file.REGISTRY_ROW
        )


def _check_kfgqpc_inputs(config, unapproved, compares, kfgqpc, table, tanzil_text):
    if unapproved:
        raise PackError(
            "an unapproved test copy is built from the Tanzil text; the KFGQPC text "
            "(registry row %d) is stored in format %d, which the app does not read yet"
            % (kfgqpc_file.REGISTRY_ROW, database.PRESENTED_FORMAT_VERSION)
        )
    if kfgqpc is not None:
        raise PackError("the text source is the KFGQPC file; it takes no KFGQPC witness (--kfgqpc)")
    if table is None:
        raise PackError(
            "a KFGQPC text is stored with its presentation, cut by the rules of "
            "the table of known differences; give the table (--table)"
        )
    if compares and tanzil_text is None:
        raise PackError(
            "riwaya %s needs the character-by-character comparison with the "
            "Tanzil text (PRD 9.4, D-198 Q6); give the Tanzil text XML "
            "(--tanzil-text)" % config.riwaya
        )
    if not compares and tanzil_text is not None:
        raise PackError(
            "this build does not run the comparison (riwaya %s); it takes no "
            "Tanzil text" % config.riwaya
        )


def _tanzil_source(config, profile, compares, font_path, kfgqpc, table):
    text_options = options_from_url(config.text.url)
    edition_map_options = options_from_url(config.edition_map.url)
    text_bytes = _source_bytes(config.text)
    metadata_bytes = _source_bytes(config.edition_map)
    marks = read_mark_table(config.mark_table.read_bytes())
    font = read_font(Path(font_path).read_bytes())
    if font.family != FONT_FAMILY:
        raise PackError("the font is %s, not %s" % (_ascii(font.family), FONT_FAMILY))
    text = read_tanzil_text(text_bytes)
    metadata = read_tanzil_metadata(metadata_bytes)

    source_checks.check_notice(text.notice, config.text.version, "text")
    source_checks.check_metadata_version(metadata, config.edition_map.version)
    source_checks.check_structure(profile, text, metadata)
    places = source_checks.revelation(metadata)
    ayah_counts = {sura.index: len(sura.ayat) for sura in text.suras}
    division_rows = source_checks.divisions(profile, metadata, ayah_counts)
    sajda_rows = source_checks.sajdas(metadata, ayah_counts)
    ayat = [
        ((aya.surah, aya.number), aya.text.value)
        for sura in text.suras
        for aya in sura.ayat
    ]
    drawn = list(_drawn_texts(text))
    source_checks.check_profile_signs(profile, drawn)
    problems = option_problems(text_options, drawn)
    if problems:
        raise PackError("the text does not match its options: " + "; ".join(problems))
    source_checks.check_sajda_signs(text_options, sajda_rows, ayat)
    source_checks.check_font_coverage(font, drawn)
    surah_rows = _surah_rows(text, metadata, places, marks)
    if compares:
        tanzil_sha256 = {
            "text": digest.sha256_bytes(text_bytes),
            "metadata": digest.sha256_bytes(metadata_bytes),
        }
        _compare_with_kfgqpc(text, metadata, kfgqpc, table, profile, tanzil_sha256)
    return _Source(
        format_version=database.FORMAT_VERSION,
        surah_rows=surah_rows,
        division_rows=division_rows,
        sajda_rows=sajda_rows,
        sources=[
            _source_entry(config.text, text_bytes, text_options, text.notice.value),
            _source_entry(
                config.edition_map,
                metadata_bytes,
                edition_map_options,
                None if metadata.notice is None else metadata.notice.value,
            ),
        ],
        font=font,
        marks=marks,
        presentation=None,
        expected=_tanzil_expected(text, metadata, text_bytes, metadata_bytes),
    )


def _kfgqpc_source(config, profile, compares, font_path, table, tanzil_text):
    _check_kfgqpc_description(config)
    edition_map_options = options_from_url(config.edition_map.url)
    text_bytes = _source_bytes(config.text)
    metadata_bytes = _source_bytes(config.edition_map)
    marks = read_mark_table(config.mark_table.read_bytes())
    font = _kfgqpc_font(font_path)
    rules = presentation(read_table(Path(table).read_bytes()))
    ayat = kfgqpc_file.read_kfgqpc(text_bytes, profile.ayat)
    metadata = read_tanzil_metadata(metadata_bytes)

    source_checks.check_metadata_version(metadata, config.edition_map.version)
    surahs = _kfgqpc_surahs(profile, ayat, metadata)
    places = source_checks.revelation(metadata)
    ayah_counts = {number: len(group) for number, group in enumerate(surahs, 1)}
    division_rows = source_checks.divisions(profile, metadata, ayah_counts)
    sajda_rows = source_checks.sajdas(metadata, ayah_counts)
    with_basmala = frozenset(range(1, len(surahs) + 1)) - profile.without_basmala
    text = _KfgqpcText(surahs, text_bytes, marks, rules, with_basmala)
    source_checks.check_profile_signs(profile, text.drawn(text.bodies))
    source_checks.check_signed_sajdas(sajda_rows, list(text.stored.items()))
    source_checks.check_font_coverage(font, text.drawn(text.stored))
    if compares:
        _compare_kfgqpc_text(tanzil_text, metadata, metadata_bytes, config.text.file, table, profile)
    surah_rows, expected = text.rows(metadata, places, metadata_bytes)
    return _Source(
        format_version=database.PRESENTED_FORMAT_VERSION,
        surah_rows=surah_rows,
        division_rows=division_rows,
        sajda_rows=sajda_rows,
        sources=[
            _source_entry(config.text, text_bytes, None, None),
            _source_entry(
                config.edition_map,
                metadata_bytes,
                edition_map_options,
                None if metadata.notice is None else metadata.notice.value,
            ),
        ],
        font=font,
        marks=marks,
        presentation=rules,
        expected=expected,
    )


def _check_kfgqpc_description(config):
    """The text source is the published KFGQPC file, of the version kfgqpc.py reads, which has no download options."""
    kfgqpc_file.check_file_name(config.text.file)
    if config.text.version != kfgqpc_file.VERSION:
        raise PackError(
            "sources.text: the KFGQPC file is read as version %s; the description names version %s"
            % (kfgqpc_file.VERSION, _ascii(config.text.version))
        )
    if options_from_url(config.text.url) is not None:
        raise PackError(
            "sources.text: the KFGQPC file is published with no download options; its URL has a query"
        )


def _kfgqpc_font(font_path):
    """The font the KFGQPC text is paired with (D-198 Q2), known by its published file name."""
    font_path = Path(font_path)
    if font_path.name != kfgqpc_file.FONT_FILE_NAME:
        raise PackError(
            "the font of a KFGQPC text is KFGQPC's own %s (D-198 Q2), not %s"
            % (kfgqpc_file.FONT_FILE_NAME, _ascii(font_path.name))
        )
    return read_font(font_path.read_bytes())


def _kfgqpc_surahs(profile, ayat, metadata):
    """The KFGQPC ayat by surah, which the reader gives in mushaf order from
    1:1, checked against the profile and the metadata's counts and starts."""
    surahs = []
    for aya in ayat:
        if aya.number == 1:
            surahs.append([])
        surahs[-1].append(aya)
    if len(surahs) != profile.surahs:
        raise PackError("the KFGQPC file has %d surahs, not %d" % (len(surahs), profile.surahs))
    if len(metadata.suras) != len(surahs):
        raise PackError(
            "the metadata lists %d surahs, the KFGQPC file has %d" % (len(metadata.suras), len(surahs))
        )
    start = 0
    for number, (group, meta) in enumerate(zip(surahs, metadata.suras), 1):
        if meta.ayas != len(group):
            raise PackError(
                "surah %d: the metadata gives %d ayat, the KFGQPC file has %d"
                % (number, meta.ayas, len(group))
            )
        if meta.start != start:
            raise PackError(
                "surah %d: the metadata starts it after %d ayat, the KFGQPC file after %d"
                % (number, meta.start, start)
            )
        start += len(group)
    return surahs


class _KfgqpcText:
    """The KFGQPC ayat by surah with their spans (D-198 Q4), each ayah's text
    without its presentation, the basmala taken from 1:1 (D-198 Q5), and the
    bytes of the file each stored text must read back as."""

    def __init__(self, surahs, data, marks, rules, with_basmala):
        ayat = [aya for group in surahs for aya in group]
        self.surahs = surahs
        self.with_basmala = with_basmala
        self.stored = {}
        self.bodies = {}
        self.spans = {}
        self.source = {}
        for aya, (offset, length) in zip(ayat, kfgqpc_file.text_offsets(data, ayat)):
            address = (aya.surah, aya.number)
            self.spans[address] = presented_spans(aya.text, marks, rules, address, "ayah %d:%d" % address)
            start, end = _body(aya.text, self.spans[address].presentation)
            self.stored[address] = aya.text
            self.bodies[address] = aya.text[start:end]
            self.source[address] = data[offset : offset + length]
            if address == BASMALA_AYAH:
                before = offset + len(aya.text[:start].encode("utf-8"))
                self.basmala = self.bodies[address]
                self.basmala_bytes = data[before : before + len(self.basmala.encode("utf-8"))]

    def drawn(self, texts):
        """(where, text) of every basmala and ayah in mushaf order, each ayah's text from `texts`."""
        for number, group in enumerate(self.surahs, 1):
            if number in self.with_basmala:
                yield "surah %d basmala" % number, self.basmala
            for aya in group:
                address = (aya.surah, aya.number)
                yield "ayah %d:%d" % address, texts[address]

    def rows(self, metadata, places, metadata_bytes):
        """The surah rows to store, and per surah the source bytes they must read back as."""
        rows = []
        expected = []
        for number, (group, meta, (place, order)) in enumerate(zip(self.surahs, metadata.suras, places), 1):
            basmala = self.basmala if number in self.with_basmala else None
            rows.append(
                database.SurahRow(
                    number=number,
                    name=meta.name.value,
                    revelation_place=place,
                    revelation_order=order,
                    basmala=basmala,
                    ayat=[self._ayah_row(aya) for aya in group],
                )
            )
            expected.append(
                (
                    number,
                    _slice(metadata_bytes, meta.name),
                    None if basmala is None else self.basmala_bytes,
                    [(aya.number, self.source[(aya.surah, aya.number)]) for aya in group],
                )
            )
        return rows, expected

    def _ayah_row(self, aya):
        found = self.spans[(aya.surah, aya.number)]
        return database.AyahRow(
            number=aya.number,
            text=aya.text,
            words=found.words,
            marks=found.marks,
            presentation=tuple(found.presentation),
        )


def _body(text, presentation_spans):
    """The code point range of `text` between its presentation spans, which
    are UTF-16 offsets: the ending always, the quarter opening when there are two."""
    offsets = [0]
    for c in text:
        offsets.append(offsets[-1] + (2 if ord(c) > 0xFFFF else 1))
    start = presentation_spans[0][2] if len(presentation_spans) == 2 else 0
    return offsets.index(start), offsets.index(presentation_spans[-1][1])


def _compare_kfgqpc_text(tanzil_text, metadata, metadata_bytes, kfgqpc, table, profile):
    """PRD 9.4 and P2 with the Tanzil text as the witness (D-198 Q1, Q6).
    Even when it passes, the build stops: the KFGQPC text's rights row is
    incomplete (D-198 Q3)."""
    witness_bytes = Path(tanzil_text).read_bytes()
    witness = read_tanzil_text(witness_bytes)
    tanzil_sha256 = {
        "text": digest.sha256_bytes(witness_bytes),
        "metadata": digest.sha256_bytes(metadata_bytes),
    }
    report = compare.run_comparison(witness, metadata, kfgqpc, table, profile, tanzil_sha256)
    if not report["passed"]:
        raise PackError(
            "the comparison of the KFGQPC text with its Tanzil witness fails (%s); "
            "pack.py compare writes the full report" % compare.summary(report)
        )
    raise PackError(
        "the comparison of the KFGQPC text with its Tanzil witness passes (%s; "
        "KFGQPC file %s, table version %d, table SHA-256 %s), but no hafs pack is "
        "built from the KFGQPC text: its rights row is incomplete (D-198 Q3), its "
        "basmala taken from 1:1 waits for the proofreader (D-198 Q5), and format 3 "
        "has no place yet to record the witness and the table"
        % (
            compare.summary(report),
            report["kfgqpc"]["sha256"],
            report["table"]["version"],
            report["table"]["sha256"],
        )
    )


def _compare_with_kfgqpc(text, metadata, kfgqpc, table, profile, tanzil_sha256):
    """PRD 9.4 and P2. Even when it passes, the build stops: manifest format 1
    has no place for the KFGQPC file or the table's version (D-175)."""
    report = compare.run_comparison(text, metadata, kfgqpc, table, profile, tanzil_sha256)
    if not report["passed"]:
        raise PackError(
            "the KFGQPC comparison fails (%s); pack.py compare writes the full report"
            % compare.summary(report)
        )
    raise PackError(
        "the KFGQPC comparison passes (%s; KFGQPC file %s, table version %d, "
        "table SHA-256 %s), but manifest format 1 has no place to record the "
        "KFGQPC file or the table, so no pack is built until the format "
        "records them (D-175)"
        % (
            compare.summary(report),
            report["kfgqpc"]["sha256"],
            report["table"]["version"],
            report["table"]["sha256"],
        )
    )


def _check_test_copy(config, out_root):
    if config.reviews:
        raise PackError(
            "an unapproved test copy has no reviews: a review would present "
            "it as approved (reviews must be empty)"
        )
    tree = git_tree(out_root)
    if tree is not None:
        raise PackError(
            "the output %s is inside a Git working tree; an unapproved test "
            "copy is written outside every repository" % out_root
        )


def _source_bytes(source):
    """The file the description names, refused unless its SHA-256 is the one recorded (PRD 9.3, step 1)."""
    data = source.file.read_bytes()
    found = digest.sha256_bytes(data)
    if found != source.file_sha256:
        raise PackError(
            "sources.%s: the file has SHA-256 %s, the description expects %s"
            % (source.role, found, source.file_sha256)
        )
    return data


def _drawn_texts(text):
    for sura in text.suras:
        basmala = sura.ayat[0].basmala
        if basmala is not None:
            yield "surah %d basmala" % sura.index, basmala.value
        for aya in sura.ayat:
            yield "ayah %d:%d" % (aya.surah, aya.number), aya.text.value


def _surah_rows(text, metadata, places, marks):
    rows = []
    for sura, meta, (place, order) in zip(text.suras, metadata.suras, places):
        ayat = []
        for aya in sura.ayat:
            found = spans(aya.text.value, marks, "ayah %d:%d" % (aya.surah, aya.number))
            ayat.append(
                database.AyahRow(
                    number=aya.number,
                    text=aya.text.value,
                    words=found.words,
                    marks=found.marks,
                )
            )
        basmala = sura.ayat[0].basmala
        rows.append(
            database.SurahRow(
                number=sura.index,
                name=meta.name.value,
                revelation_place=place,
                revelation_order=order,
                basmala=None if basmala is None else basmala.value,
                ayat=ayat,
            )
        )
    return rows


def _tanzil_expected(text, metadata, text_bytes, metadata_bytes):
    expected = []
    for sura, meta in zip(text.suras, metadata.suras):
        basmala = sura.ayat[0].basmala
        expected.append(
            (
                sura.index,
                _slice(metadata_bytes, meta.name),
                None if basmala is None else _slice(text_bytes, basmala),
                [(aya.number, _slice(text_bytes, aya.text)) for aya in sura.ayat],
            )
        )
    return expected


def _slice(data, value):
    return data[value.offset : value.offset + value.length]


def _read_back(text_file, expected):
    """Every stored text equals the source bytes it was taken from; the digests are taken over what was stored."""
    stored = database.read_stored_texts(text_file)

    def check(where, found, source):
        if found != source:
            raise PackError("%s: the stored bytes differ from the source bytes" % where)

    surah_sha256 = {}
    ayat = 0
    for n, name, basmala, sources in expected:
        check("surah %d name" % n, stored.names.get(n), name)
        check("surah %d basmala" % n, stored.basmalas.get(n), basmala)
        fields = [] if basmala is None else [(0, stored.basmalas[n])]
        for number, source in sources:
            address = (n, number)
            check("ayah %d:%d" % address, stored.ayat.get(address), source)
            fields.append((number, stored.ayat[address]))
        ayat += len(sources)
        surah_sha256[str(n)] = digest.surah_digest(fields)
    if len(stored.names) != len(expected) or len(stored.ayat) != ayat:
        raise PackError("the database holds other surahs or ayat than the source")
    return surah_sha256


def _counts(source):
    ayat = [aya for surah in source.surah_rows for aya in surah.ayat]
    counts = {
        "surahs": len(source.surah_rows),
        "ayat": len(ayat),
        "words": sum(len(aya.words) for aya in ayat),
        "marks": sum(len(aya.marks) for aya in ayat),
        "divisions": {
            kind: sum(1 for row in source.division_rows if row[0] == kind)
            for kind in DIVISION_KINDS
        },
        "sajdas": len(source.sajda_rows),
    }
    if source.format_version == database.PRESENTED_FORMAT_VERSION:
        counts["presentations"] = sum(len(aya.presentation) for aya in ayat)
    return counts


def _source_entry(source, data, options, notice):
    return manifest.source_entry(
        role=source.role,
        registry_row=source.registry_row,
        name=source.name,
        publisher=source.publisher,
        url=source.url,
        version=source.version,
        fetched_on=source.fetched_on,
        file_sha256=digest.sha256_bytes(data),
        trust_grade=source.trust_grade,
        options=options,
        licence={
            "text": source.licence["text"],
            "permission_ref": source.licence["permission_ref"],
            "notice": notice,
            "allows_export": source.licence["allows_export"],
        },
    )


def _ascii(value):
    return "".join(c if " " <= c <= "~" else code_point(c) for c in value)
