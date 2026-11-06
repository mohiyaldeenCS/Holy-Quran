"""The reciter's review page (D-178) on synthetic sources: no Quran text, mark code points as escapes."""

import dataclasses
import html
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path
from unittest import mock

import synthetic_source as synthetic
from hqpack import compare, kfgqpc, review_html, review_page
from hqpack.errors import PackError
from hqpack.profiles import PROFILES
from hqpack.tanzil_text import read_tanzil_text

from tests.build_support import FONT, OTHER_FONT, synthetic_table_document
from tests.test_font import cmap_table, format12, sfnt, windows_names

SUKUN = "\u0652"
KFGQPC_SUKUN = "\u06e1"
PAUSE = "\u06d6"
# Letter runs that are not words: one with a sukun, one ending in alef maksura.
SUKUN_RUN = "\u0632\u0652\u0637"
MAKSURA_RUN = "\u0637\u0638\u0649"
YEH_RUN = "\u0637\u0638\u064a"
SURAHS = (
    (
        "Synthetic surah one",
        "Synthetic opening line",
        (
            "Synthetic one " + SUKUN_RUN + " \u06d6 end",
            "Synthetic two " + SUKUN_RUN + " \u06d7 end \u06e9",
            "Synthetic three " + SUKUN_RUN + " \u06d6 end",
            "Synthetic four " + MAKSURA_RUN + " \u06d6 end",
        ),
    ),
    (
        "Synthetic surah two",
        None,
        (
            "Synthetic five " + SUKUN_RUN + " \u06d6 end",
            "Synthetic six \u06d6 end",
            "Synthetic seven \u06d6 end \u06e9",
        ),
    ),
    ("Synthetic surah three", "Synthetic opening line", ("Synthetic last \u06d6 end",)),
)
SPACE_REMOVED = ((1, 1), (1, 3), (2, 1), (2, 2), (2, 3), (3, 1))
SUKUN_CHANGED = ((1, 1), (1, 2), (1, 3), (2, 1))
INPUT_KEYS = [
    "tanzil_text_sha256",
    "tanzil_metadata_sha256",
    "kfgqpc_file",
    "kfgqpc_version",
    "kfgqpc_sha256",
    "table_version",
    "table_sha256",
    "tanzil_font_sha256",
    "kfgqpc_font_sha256",
]
DECISION_KEYS = ["format", "version", "reviewer", "saved_at", "inputs", "decisions"]
ITEM_KEYS = {
    "A": ["id", "section", "address", "word", "in_mark", "kfgqpc", "tanzil"],
    "B": ["id", "section", "kfgqpc", "tanzil", "count", "examples"],
    "C": ["id", "section", "kfgqpc", "tanzil", "count", "examples"],
    "D": ["id", "section", "kind", "address", "kfgqpc", "tanzil_metadata"],
}


def synthetic_kfgqpc_font(last=0xFFFF):
    """A font under KFGQPC's file name whose cmap covers U+0020 to `last`."""
    return sfnt(
        [
            (b"cmap", cmap_table([(3, 10, format12([(0x20, last, 1)]))])),
            (b"name", windows_names(id1="Synthetic KFGQPC", id5="Version 1.000; synthetic")),
        ]
    )


def _index(surah, ayah):
    return sum(len(s[2]) for s in SURAHS[: surah - 1]) + ayah - 1


def review_entries():
    """The KFGQPC side: a space before a pause mark removed, a sukun encoded otherwise,
    one pause mark and one letter changed, and one page, juz and quarter difference."""
    entries = synthetic.synthetic_kfgqpc_entries(surahs=SURAHS)

    def change(address, old, new):
        entry = entries[_index(*address)]
        self_check = entry["aya_text"].replace(old, new)
        assert self_check != entry["aya_text"]
        entry["aya_text"] = self_check

    for address in SPACE_REMOVED:
        change(address, " " + PAUSE, PAUSE)
    for address in SUKUN_CHANGED:
        change(address, SUKUN, KFGQPC_SUKUN)
    change((1, 2), "\u06d7", "\u06da")
    change((1, 4), "\u0649", "\u064a")
    change((2, 2), synthetic.KFGQPC_QUARTER_SIGN + synthetic.KFGQPC_NO_BREAK_SPACE, "")
    entries[_index(2, 1)]["page"] = 3
    entries[_index(1, 4)]["jozz"] = 2
    return entries


