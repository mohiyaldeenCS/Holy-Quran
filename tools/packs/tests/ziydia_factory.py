"""A synthetic Zaydi-library book: the extraction, the linker's output, the
honorific table, the reviewer's record, the P5 counts and a tafsir
description, all tied by their hashes as the real ones are.

Written from docs/content/ZIYDIA_LIBRARY.md and tools/ziydia/README.md with
json and hashlib only; it imports neither tool. Every text is plainly
synthetic: Latin words and a synthetic Arabic-script phrase from escapes,
never Quran or book text.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from hqpack import kfgqpc
from hqpack.kfgqpc_counts import encode_counts

BOOK = 183
P = '<p style="margin-top:1px;margin-bottom:1px">'
BOLD = '<span style="font-family:Ziydia-Bold">'
QUOTE = '<span style="color: #00AA00;font-family: Ziydia-Q;">'
SMALL = '<span style="font-size: 0.8em;">'
RED = '<span style="color: #be0000;">'
CODE = '<span style="color: #800000;">'
END = "</span>"

PHRASE = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"  # a synthetic phrase
HONORIFIC = "\u0639\u0628\u0627\u0631\u0629 \u062a\u062c\u0631\u064a\u0628\u064a\u0629"  # a synthetic phrase
SENTINEL = "SENTINEL-NEVER-SHIPPED"
AYAH_COUNTS = {1: 4, 2: 3, 3: 1}
# The book card's labels (ziydia_fetch.py parse_book).
TITLE_LABEL = "\u0627\u0644\u0643\u062a\u0627\u0628"
PUBLISHER = "\u0627\u0644\u0646\u0627\u0634\u0631"
EDITION = "\u0627\u0644\u0637\u0628\u0639\u0629"


def para(body: str) -> str:
    return P + body + "</p>"


def code(c: str) -> str:
    return CODE + c + END


def entry(kind, surah, refs, *paragraphs, review=None, outcome=None):
    """`paragraphs` are (site_page, html); `outcome` is compare's, for kind passage."""
    return {
        "kind": kind,
        "surah": surah,
        "refs": refs,
        "paragraphs": list(paragraphs),
        "review": review,
        "outcome": outcome,
    }


# In book order. Shipped as four passages: surah 1's surah-level text (2,
# cleared with its surah by `Book.cleared_surah_level`), 1:1-3 (3 and 4
# merged), 2:2-3 (7) and 3:1 (10). Held: 5 (not found) and 6 (flagged). Never
# shipped: 1, 8 and 9.
ENTRIES = (
    entry("heading", 1, [], (10, para("Synthetic heading one"))),
    entry("unlinked", 1, [], (10, para("Synthetic surah-level opening " + PHRASE))),
    entry("passage", 1, [[1, 2]], (10, para("&nbsp&nbsp" + BOLD + "Synthetic lead:" + END + " first part")), outcome="same"),
    entry(
        "passage", 1, [[2, 3]],
        (11, para("Synthetic " + QUOTE + "quoted words" + END + "\u2063" + SMALL + "[3]" + END + " second part")),
        outcome="same_but_for_spelling",
    ),
    entry("passage", 1, [[4, 4]], (11, para("Synthetic not found")), outcome="not_found"),
    entry("passage", 2, [[1, 1]], (11, para("Synthetic flagged")), review=["range_is_not_valid"], outcome="same"),
    entry(
        "passage", 2, [[2, 2], [3, 3]],
        (12, para(RED + "(2)" + END + "  Synthetic   name " + code("\u00f7") + " and " + code("&") + " end \ufdfa " + code("...") + " &nbsp")),
        outcome="same",
    ),
    entry("text", 2, [[1, 3]], (12, para(SENTINEL))),
    entry("unlinked", None, [], (12, para("Synthetic unlinked"))),
    entry("passage", 3, [[1, 1]], (12, para("Synthetic last")), (12, para("&nbsp")), outcome="same"),
)

# tools/ziydia/README.md: report.json lists every kind a line can have.
ENTRY_KINDS = ["passage", "unlinked", "heading", "text", "title_page", "ornament", "footnote", "above_the_rule"]

