"""A Zaydi-library book to a verified, unsigned tafsir pack (B0.7, D-184 to D-188).

Order: the description, the output folder, the pinned tafsir font, the P5
counts, the approved honorific table and the reviewer's record are read and
checked before the book; then every input is tied by its hash
(`ziydia_inputs`); the gate chooses the entries (`tafsir_passages`); each
shipped paragraph is found on its page (P3) and converted with its proofs
(`tafsir_html`, P1 and P2); the notes of its footnote marks are paired on
their pages, found there (P3) and converted the same way (`tafsir_footnotes`,
D-189), any footnote case stopping the build; the passages are merged,
ordered and numbered, their notes after their body, and each is rebuilt by
the regular-expression path (P2); every code point is checked against the
font; the database is written in a
temporary folder and read back (P4); the manifest is written; the independent
verifier runs; and only then is the pack moved to `<out>/<id>/<version>/`.
Any failure leaves nothing behind. Signing is a separate step.
"""

from __future__ import annotations

import json
import os
import shutil
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from . import digest
from .ayah_counts import read_ayah_counts
from .database import require_sqlite
from .errors import PackError, code_point
from .font import read_font
from .git_tree import git_tree
from .honorifics import read_honorific_table
from .manifest import build_tafsir_manifest, encode_manifest, source_entry
from .tafsir_config import read_tafsir_config
from .tafsir_database import SURAH_LEVEL, read_tafsir_texts, write_tafsir_database
from .tafsir_footnotes import Case, notes_of_marks, refuse, regex_passage_text, repeated_in_passages
from .tafsir_html import NOTE_OPEN, SEPARATOR, convert_paragraph
from .tafsir_passages import JOIN, assemble, group, select
from .verify_tafsir import verify_tafsir_pack
from .ziydia_inputs import PageParagraphs, read_book_inputs, read_review_record

TAFSIR_FILE = "tafsir.sqlite"
MANIFEST_FILE = "manifest.json"
# assets/fonts/IBMPlexSansArabic-Regular.ttf, version 1.101 (design/README.md):
# the font the passages are drawn with.
TAFSIR_FONT_SHA256 = "6f611412270a132bbac838da9259d4c68569b4175f3b3b8fa3fa36a30b56dab9"
# The two code points D-185 keeps that the tafsir font does not draw.
FONT_EXEMPT = frozenset({0x2009, 0x2063})
ZIYDIA_REGISTRY_ROW = 18  # docs/SOURCES.md, D-187


@dataclass(frozen=True)
class TafsirBuildResult:
    directory: Path
    sqlite_version: str
    counts: dict
    held: list
    tafsir_sha256: str
    manifest_sha256: str
    report: bytes  # the held-out report: numbers, reasons and hashes only