class _Texts(HTMLParser):
    """Each source text of the page as (source, address, [(in_mark, data), ...])."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.texts = []
        self.current = None
        self.in_mark = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "p" and "data-source" in attrs:
            self.current = (attrs["data-source"], attrs["data-address"], [])
        elif self.current is not None:
            if tag != "mark":
                raise AssertionError("a <%s> inside a source text" % tag)
            self.in_mark = True

    def handle_endtag(self, tag):
        if tag == "mark":
            self.in_mark = False
        elif tag == "p" and self.current is not None:
            self.texts.append(self.current)
            self.current = None

    def handle_data(self, data):
        if self.current is not None:
            self.current[2].append((self.in_mark, data))


class ReviewPageCase(unittest.TestCase):
    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="hqpack review "))
        self.addCleanup(shutil.rmtree, str(self.work), True)
        self.source = self.work / "source"
        self.source.mkdir()
        self.text = self.source / synthetic.TEXT_FILE
        self.text.write_bytes(synthetic.synthetic_text_xml(surahs=SURAHS))
        self.metadata = self.source / synthetic.METADATA_FILE
        self.metadata.write_bytes(synthetic.synthetic_metadata_xml())
        self.table = self.source / "known_differences.json"
        self.table.write_bytes(json.dumps(synthetic_table_document()).encode("ascii"))
        self.kfgqpc_font = self.source / review_page.KFGQPC_FONT_NAME
        self.kfgqpc_font.write_bytes(synthetic_kfgqpc_font())
        self.out = self.work / "review"
        self.entries = review_entries()

    def write(self, entries=None, out=None, tanzil_font=FONT, kfgqpc_font=None):
        kfgqpc = self.source / synthetic.KFGQPC_FILE
        kfgqpc.write_bytes(synthetic.synthetic_kfgqpc_json(self.entries if entries is None else entries))
        return review_page.write_review_page(
            self.text,
            self.metadata,
            kfgqpc,
            self.table,
            tanzil_font,
            self.kfgqpc_font if kfgqpc_font is None else kfgqpc_font,
            self.out if out is None else out,
            PROFILES["synthetic"],
        )

    def page(self, out=None):
        return ((self.out if out is None else out) / review_page.PAGE_FILE).read_text(encoding="utf-8")

    def data(self, page):
        match = re.search(r'<script type="application/json" id="review-data">(.*?)</script>', page, re.S)
        return json.loads(match.group(1))

    def sources(self, entries=None):
        """{("tanzil" or "kfgqpc", "hafs:S:A"): the ayah as its source has it}."""
        text = read_tanzil_text(self.text.read_bytes())
        result = {}
        for sura in text.suras:
            for aya in sura.ayat:
                result[("tanzil", "hafs:%d:%d" % (aya.surah, aya.number))] = aya.text.value
        for entry in self.entries if entries is None else entries:
            result[("kfgqpc", "hafs:%d:%d" % (entry["sura_no"], entry["aya_no"]))] = entry["aya_text"]
        return result

    def assert_reconstitutes(self, page, sources):
        """Every source text on the page, its <mark> removed, is its source text exactly,
        and the mark covers whole tokens."""
        parser = _Texts()
        parser.feed(page)
        parser.close()
        self.assertTrue(parser.texts)
        for source, address, pieces in parser.texts:
            text = "".join(data for _, data in pieces)
            self.assertEqual(text, sources[(source, address)], "%s %s" % (source, address))
            marked = [i for i, (in_mark, _) in enumerate(pieces) if in_mark]
            self.assertEqual(len(marked), 1, "%s %s" % (source, address))
            start = sum(len(data) for _, data in pieces[: marked[0]])
            end = start + len(pieces[marked[0]][1])
            self.assertTrue(start == 0 or text[start - 1] == " ", "%s %s" % (source, address))
            self.assertTrue(end == len(text) or text[end] == " ", "%s %s" % (source, address))
        return parser.texts


class WrittenPageTest(ReviewPageCase):
    def test_the_page_and_the_two_fonts_are_written(self):
        result = self.write()
        self.assertEqual(
            sorted(p.name for p in self.out.iterdir()),
            sorted([review_page.PAGE_FILE, review_page.TANZIL_FONT_FILE, review_page.KFGQPC_FONT_FILE]),
        )
        self.assertEqual((self.out / review_page.TANZIL_FONT_FILE).read_bytes(), FONT.read_bytes())
        self.assertEqual((self.out / review_page.KFGQPC_FONT_FILE).read_bytes(), self.kfgqpc_font.read_bytes())
        self.assertFalse(result.report["passed"])

    def test_the_page_is_self_contained(self):
        self.write()
        page = self.page()
        self.assertNotIn("http", page.lower())
        self.assertNotIn("//", re.sub(r"<script>.*?</script>", "", page, flags=re.S))
        self.assertNotIn("<link", page)
        self.assertNotIn(" src=", page)
        self.assertNotIn("@import", page)
        self.assertNotIn("fetch(", page)
        self.assertNotIn("XMLHttpRequest", page)
        self.assertEqual(
            re.findall(r'url\("([^"]*)"\)', page), [review_page.TANZIL_FONT_FILE, review_page.KFGQPC_FONT_FILE]
        )
        self.assertIn('.text.tanzil { font-family: "HQ Tanzil"; }', page)
        self.assertIn('.text.kfgqpc { font-family: "HQ KFGQPC"; }', page)

    def test_every_marked_word_reconstitutes_its_source(self):
        self.write()
        texts = self.assert_reconstitutes(self.page(), self.sources())
        # Section A: two places, B: three examples, C: five, each shown from both sources.
        self.assertEqual(len(texts), 2 * (2 + 3 + 5))

    def test_each_text_is_in_its_own_font_class(self):
        self.write()
        for source in ("tanzil", "kfgqpc"):
            classes = re.findall(r'<p class="text ([a-z]+)"[^>]*data-source="%s"' % source, self.page())
            self.assertTrue(classes)
            self.assertEqual(set(classes), {source})

    def test_the_differing_word_is_marked(self):
        self.write()
        marks = {}
        parser = _Texts()
        parser.feed(self.page())
        for source, address, pieces in parser.texts:
            marks.setdefault((source, address), set()).update(data for in_mark, data in pieces if in_mark)
        self.assertEqual(marks[("tanzil", "hafs:1:4")], {MAKSURA_RUN})
        self.assertEqual(marks[("kfgqpc", "hafs:1:4")], {YEH_RUN})
        # A pause mark is marked with the word it follows.
        self.assertIn(SUKUN_RUN + " \u06d7", marks[("tanzil", "hafs:1:2")])
        # C: the word and the pause mark, with the space between them in Tanzil only.
        self.assertIn("six " + PAUSE, marks[("tanzil", "hafs:2:2")])
        self.assertIn("six" + PAUSE, marks[("kfgqpc", "hafs:2:2")])

    def test_the_address_and_the_code_points_with_their_names(self):
        self.write()
        page = self.page()
        self.assertIn("Synthetic surah one (\u0661)\u060c \u0622\u064a\u0629 \u0664", page)
        self.assertIn("<li>U+0649 ARABIC LETTER ALEF MAKSURA</li>", page)
        self.assertIn("<li>U+064A ARABIC LETTER YEH</li>", page)
        self.assertIn("<li>U+06DA ARABIC SMALL HIGH JEEM</li>", page)
        self.assertIn("<li>U+0020 SPACE</li>", page)

    def test_the_page_is_deterministic(self):
        self.write()
        other = self.work / "again"
        self.write(out=other)
        self.assertEqual(self.page(), self.page(other))


class EveryDifferenceOnceTest(ReviewPageCase):
    def test_every_difference_appears_in_the_page_once(self):
        result = self.write()
        page = self.page()
        items = self.data(page)["items"]
        by_section = {}
        for item in items:
            by_section.setdefault(item["section"], []).append(item)
        differences = result.report["differences"]
        self.assertEqual(len(differences), 12)
        self.assertEqual(
            len(by_section["A"]) + sum(i["count"] for i in by_section["B"] + by_section["C"]), len(differences)
        )
        ids = [item["id"] for item in items]
        self.assertEqual(len(ids), len(set(ids)))
        for item_id in ids:
            self.assertEqual(page.count('<fieldset class="choice" data-id="%s">' % html.escape(item_id)), 1, item_id)
        self.assertEqual(page.count('<fieldset class="choice"'), len(items))

        self.assertEqual(
            [(i["address"], i["kfgqpc"], i["tanzil"]) for i in by_section["A"]],
            [("hafs:1:2", ["U+06DA"], ["U+06D7"]), ("hafs:1:4", ["U+064A"], ["U+0649"])],
        )
        (b,) = by_section["B"]
        self.assertEqual((b["id"], b["count"]), ("B:U+06E1>U+0652", 4))
        self.assertEqual(b["examples"], ["hafs:1:1", "hafs:1:2", "hafs:1:3"])
        (c,) = by_section["C"]
        self.assertEqual((c["id"], c["kfgqpc"], c["tanzil"], c["count"]), ("C:>U+0020", [], ["U+0020"], 6))
        self.assertEqual(c["examples"], ["hafs:1:1", "hafs:1:3", "hafs:2:1", "hafs:2:2", "hafs:2:3"])
        self.assertEqual(
            [(i["kind"], i["address"], i["kfgqpc"], i["tanzil_metadata"]) for i in by_section["D"]],
            [
                ("page", "hafs:2:1", 3, 2),
                ("juz", "hafs:1:4", 2, 1),
                ("quarter", "hafs:2:2", False, True),
                ("surah_opening_quarter", "hafs:1:1", False, True),
                ("surah_opening_quarter", "hafs:2:1", False, True),
                ("surah_opening_quarter", "hafs:3:1", False, True),
            ],
        )

    def test_a_place_keeps_its_id_when_other_places_join_section_a(self):
        ids = [i["id"] for i in self.data(self.page_written())["items"] if i["section"] == "A"]
        self.assertEqual(ids, ["A:hafs:1:2:3:U+06DA>U+06D7", "A:hafs:1:4:3:U+064A>U+0649"])
        other = self.work / "more-in-a"
        with mock.patch.object(review_page, "RARE_COUNT", 10):
            self.write(out=other)
        moved = [i["id"] for i in self.data(self.page(other))["items"] if i["section"] == "A"]
        self.assertEqual(len(moved), 6)
        self.assertEqual([i for i in moved if i in ids], ids)
        self.assertIn("A:hafs:1:2:3:U+06E1>U+0652", moved)

    def page_written(self):
        self.write()
        return self.page()

    def test_the_places_match_the_report(self):
        result = self.write()
        sections = result.sections
        places = list(sections.a) + [p for card in sections.b + sections.c for p in card.places]
        self.assertEqual(
            sorted((p.address, p.word, p.in_mark) for p in places),
            sorted(
                (tuple(int(x) for x in d["address"].split(":")[1:]), d["word"], d["in_mark"])
                for d in result.report["differences"]
            ),
        )


class DecisionsShapeTest(ReviewPageCase):
    def test_the_data_the_script_reads(self):
        result = self.write()
        data = self.data(self.page())
        self.assertEqual(list(data), ["decisions", "storage_key", "inputs", "items"])
        self.assertEqual(data["decisions"], {"format": "holyquran-kfgqpc-review-decisions", "version": 1})
        self.assertRegex(data["storage_key"], r"^holyquran-kfgqpc-review:[0-9a-f]{16}$")
        self.assertEqual(list(data["inputs"]), INPUT_KEYS)
        self.assertEqual(data["inputs"], dict(result.inputs))
        report = result.report
        self.assertEqual(data["inputs"]["tanzil_text_sha256"], report["tanzil"]["text_sha256"])
        self.assertEqual(data["inputs"]["kfgqpc_sha256"], report["kfgqpc"]["sha256"])
        self.assertEqual(data["inputs"]["table_sha256"], report["table"]["sha256"])
        for item in data["items"]:
            self.assertEqual(list(item), ITEM_KEYS[item["section"]], item["id"])

    def test_the_readme_documents_this_shape(self):
        readme = (Path(__file__).resolve().parents[1] / "README.md").read_text(encoding="utf-8")
        section = readme[readme.index("### The decisions"):]
        example = json.loads(re.search(r"```json\n(.*?)```", section, re.S).group(1))
        self.assertEqual(list(example), DECISION_KEYS)
        self.assertEqual((example["format"], example["version"]), (review_html.DECISIONS_FORMAT, review_html.DECISIONS_VERSION))
        self.assertEqual(list(example["inputs"]), INPUT_KEYS)
        self.assertEqual([d["section"] for d in example["decisions"]], ["A", "B", "C", "D"])
        for decision in example["decisions"]:
            self.assertEqual(list(decision), ITEM_KEYS[decision["section"]] + ["choice", "note"])
            self.assertIn(decision["choice"], review_html.CHOICES)
        for value in review_html.CHOICES:
            self.assertIn("`%s`" % value, section)

    @unittest.skipUnless(shutil.which("node"), "needs node to run the page's script")
    def test_the_decisions_file_the_script_builds(self):
        self.write()
        page = self.page()
        script = re.search(r"<script>\n(.*?)</script>", page, re.S).group(1)
        data = self.data(page)
        first, second = data["items"][0]["id"], data["items"][1]["id"]
        program = script + (
            "\nvar data = %s;\n"
            "var items = {};\n"
            "items[%s] = {choice: 'agrees', note: 'synthetic note'};\n"
            "items[%s] = {choice: 'invented'};\n"
            "process.stdout.write(JSON.stringify(globalThis.decisionsFile(data, items, 'Synthetic reviewer', "
            "'2026-01-01T00:00:00.000Z')));\n"
        ) % (json.dumps(data), json.dumps(first), json.dumps(second))
        run = subprocess.run(["node", "-e", program], capture_output=True, check=True)
        decisions = json.loads(run.stdout.decode("utf-8"))
        self.assertEqual(list(decisions), DECISION_KEYS)
        self.assertEqual(decisions["format"], "holyquran-kfgqpc-review-decisions")
        self.assertEqual(decisions["version"], 1)
        self.assertEqual(decisions["reviewer"], "Synthetic reviewer")
        self.assertEqual(decisions["saved_at"], "2026-01-01T00:00:00.000Z")
        self.assertEqual(decisions["inputs"], data["inputs"])
        self.assertEqual(len(decisions["decisions"]), len(data["items"]))
        for item, decision in zip(data["items"], decisions["decisions"]):
            self.assertEqual(list(decision), ITEM_KEYS[item["section"]] + ["choice", "note"])
            self.assertEqual({k: decision[k] for k in item}, item)
        self.assertEqual(
            [(d["choice"], d["note"]) for d in decisions["decisions"][:3]],
            [("agrees", "synthetic note"), ("unchecked", ""), ("unchecked", "")],
        )


class RefusalTest(ReviewPageCase):
    def assert_refused(self, pattern, out=None, **arguments):
        with self.assertRaisesRegex(PackError, pattern):
            self.write(out=out, **arguments)
        target = self.out if out is None else out
        if target.exists():
            self.assertEqual([p.name for p in target.iterdir() if p.name != ".keep"], [])

    def test_an_output_folder_inside_a_git_tree(self):
        tree = self.work / "repository"
        (tree / ".git").mkdir(parents=True)
        self.assert_refused("inside the Git working tree", out=tree / "deep" / "review")
        self.assertFalse((tree / "deep").exists())
        with self.assertRaisesRegex(PackError, "inside the Git working tree"):
            self.write(out=tree)
        self.assertEqual([p.name for p in tree.iterdir()], [".git"])

    def test_an_output_folder_inside_a_worktree_or_submodule(self):
        tree = self.work / "worktree"
        tree.mkdir()
        (tree / ".git").write_text("gitdir: elsewhere\n", encoding="ascii")
        self.assert_refused("inside the Git working tree", out=tree / "review")

    def test_this_repository(self):
        inside = Path(__file__).resolve().parent / "review-output-never-written"
        self.addCleanup(shutil.rmtree, str(inside), True)
        self.assert_refused("inside the Git working tree", out=inside)
        self.assertFalse(inside.exists())

    def test_a_non_empty_output_folder(self):
        self.out.mkdir()
        (self.out / ".keep").write_bytes(b"")
        self.assert_refused("is not empty")

    def test_an_output_that_is_a_file(self):
        self.out.write_bytes(b"")
        with self.assertRaisesRegex(PackError, "exists and is not a folder"):
            self.write()

    def test_an_output_that_is_a_dangling_link(self):
        os.symlink(str(self.work / "nowhere"), str(self.out))
        with self.assertRaisesRegex(PackError, "is a link to nothing"):
            self.write()
        self.assertFalse((self.work / "nowhere").exists())

    def test_an_output_folder_that_cannot_be_created(self):
        blocker = self.work / "a-file"
        blocker.write_bytes(b"")
        with self.assertRaisesRegex(PackError, "cannot be created"):
            self.write(out=blocker / "review")
        self.assertEqual(blocker.read_bytes(), b"")

    def test_the_output_folder_is_checked_again_before_writing(self):
        render = review_html.render

        def render_while_the_folder_fills(page):
            self.out.mkdir()
            (self.out / ".keep").write_bytes(b"")
            return render(page)

        with mock.patch.object(review_html, "render", render_while_the_folder_fills):
            self.assert_refused("is not empty")

    def test_an_empty_output_folder_is_used(self):
        self.out.mkdir()
        self.write()
        self.assertTrue((self.out / review_page.PAGE_FILE).is_file())

    def test_the_kfgqpc_font_under_another_name(self):
        other = self.source / "other.ttf"
        other.write_bytes(synthetic_kfgqpc_font())
        self.assert_refused("the KFGQPC font is not named uthmanic_hafs_v20.ttf", kfgqpc_font=other)

    def test_a_tanzil_font_other_than_amiri_quran(self):
        self.assert_refused("the Tanzil font is not Amiri Quran", tanzil_font=OTHER_FONT)

    def test_a_font_that_lacks_a_shown_code_point(self):
        self.kfgqpc_font.write_bytes(synthetic_kfgqpc_font(last=0x06FF))
        self.assert_refused(r"the KFGQPC font lacks U\+FC00 \(first in hafs:1:1\), U\+FC01 \(first in hafs:1:2\)")

    def test_a_text_html_would_change(self):
        entries = review_entries()
        entries[_index(1, 4)]["aya_text"] = entries[_index(1, 4)]["aya_text"].replace("four", "fo\rur")
        self.assert_refused(r"the KFGQPC text of hafs:1:4 holds U\+000D", entries=entries)

    def test_a_kfgqpc_file_the_comparison_refuses(self):
        self.assert_refused("the file holds 7 entries, not 8", entries=review_entries()[:-1])


class ReconstitutionMutationTest(ReviewPageCase):
    """The reconstitution checks fail when the slicing drops a code point."""

    @staticmethod
    def dropping_parts(text, start, end):
        return text[:start], text[start:end], text[end + 1:]

    def test_the_writer_refuses_a_mutated_slicing(self):
        with mock.patch.object(review_html, "parts", self.dropping_parts):
            self.assert_refused_page("does not reconstitute its source text")

    def test_the_page_check_catches_it_when_the_writer_does_not(self):
        with mock.patch.object(review_html, "parts", self.dropping_parts), mock.patch.object(
            review_html, "check_parts", lambda pieces, text, where: None
        ):
            self.write()
        with self.assertRaises(AssertionError):
            self.assert_reconstitutes(self.page(), self.sources())

    def assert_refused_page(self, pattern):
        with self.assertRaisesRegex(PackError, pattern):
            self.write()
        self.assertFalse(self.out.exists())


# Markup and references as whole tokens with letters, so that the word count and the marked words do not change.
HOSTILE_BEFORE = "<i>&amp;</p>"
HOSTILE_AFTER = "&lt;/p&gt;</p>&x"
HOSTILE_NAME = "Synthetic <b>surah</b> &amp; one"
HOSTILE_VERSION = "synthetic </script><b>&amp;"


def hostile_ayah(text):
    hostile = text.replace("four ", "four %s " % HOSTILE_BEFORE, 1).replace(" end", " end " + HOSTILE_AFTER, 1)
    assert hostile.count(HOSTILE_BEFORE) == 1 and hostile.count(HOSTILE_AFTER) == 1
    return hostile


def _replace_value(source_value, value):
    return dataclasses.replace(source_value, value=value)


class _Fragment(HTMLParser):
    """The character data of a fragment and the tags in it."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.data = []
        self.tags = []

    def handle_starttag(self, tag, attrs):
        self.tags.append(tag)

    def handle_endtag(self, tag):
        self.tags.append("/" + tag)

    def handle_data(self, data):
        self.data.append(data)