TABLE = {
    "version": 1,
    "approved_by": "Synthetic approver",
    "approved_on": "2026-01-02",
    "derived_from_font_sha256": "a" * 64,
    "codes": [{"code": "U+00F7", "phrase": HONORIFIC}, {"code": "U+0026", "phrase": "Synthetic honorific"}],
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def dumps(value) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=1, sort_keys=True) + "\n").encode("utf-8")


class Book:
    """The files of one synthetic book under `root`. Change `entries`, the
    other attributes or a file, then call `write()` again to re-tie hashes."""

    def __init__(self, root, entries=ENTRIES, book=BOOK):
        self.root = Path(root)
        self.book = book
        self.entries = [dict(e) for e in entries]
        self.extra_paragraphs = {}  # site page -> page paragraphs no entry carries
        self.meta = {
            "id": book,
            "url": "https://ziydia.com/book/%d" % book,
            "title": "Synthetic book " + PHRASE,
            "author": "Synthetic author",
            "category": "synthetic",
            "date_added": "2020-01-02",
            "card": [
                {"label": TITLE_LABEL, "value": "Synthetic book"},
                {"label": PUBLISHER, "value": "Synthetic publisher"},
                {"label": EDITION, "value": "Synthetic edition 1"},
            ],
        }
        self.state = {"done": True, "pages": 3}
        self.table = json.loads(json.dumps(TABLE))
        self.cleared = []
        self.excluded = []
        self.cleared_surah_level = [1]  # surahs whose surah-level entries the record clears together
        self.profile = "bracket_numbers"
        self.out = self.root / "out"

    @property
    def extraction(self):
        return self.root / "extraction" / ("book_%d" % self.book)

    @property
    def links(self):
        return self.root / "links" / ("book_%d" % self.book)

    def write(self):
        self.extraction.mkdir(parents=True, exist_ok=True)
        self.links.mkdir(parents=True, exist_ok=True)
        (self.extraction / "meta.json").write_bytes(dumps(self.meta))
        (self.extraction / "state.json").write_bytes(dumps(self.state))
        pages = self.pages_bytes()
        (self.extraction / "pages.jsonl").write_bytes(pages)
        passages = self.passages_bytes()
        (self.links / "passages.jsonl").write_bytes(passages)
        report = {
            "book": self.book,
            "profile": self.profile,
            "entry_kinds": ENTRY_KINDS,
            "input": {"pages_sha256": sha256(pages), "surahs_table_sha256": None},
            "counts": {},
            "checks": {},
            "notes_by_kind": {},
            "notes": [],
            "surahs": {},
            "passages_sha256": sha256(passages),
        }
        (self.links / "report.json").write_bytes(dumps(report))
        compare = {
            "book": self.book,
            "passages_sha256": sha256(passages),
            "text_from_book": 514,
            "text_passages_sha256": "b" * 64,
            "counts": {},
            "not_confirmed": [],
            "outcomes": {
                str(n): e["outcome"] for n, e in enumerate(self.entries, 1) if e["kind"] == "passage"
            },
        }
        compare_bytes = dumps(compare)
        (self.links / "compare.json").write_bytes(compare_bytes)
        sample = b"<!doctype html><title>synthetic sample</title>\n"
        (self.links / "sample.html").write_bytes(sample)
        self.write_file("table.json", dumps(self.table))
        record = {
            "book": self.book,
            "passages_sha256": sha256(passages),
            "compare_sha256": sha256(compare_bytes),
            "sample": {"reviewer": "Synthetic reviewer", "date": "2026-01-03", "sample_sha256": sha256(sample)},
            "cleared": [{"n": n, "reviewer": "Synthetic reviewer", "date": "2026-01-03"} for n in self.cleared],
            "excluded": [{"n": n, "reviewer": "Synthetic reviewer", "date": "2026-01-04"} for n in self.excluded],
            "cleared_surah_level": [
                {
                    "surah": surah,
                    "entries_sha256": self.surah_level_sha256(passages, surah),
                    "reviewer": "Synthetic reviewer",
                    "date": "2026-01-05",
                }
                for surah in self.cleared_surah_level
            ],
        }
        self.write_file("review.json", (json.dumps(record, indent=1, sort_keys=True) + "\n").encode("ascii"))
        self.write_file("counts.json", counts_bytes())
        self.write_file("tafsir.json", dumps(self.description(pages, passages)))
        return self

    def surah_level_sha256(self, passages: bytes, surah: int) -> str:
        """The hash of the surah's lines of kind unlinked in passages.jsonl, each with its line break."""
        lines = [line + b"\n" for line in passages.split(b"\n")[:-1]]
        return sha256(b"".join(line for e, line in zip(self.entries, lines) if e["kind"] == "unlinked" and e["surah"] == surah))

    def write_file(self, name, data):
        (self.root / name).write_bytes(data)

    def path(self, name):
        return self.root / name

    def description(self, pages, passages):
        return {
            "id": "synthetic-tafsir-%d" % self.book,
            "version": 1,
            "changelog": [{"version": 1, "date": "2026-01-04", "summary": "Synthetic"}],
            "riwaya": "hafs",
            "book": self.book,
            "extraction": "extraction",
            "links": "links",
            "pages_sha256": sha256(pages),
            "passages_sha256": sha256(passages),
            "source": {
                "name": "Synthetic library",
                "publisher": "Synthetic publisher",
                "fetched_on": "2026-01-05",
                "trust_grade": "B",
                "licence": {"text": None, "permission_ref": "Synthetic permission", "allows_export": True},
            },
            "reviews": [],
        }

    def pages_bytes(self) -> bytes:
        by_page = {}
        for e in self.entries:
            for site_page, html in e["paragraphs"]:
                by_page.setdefault(site_page, []).append(html)
        for site_page, extra in self.extra_paragraphs.items():
            by_page.setdefault(site_page, []).extend(extra)
        lines = []
        for seq, site_page in enumerate(sorted(by_page), 1):
            page = {
                "book": self.book,
                "seq": seq,
                "part": 1,
                "url_page": str(site_page),
                "page_label": "synthetic %d" % site_page,
                "chapter": "",
                "url": "https://ziydia.com/book/%d/page/%d/1" % (self.book, site_page),
                "html": "\n".join(by_page[site_page]),
                "text": "synthetic",
            }
            lines.append(json.dumps(page, ensure_ascii=False) + "\r\n")
        return "".join(lines).encode("utf-8")

    def passages_bytes(self) -> bytes:
        lines = []
        for n, e in enumerate(self.entries, 1):
            line = {
                "n": n,
                "book": self.book,
                "kind": e["kind"],
                "surah": e["surah"],
                "refs": e["refs"],
                "basis": "none",
                "paragraphs": [
                    {"site_page": site_page, "part": 1, "printed_page": site_page, "html": html}
                    for site_page, html in e["paragraphs"]
                ],
            }
            if e["review"] is not None:
                line["review"] = e["review"]
            lines.append(json.dumps(line, ensure_ascii=False, sort_keys=True) + "\n")
        return "".join(lines).encode("utf-8")

    def args(self, **replace):
        """The `tafsir` command's options, each replaceable."""
        values = {
            "--config": self.path("tafsir.json"),
            "--honorifics": self.path("table.json"),
            "--reviews": self.path("review.json"),
            "--ayah-counts": self.path("counts.json"),
            "--font": FONT,
            "--out": self.out,
        }
        values.update({"--" + k.replace("_", "-"): v for k, v in replace.items()})
        return [str(a) for item in values.items() if item[1] is not None for a in item]


def counts_bytes(counts=AYAH_COUNTS) -> bytes:
    return encode_counts(
        {
            "kfgqpc_file": {
                "registry_row": kfgqpc.REGISTRY_ROW,
                "name": kfgqpc.FILE_NAME,
                "version": kfgqpc.VERSION,
                "sha256": "0" * 64,
            },
            "date": "2026-11-06",
            "surahs": {str(s): c for s, c in counts.items()},
            "total": sum(counts.values()),
        }
    )


FONT = Path(__file__).resolve().parents[3] / "assets" / "fonts" / "IBMPlexSansArabic-Regular.ttf"