def build_tafsir_pack(config_path, honorifics_path, reviews_path, ayah_counts_path, font_path, out_root):
    sqlite_version = require_sqlite(TAFSIR_FILE)
    config = read_tafsir_config(config_path)
    out_root = Path(out_root)
    tree = git_tree(out_root)
    if tree is not None:
        raise PackError("the output %s is inside the Git working tree %s; a tafsir pack is written outside it" % (out_root, tree))
    destination = out_root / config.pack_id / str(config.version)
    if destination.exists():
        raise PackError("%s exists; a pack version is never rebuilt in place" % destination)
    font = read_font(_read(font_path, "the font"))
    if font.sha256 != TAFSIR_FONT_SHA256:
        raise PackError("the font has SHA-256 %s, not that of the tafsir font %s" % (font.sha256, TAFSIR_FONT_SHA256))
    ayah_counts = read_ayah_counts(_read(ayah_counts_path, "the ayah counts"))
    table = read_honorific_table(_read(honorifics_path, "the honorific table"))
    review = read_review_record(_read(reviews_path, "the review record"))
    inputs = read_book_inputs(
        config.extraction, config.links, config.book, config.pages_sha256, config.passages_sha256, review
    )

    selection = select(inputs.entries, inputs.outcomes, review, ayah_counts)
    on_pages = PageParagraphs(inputs.pages)
    texts, marks, empty, replaced, cases = _convert(selection.chosen, on_pages, table.phrases)
    notes_html, page_cases = notes_of_marks(marks, inputs.pages)
    refuse(config.book, cases + page_cases + repeated_in_passages(group(selection.chosen), marks))
    notes, note_paragraphs, note_empty = _convert_notes(notes_html, on_pages, table.phrases, replaced)
    rows = assemble(selection.chosen, texts, marks, notes)
    _check_passages_by_regex(selection.chosen, rows, inputs.pages, table.phrases)
    _check_font(inputs.facts, rows, font)
    counts = {
        "passages": len(rows),
        "surah_level": sum(1 for row in rows if row.first_ayah == SURAH_LEVEL),
        "entries_shipped": len(selection.chosen),
        "entries_held": len(selection.held),
        "paragraphs": sum(len(t) for t in texts.values()),
        "empty_paragraphs": empty + note_empty,
        "codes_replaced": sum(replaced.values()),
        "footnotes": sum(len(m) for m in marks.values()),
        "note_paragraphs": note_paragraphs,
    }

    out_root.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=".build-", dir=str(out_root)))
    try:
        directory = work / config.pack_id / str(config.version)
        directory.mkdir(parents=True)
        path = directory / TAFSIR_FILE
        write_tafsir_database(path, inputs.facts, rows)
        _read_back(path, inputs.facts, rows)
        tafsir_sha256 = digest.sha256_file(path)
        manifest_bytes = encode_manifest(
            build_tafsir_manifest(
                pack_id=config.pack_id,
                version=config.version,
                changelog=config.changelog,
                riwaya=config.riwaya,
                sources=[_source(config, inputs)],
                tafsir_sha256=tafsir_sha256,
                tafsir_bytes=path.stat().st_size,
                passages=len(rows),
                reviews=config.reviews + _reviews(table, review),
            )
        )
        (directory / MANIFEST_FILE).write_bytes(manifest_bytes)
        report = verify_tafsir_pack(directory, ayah_counts, font=font)
        if report.problems:
            raise PackError("the built pack fails verification: " + "; ".join(report.problems[:20]))
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.rename(str(directory), str(destination))
    finally:
        shutil.rmtree(str(work), ignore_errors=True)
    return TafsirBuildResult(
        directory=destination,
        sqlite_version=sqlite_version,
        counts=counts,
        held=selection.held,
        tafsir_sha256=tafsir_sha256,
        manifest_sha256=digest.sha256_bytes(manifest_bytes),
        report=_report(config, inputs, counts, selection, review),
    )


def _read(path, what):
    try:
        return Path(path).read_bytes()
    except OSError:
        raise PackError("%s cannot be read (%s)" % (what, path)) from None


def _convert(chosen, on_pages, phrases):
    """{n: the texts of its paragraphs, empty ones left out}, {n: its footnote
    marks [(site_page, N)]}, the empty count, the codes replaced, and a case
    for each note or footnote line an entry carries as its own paragraph."""
    texts, marks, empty, replaced, cases = {}, {}, 0, Counter(), []
    for entry in chosen:
        texts[entry.n], marks[entry.n] = [], []
        for index, (site_page, html) in enumerate(entry.paragraphs, 1):
            where = "entry %d paragraph %d (site page %d)" % (entry.n, index, site_page)
            on_pages.take(site_page, html, where)
            if html == SEPARATOR or html.startswith(NOTE_OPEN):
                cases.append(Case("page_layout", site_page, "", (entry.n,)))
                continue
            paragraph = convert_paragraph(html, phrases, where)
            replaced.update(paragraph.replaced)
            marks[entry.n] += [(site_page, number) for number in paragraph.marks]
            if paragraph.text:
                texts[entry.n].append(paragraph.text)
            else:
                empty += 1
    return texts, marks, empty, replaced, cases


def _convert_notes(notes_html, on_pages, phrases, replaced):
    """{(site_page, N): the texts of the note's paragraphs, empty ones left out},
    the paragraphs kept and the empty ones; each note paragraph found on its page (P3)."""
    notes, kept, empty = {}, 0, 0
    for (site_page, number), paragraphs in sorted(notes_html.items()):
        notes[(site_page, number)] = []
        for index, html in enumerate(paragraphs, 1):
            where = "note %d paragraph %d (site page %d)" % (int(number), index, site_page)
            on_pages.take(site_page, html, where)
            paragraph = convert_paragraph(html, phrases, where)
            replaced.update(paragraph.replaced)
            if paragraph.text:
                notes[(site_page, number)].append(paragraph.text)
                kept += 1
            else:
                empty += 1
    return notes, kept, empty