class EscapingTest(ReviewPageCase):
    """`<`, `&` and `</p>` in an ayah of each source, `<` in a surah name and in an input value.

    The Tanzil reader refuses `<` and `&` in a value, so the Tanzil ayah and the surah name are
    set after reading; the page must still show every text exactly."""

    def write_hostile(self):
        read_text = review_page.read_tanzil_text
        read_metadata = review_page.read_tanzil_metadata

        def text_with_hostile_ayah(data):
            text = read_text(data)
            sura = text.suras[0]
            ayat = list(sura.ayat)
            ayat[3] = dataclasses.replace(ayat[3], text=_replace_value(ayat[3].text, hostile_ayah(ayat[3].text.value)))
            return dataclasses.replace(text, suras=[dataclasses.replace(sura, ayat=ayat)] + list(text.suras[1:]))

        def metadata_with_hostile_name(data):
            metadata = read_metadata(data)
            first = dataclasses.replace(metadata.suras[0], name=_replace_value(metadata.suras[0].name, HOSTILE_NAME))
            return dataclasses.replace(metadata, suras=[first] + list(metadata.suras[1:]))

        entries = review_entries()
        entries[_index(1, 4)]["aya_text"] = hostile_ayah(entries[_index(1, 4)]["aya_text"])
        with mock.patch.object(review_page, "read_tanzil_text", text_with_hostile_ayah), mock.patch.object(
            review_page, "read_tanzil_metadata", metadata_with_hostile_name
        ), mock.patch.object(kfgqpc, "VERSION", HOSTILE_VERSION):
            result = self.write(entries=entries)
        sources = self.sources(entries)
        sources[("tanzil", "hafs:1:4")] = hostile_ayah(sources[("tanzil", "hafs:1:4")])
        return result, self.page(), sources

    def test_both_texts_parse_back_exactly(self):
        result, page, sources = self.write_hostile()
        self.assertEqual(len(result.report["differences"]), 12)
        texts = self.assert_reconstitutes(page, sources)
        shown = {(source, address) for source, address, _ in texts}
        self.assertIn(("tanzil", "hafs:1:4"), shown)
        self.assertIn(("kfgqpc", "hafs:1:4"), shown)

    def test_the_surah_name_is_escaped(self):
        _, page, _ = self.write_hostile()
        self.assertIn(html.escape(HOSTILE_NAME, quote=False) + " (\u0661)", page)
        self.assertNotIn(HOSTILE_NAME, page)

    def test_the_input_values_parse_back_exactly(self):
        result, page, _ = self.write_hostile()
        fragment = _Fragment()
        fragment.feed(re.search(r'<div class="inputs">(.*?)</div>', page, re.S).group(1))
        fragment.close()
        self.assertEqual(set(fragment.tags), {"br"})
        self.assertEqual(
            "".join(fragment.data).split("\n"), ["%s: %s" % item for item in result.inputs.items()]
        )
        self.assertEqual(result.inputs["kfgqpc_version"], HOSTILE_VERSION)

    def test_the_script_data_parses_back_exactly(self):
        result, page, _ = self.write_hostile()
        self.assertEqual(page.count("</script>"), 2)
        self.assertEqual(self.data(page)["inputs"], dict(result.inputs))


