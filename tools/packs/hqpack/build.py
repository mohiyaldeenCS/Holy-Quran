"""The pipeline: a text source file and its metadata file to a verified, unsigned text pack.

Order (PRD 9.3): hash and read the sources, run every build check, write into
a temporary directory, read every stored text back against the source bytes,
digest the stored bytes, write the manifest, run the independent verifier,
and only then move the pack to `<out>/<id>/<version>/`. Any failure leaves
nothing behind. Signing is a separate step (signing.py, D-080).
"""

from __future__ import annotations

import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from . import database, digest, manifest, source_checks
from .config import read_build_config
from .errors import PackError, code_point
from .font import read_font
from .mark_table import read_mark_table
from .options import option_problems, options_from_url
from .profiles import DIVISION_KINDS, profile_for
from .tanzil_metadata import read_tanzil_metadata
from .tanzil_text import read_tanzil_text
from .tokens import spans
from .verify import verify_pack

TEXT_FILE = "text.sqlite"
MANIFEST_FILE = "manifest.json"
FONT_FAMILY = "Amiri Quran"


@dataclass(frozen=True)
class BuildResult:
    directory: Path
    sqlite_version: str
    counts: dict
    text_sha256: str
    manifest_sha256: str
    surah_sha256: dict


def build_pack(config_path, font_path, out_root):
    sqlite_version = database.require_sqlite()
    config = read_build_config(config_path)
    profile = profile_for(config.riwaya, config.pack_id)
    if profile.needs_kfgqpc_comparison:
        raise PackError(
            "riwaya %s needs the character-by-character comparison with the "
            "KFGQPC text and the page-list comparison (PRD 9.4, "
            "docs/CONTENT_PACKS.md P2); the pipeline does not have them yet "
            "(B0.2), so it builds no %s pack" % (config.riwaya, config.riwaya)
        )
    out_root = Path(out_root)
    destination = out_root / config.pack_id / str(config.version)
    if destination.exists():
        raise PackError("%s exists; a pack version is never rebuilt in place" % destination)

    text_bytes = _source_bytes(config.text)
    metadata_bytes = _source_bytes(config.edition_map)
    marks = read_mark_table(config.mark_table.read_bytes())
    font = read_font(Path(font_path).read_bytes())
    if font.family != FONT_FAMILY:
        raise PackError("the font is %s, not %s" % (_ascii(font.family), FONT_FAMILY))
    text = read_tanzil_text(text_bytes)
    metadata = read_tanzil_metadata(metadata_bytes)

    source_checks.check_notice(text.notice, config.text.version, "text")
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
    text_options = options_from_url(config.text.url)
    problems = option_problems(text_options, drawn)
    if problems:
        raise PackError("the text does not match its options: " + "; ".join(problems))
    source_checks.check_sajda_signs(text_options, sajda_rows, ayat)
    source_checks.check_font_coverage(font, drawn)
    surah_rows = _surah_rows(text, metadata, places, marks)

    out_root.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=".build-", dir=str(out_root)))
    try:
        directory = work / config.pack_id / str(config.version)
        directory.mkdir(parents=True)
        text_file = directory / TEXT_FILE
        database.write_text_database(text_file, surah_rows, division_rows, sajda_rows)
        surah_sha256 = _read_back(text_file, text, metadata, text_bytes, metadata_bytes)
        counts = _counts(surah_rows, division_rows, sajda_rows)
        text_sha256 = digest.sha256_file(text_file)
        manifest_bytes = manifest.encode_manifest(
            manifest.build_manifest(
                pack_id=config.pack_id,
                version=config.version,
                changelog=config.changelog,
                riwaya=config.riwaya,
                edition=config.edition,
                font={"family": font.family, "version": font.version, "sha256": font.sha256},
                sources=[
                    _source_entry(config.text, text_bytes, text_options, text.notice.value),
                    _source_entry(
                        config.edition_map,
                        metadata_bytes,
                        options_from_url(config.edition_map.url),
                        metadata.notice.value,
                    ),
                ],
                text_sha256=text_sha256,
                text_bytes=text_file.stat().st_size,
                surah_sha256=surah_sha256,
                counts=counts,
                reviews=config.reviews,
            )
        )
        (directory / MANIFEST_FILE).write_bytes(manifest_bytes)
        report = verify_pack(directory, mark_code_points=marks, font=font)
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


def _read_back(text_file, text, metadata, text_bytes, metadata_bytes):
    """Every stored text equals its source bytes; the digests are taken over what was stored."""
    stored = database.read_stored_texts(text_file)

    def expect(where, found, value, source):
        if value is None:
            same = found is None
        else:
            same = found == source[value.offset : value.offset + value.length]
        if not same:
            raise PackError("%s: the stored bytes differ from the source bytes" % where)

    surah_sha256 = {}
    for sura, meta in zip(text.suras, metadata.suras):
        n = sura.index
        expect("surah %d name" % n, stored.names.get(n), meta.name, metadata_bytes)
        basmala = sura.ayat[0].basmala
        expect("surah %d basmala" % n, stored.basmalas.get(n), basmala, text_bytes)
        fields = [] if basmala is None else [(0, stored.basmalas[n])]
        for aya in sura.ayat:
            address = (n, aya.number)
            expect("ayah %d:%d" % address, stored.ayat.get(address), aya.text, text_bytes)
            fields.append((aya.number, stored.ayat[address]))
        surah_sha256[str(n)] = digest.surah_digest(fields)
    if len(stored.names) != len(text.suras) or len(stored.ayat) != sum(
        len(sura.ayat) for sura in text.suras
    ):
        raise PackError("the database holds other surahs or ayat than the source")
    return surah_sha256


def _counts(surah_rows, division_rows, sajda_rows):
    ayat = [aya for surah in surah_rows for aya in surah.ayat]
    return {
        "surahs": len(surah_rows),
        "ayat": len(ayat),
        "words": sum(len(aya.words) for aya in ayat),
        "marks": sum(len(aya.marks) for aya in ayat),
        "divisions": {
            kind: sum(1 for row in division_rows if row[0] == kind)
            for kind in DIVISION_KINDS
        },
        "sajdas": len(sajda_rows),
    }


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