def _check_passages_by_regex(chosen, rows, pages, phrases):
    """P2 for whole passages, notes included."""
    for entries, row in zip(group(chosen), rows):
        paragraphs = [paragraph for e in entries for paragraph in e.paragraphs]
        if JOIN.join(regex_passage_text(paragraphs, pages, phrases)) != row.text:
            raise PackError("passage %d: the text rebuilt from the html by the second path differs (P2)" % row.number)


def _check_font(facts, rows, font):
    places = [("book." + column, getattr(facts, column), FONT_EXEMPT) for column in ("title", "author", "publisher", "edition", "editor")]
    places += [("passage %d" % row.number, row.text, FONT_EXEMPT | {ord(JOIN)}) for row in rows]
    missing = {}
    for where, text, exempt in places:
        for c in text or "":
            if ord(c) not in font.code_points and ord(c) not in exempt:
                missing.setdefault(ord(c), where)
    if missing:
        raise PackError(
            "%d code points are not in the tafsir font: %s"
            % (len(missing), "; ".join("%s first at %s" % (code_point(cp), missing[cp]) for cp in sorted(missing)[:20]))
        )


def _read_back(path, facts, rows):
    """P4: every stored text is the bytes of the text that was written."""
    stored = read_tafsir_texts(path)
    for column, value in stored.book.items():
        expected = getattr(facts, column)
        if value != (None if expected is None else expected.encode("utf-8")):
            raise PackError("book.%s: the stored bytes differ from the text written (P4)" % column)
    if sorted(stored.passages) != [row.number for row in rows]:
        raise PackError("tafsir.sqlite holds other passages than were written (P4)")
    for row in rows:
        if stored.passages[row.number] != row.text.encode("utf-8"):
            raise PackError("passage %d: the stored bytes differ from the text written (P4)" % row.number)


def _source(config, inputs):
    source = config.source
    return source_entry(
        role="tafsir",
        registry_row=ZIYDIA_REGISTRY_ROW,
        name=source["name"],
        publisher=source["publisher"],
        url=inputs.url,
        version=inputs.date_added,
        fetched_on=source["fetched_on"],
        file_sha256=inputs.pages_sha256,
        trust_grade=source["trust_grade"],
        options=None,
        licence={
            "text": source["licence"]["text"],
            "permission_ref": source["licence"]["permission_ref"],
            "notice": None,
            "allows_export": source["licence"]["allows_export"],
        },
    )


def _reviews(table, review):
    """The table, the linking sample and the clearances, bound by their SHA-256 (D-187)."""
    entries = [
        {
            "reviewer": table.approved_by,
            "date": table.approved_on,
            "scope": "honorific table version %d, SHA-256 %s (D-188)" % (table.version, table.sha256),
        },
        {
            "reviewer": review.sample["reviewer"],
            "date": review.sample["date"],
            "scope": "linking sample, sample.html SHA-256 %s, of passages.jsonl SHA-256 %s (D-082, D-186)"
            % (review.sample["sample_sha256"], review.passages_sha256),
        },
    ]
    marks = Counter()
    for name, given in (
        ("cleared", review.cleared),
        ("excluded", review.excluded),
        ("surahs", review.cleared_surah_level),
    ):
        for mark in given.values():
            marks[(mark.reviewer, mark.date, name)] += 1
    for reviewer, date in sorted({(r, d) for r, d, _ in marks}):
        entries.append(
            {
                "reviewer": reviewer,
                "date": date,
                "scope": "review record SHA-256 %s: cleared %d, excluded %d, surah-level entries cleared for %d surahs (D-186)"
                % (
                    review.sha256,
                    marks[(reviewer, date, "cleared")],
                    marks[(reviewer, date, "excluded")],
                    marks[(reviewer, date, "surahs")],
                ),
            }
        )
    return entries


def _report(config, inputs, counts, selection, review):
    report = {
        "book": config.book,
        "pack": {"id": config.pack_id, "version": config.version},
        "passages_sha256": inputs.passages_sha256,
        "counts": counts,
        "held": [{"n": h.n, "site_page": h.site_page, "reason": h.reason} for h in selection.held],
        "held_by_reason": dict(sorted(Counter(h.reason for h in selection.held).items())),
        "never_shipped_by_kind": dict(sorted(selection.never.items())),
        "surah_level": {
            str(surah): {
                "entries": list(level.entries),
                "entries_sha256": level.sha256,
                "cleared_together": surah in review.cleared_surah_level,
            }
            for surah, level in sorted(inputs.surah_level.items())
        },
    }
    return (json.dumps(report, ensure_ascii=True, indent=1, sort_keys=True) + "\n").encode("ascii")