class ScriptJsonTest(unittest.TestCase):
    def test_nothing_in_it_can_close_the_script_element(self):
        value = ["</script>", "<!--", "</SCRIPT >"]
        encoded = review_html._script_json(value)
        self.assertNotIn("</", encoded)
        self.assertNotIn("<", encoded)
        self.assertEqual(json.loads(encoded), value)


@unittest.skipUnless(shutil.which("node"), "needs node to run the page's script")
class PageScriptTest(ReviewPageCase):
    def run_script(self, statements):
        self.write()
        page = self.page()
        script = re.search(r"<script>\n(.*?)</script>", page, re.S).group(1)
        program = script + "\nvar data = %s;\n%s\n" % (json.dumps(self.data(page)), statements)
        run = subprocess.run(["node", "-e", program], capture_output=True, check=True)
        return json.loads(run.stdout.decode("utf-8"))

    def test_the_counter_counts_what_the_decisions_file_saves(self):
        result = self.run_script(
            "var ids = data.items.map(function (item) { return item.id; });\n"
            "var items = {};\n"
            "items[ids[0]] = {choice: 'agrees'};\n"
            "items[ids[1]] = {choice: 'invented'};\n"
            "items[ids[2]] = {choice: 'disagrees'};\n"
            "items[ids[3]] = {choice: 'unchecked'};\n"
            "items[ids[4]] = {choice: 'toString'};\n"
            "items['not-an-item'] = {choice: 'agrees'};\n"
            "var file = globalThis.decisionsFile(data, items, 'Synthetic reviewer', '2026-01-01T00:00:00.000Z');\n"
            "process.stdout.write(JSON.stringify([globalThis.checkedCount(data, items), file.decisions.filter("
            "function (d) { return d.choice !== 'unchecked'; }).length]));"
        )
        self.assertEqual(result, [2, 2])

    def test_saved_state_of_another_shape_is_refused(self):
        cases = [
            None,
            '{"reviewer":"Synthetic reviewer","items":{"x":{"choice":"agrees","note":""}}}',
            '{"reviewer":"Synthetic reviewer","items":[]}',
            '{"reviewer":"Synthetic reviewer","items":[{"choice":"agrees"}]}',
            '{"reviewer":"Synthetic reviewer","items":null}',
            '{"reviewer":"Synthetic reviewer","items":"synthetic"}',
            '{"reviewer":"Synthetic reviewer"}',
            '{"reviewer":7,"items":{}}',
            "[]",
            "null",
            "not json",
        ]
        result = self.run_script(
            "process.stdout.write(JSON.stringify(%s.map(globalThis.loadState)));" % json.dumps(cases)
        )
        self.assertEqual(
            result,
            [
                {"reviewer": "", "items": {}},
                {"reviewer": "Synthetic reviewer", "items": {"x": {"choice": "agrees", "note": ""}}},
            ]
            + [None] * (len(cases) - 2),
        )

    def test_a_refused_state_shows_the_storage_warning(self):
        self.write()
        script = re.search(r"<script>\n(.*?)</script>", self.page(), re.S).group(1)
        self.assertRegex(
            script,
            r'if \(state === null\) \{\n\s*state = \{ reviewer: "", items: \{\} \};\n'
            r'\s*document\.getElementById\("storage-warning"\)\.hidden = false;',
        )


def _place(kfgqpc_sequence, tanzil_sequence, address=(1, 1), kfgqpc_text="", tanzil_text="", kfgqpc=(0, 0), tanzil=(0, 0)):
    return compare.Place(
        address=address,
        word=1,
        in_mark=False,
        kfgqpc=kfgqpc,
        tanzil=tanzil,
        kfgqpc_sequence=kfgqpc_sequence,
        tanzil_sequence=tanzil_sequence,
        kfgqpc_text=kfgqpc_text,
        tanzil_text=tanzil_text,
    )


class ClassifyTest(unittest.TestCase):
    def test_a_space_before_a_pause_mark_in_either_source(self):
        tanzil_side = _place("", " ", tanzil_text="ab " + PAUSE, tanzil=(2, 3))
        kfgqpc_side = _place(" ", "", kfgqpc_text="ab " + PAUSE, kfgqpc=(2, 3))
        elsewhere = _place("", " ", tanzil_text="ab cd", tanzil=(2, 3))
        at_the_end = _place("", " ", tanzil_text="ab ", tanzil=(2, 3))
        self.assertTrue(review_page.is_space_before_pause_mark(tanzil_side))
        self.assertTrue(review_page.is_space_before_pause_mark(kfgqpc_side))
        self.assertFalse(review_page.is_space_before_pause_mark(elsewhere))
        self.assertFalse(review_page.is_space_before_pause_mark(at_the_end))
        sections = review_page.classify([tanzil_side, kfgqpc_side, elsewhere])
        self.assertEqual(sections.a, (elsewhere,))
        self.assertEqual([(c.kfgqpc, c.tanzil, len(c.places)) for c in sections.c], [("", " ", 1), (" ", "", 1)])

    def test_a_pause_mark_pattern_stays_in_a_however_often_it_occurs(self):
        places = [_place("\u06da", "\u06d7", address=(1, n)) for n in range(1, 10)]
        sections = review_page.classify(places)
        self.assertEqual(sections.a, tuple(places))
        self.assertEqual(sections.b, ())

    def test_a_pattern_seen_at_most_rare_count_times_is_in_a(self):
        rare = [_place("x", "y", address=(1, n)) for n in range(1, review_page.RARE_COUNT + 1)]
        common = [_place("p", "q", address=(2, n)) for n in range(1, review_page.RARE_COUNT + 2)]
        sections = review_page.classify(common[:2] + rare + common[2:])
        self.assertEqual(sections.a, tuple(rare))
        self.assertEqual([(c.kfgqpc, len(c.places)) for c in sections.b], [("p", review_page.RARE_COUNT + 1)])

    def test_cards_are_sorted_by_count_then_code_points(self):
        places = [_place("b", "c", address=(1, n)) for n in range(1, 5)]
        places += [_place("a", "c", address=(2, n)) for n in range(1, 5)]
        places += [_place("z", "c", address=(3, n)) for n in range(1, 6)]
        self.assertEqual([c.kfgqpc for c in review_page.classify(places).b], ["z", "a", "b"])


class MarkedSpanTest(unittest.TestCase):
    def test_inside_a_word(self):
        self.assertEqual(review_html.marked_span("ab cde fg", 4, 5), (3, 6))

    def test_an_insertion_at_a_word_end(self):
        self.assertEqual(review_html.marked_span("ab cde fg", 6, 6), (3, 6))

    def test_a_space_between_a_word_and_a_mark(self):
        text = "ab cd " + PAUSE + " fg"
        self.assertEqual(review_html.marked_span(text, 5, 6), (3, 7))

    def test_a_mark_is_marked_from_the_word_before_it(self):
        text = "ab cd " + PAUSE + " fg"
        self.assertEqual(review_html.marked_span(text, 6, 7), (3, 7))

    def test_before_the_first_word(self):
        self.assertEqual(review_html.marked_span(" ab", 0, 1), (0, 3))
        self.assertEqual(review_html.marked_span(PAUSE + " ab", 0, 1), (0, 1))

    def test_a_no_break_space_is_part_of_a_token(self):
        text = "ab cd\u00a0\ufc00"
        self.assertEqual(review_html.marked_span(text, 5, 7), (3, 7))

    def test_the_parts_join_to_the_text(self):
        text = "ab cd " + PAUSE + " fg"
        for start in range(len(text) + 1):
            for end in range(start, len(text) + 1):
                low, high = review_html.marked_span(text, start, end)
                self.assertLessEqual(low, start)
                self.assertGreaterEqual(high, end)
                self.assertEqual("".join(review_html.parts(text, low, high)), text)


if __name__ == "__main__":
    unittest.main()
