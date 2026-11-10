"""D-185: the closed conversion of a paragraph's html, its refusals and its proofs, on synthetic paragraphs."""

from __future__ import annotations

import unittest
from unittest import mock

from hqpack import tafsir_html as th
from hqpack.errors import PackError
from tests.ziydia_factory import BOLD, CODE, END, HONORIFIC, PHRASE, QUOTE, RED, SMALL, code, para

PHRASES = {"\u00f7": HONORIFIC, "&": "Synthetic honorific"}


def convert(html, phrases=PHRASES):
    return th.convert_paragraph(html, phrases, "synthetic paragraph").text


class ConversionTest(unittest.TestCase):
    def test_every_allowed_tag_is_dropped_and_its_content_kept(self):
        for tag in th.SPANS:
            with self.subTest(tag=tag):
                self.assertEqual(convert(para("Synthetic " + tag + "inner" + END + " tail")), "Synthetic inner tail")
        self.assertEqual(convert(para(BOLD + QUOTE + "nested" + END + END)), "nested")
        self.assertEqual(convert(para("Synthetic " + PHRASE)), "Synthetic " + PHRASE)

    def test_a_table_code_becomes_its_phrase_unchanged(self):
        self.assertEqual(convert(para("Synthetic " + code("\u00f7") + " tail")), "Synthetic " + HONORIFIC + " tail")
        self.assertEqual(convert(para("Synthetic " + code("&"))), "Synthetic Synthetic honorific")
        paragraph = th.convert_paragraph(para(code("&") + " " + code("&")), PHRASES, "p")
        self.assertEqual(paragraph.replaced, {"&": 2})

    def test_an_unknown_code_is_named(self):
        with self.assertRaisesRegex(PackError, r"the code U\+00D7 at offset \d+ is not in the honorific table"):
            convert(para("Synthetic " + code("\u00d7")))

    def test_kept_codes_and_characters_stay_as_they_are(self):
        for kept in ("\ufdfa", "\ufdfb", "\ufdfd", "\u00b7", ".", "....."):
            with self.subTest(kept=kept):
                self.assertEqual(convert(para("Synthetic " + code(kept) + " tail")), "Synthetic " + kept + " tail")
        decomposed = "Synthetic e\u0301 \u00e9 \u2063[1] \u2009 \u00a0 \u0640"
        self.assertEqual(convert(para(decomposed)), decomposed)

    def test_white_space_runs_collapse_and_the_edges_are_trimmed(self):
        self.assertEqual(convert(para(" \t Synthetic \n\r  words\f\v ")), "Synthetic words")
        self.assertEqual(convert(para("&nbsp&nbsp &nbsp" + RED + "[1]" + END + " Synthetic &nbsp")), "[1] Synthetic")
        self.assertEqual(convert(para("&nbsp \u00a0Synthetic\u00a0 ")), "\u00a0Synthetic\u00a0")

    def test_an_empty_paragraph_converts_to_nothing(self):
        for html in (para(""), para("&nbsp&nbsp"), para("  " + BOLD + " " + END)):
            with self.subTest(html=html):
                self.assertEqual(convert(html), "")

    def test_refusals(self):
        cases = (
            (para("Synthetic \ufffd"), "holds U+FFFD at offset"),
            (para("\ufeffSynthetic"), "holds U+FEFF at offset"),
            ('<p class="border-r-4 px-2">Synthetic</p>', "unknown markup <p> at offset 0"),
            (para('<span style="color: red;">x</span>'), "unknown markup <span>"),
            (para("<b>x</b>"), "unknown markup <b>"),
            (para("<div>x</div>"), "unknown markup <div>"),
            (para('x<sup style="color: #800000;">(\u20631)</sup>'), "<sup> at offset 45 belongs to a footnote"),
            (para("<hr>"), "<hr> at offset 44 belongs to a footnote"),
            (para("a < b"), "a stray < at offset"),
            (para("a > b"), "a stray > at offset"),
            (para("a & b"), "a stray & or an entity other than &nbsp"),
            (para("a &amp; b"), "a stray & or an entity other than &nbsp"),
            (para("&nbsp;Synthetic"), "&nbsp; at offset 44 is not the site's &nbsp"),
            (para("Synthetic&nbspwords"), "&nbsp inside the paragraph, not at an edge"),
            (th.P_OPEN + BOLD + "unclosed", "2 tags are not closed"),
            (para("x" + END), "</span> at offset 45 has no <span>"),
            (para(BOLD + "x</p>" + END), "</p> at offset 83 closes a <span>"),
            (para("x") + para("y"), "something follows </p>"),
            ("Synthetic" + para("x"), "text before the paragraph's <p>"),
            (para("x") + " ", "something follows </p>"),
            ("", "the html is empty"),
            (para(CODE + "\u00f7"), "the code span at offset 44 is not closed"),
            (para(code("\u00f7\u00f7")), "holds 2 characters, not a code"),
            (para(code("")), "holds 0 characters, not a code"),
            (para(code("<b>")), "holds 3 characters, not a code"),
            (para("Synthetic \u00f7 outside"), "the code U+00F7 stands outside its span"),
            (para("Synthetic" + code("\u00f7")), "the code U+00F7 touches a letter"),
            (para(code("\u00f7") + BOLD + "word" + END), "the code U+00F7 touches a letter"),
            (para("\u0646" + code("&")), "the code U+0026 touches a letter"),
        )
        for html, expected in cases:
            with self.subTest(expected=expected):
                with self.assertRaises(PackError) as caught:
                    convert(html)
                self.assertIn(expected, str(caught.exception))
                self.assertTrue(str(caught.exception).isascii())
                self.assertNotIn("Synthetic", str(caught.exception))

    def test_a_dot_run_may_touch_a_letter_as_printed(self):
        self.assertEqual(convert(para("Synthetic" + code("..."))), "Synthetic...")


class ProofTest(unittest.TestCase):
    HTML = para("&nbsp" + BOLD + "Synthetic:" + END + " words " + code("\u00f7") + " " + SMALL + "[2]" + END + " end")

    def test_both_proofs_pass_on_the_converter(self):
        pieces = th.tokenize(self.HTML, PHRASES, "p")
        th.check_rejoins(self.HTML, pieces, PHRASES, "p")
        text = th.assemble(pieces, "p")
        th.check_regex_agrees(self.HTML, PHRASES, text, "p")
        self.assertEqual(text, "Synthetic: words " + HONORIFIC + " [2] end")
        self.assertEqual("".join(p.source for p in pieces), self.HTML)

    def _mutated(self, change):
        original = th._text_run

        def mutated(html, at):
            end, piece = original(html, at)
            if len(piece.source) > 3:
                source = change(piece.source)
                piece = th.Piece("text", source, source)
            return end, piece

        return mock.patch.object(th, "_text_run", mutated)

    def _assert_both_proofs_fail(self, change):
        with self._mutated(change):
            pieces = th.tokenize(self.HTML, PHRASES, "p")
            with self.assertRaisesRegex(PackError, r"\(P1\)"):
                th.check_rejoins(self.HTML, pieces, PHRASES, "p")
            text = th.assemble(pieces, "p")
            with self.assertRaisesRegex(PackError, r"\(P2\)"):
                th.check_regex_agrees(self.HTML, PHRASES, text, "p")
            with self.assertRaisesRegex(PackError, r"\(P1\)"):
                th.convert_paragraph(self.HTML, PHRASES, "p")

    def test_a_converter_that_drops_one_character_fails_both_proofs(self):
        self._assert_both_proofs_fail(lambda s: s[:2] + s[3:])

    def test_a_converter_that_changes_one_character_fails_both_proofs(self):
        self._assert_both_proofs_fail(lambda s: s[:2] + ("x" if s[2] != "x" else "y") + s[3:])

    def test_an_assembly_that_drops_one_character_is_caught_by_p2(self):
        original = th.assemble
        with mock.patch.object(th, "assemble", lambda pieces, where: original(pieces, where)[:-1]):
            th.check_rejoins(self.HTML, th.tokenize(self.HTML, PHRASES, "p"), PHRASES, "p")
            with self.assertRaisesRegex(PackError, r"p: the two conversions disagree \(P2\)"):
                th.convert_paragraph(self.HTML, PHRASES, "p")

    def test_a_piece_whose_text_is_not_its_rule_fails_p1(self):
        pieces = th.tokenize(self.HTML, PHRASES, "p")
        at = next(k for k, p in enumerate(pieces) if p.kind == "code")
        pieces[at] = th.Piece("code", pieces[at].source, HONORIFIC + "x")
        with self.assertRaisesRegex(PackError, r"piece %d is not converted by the rule \(P1\)" % at):
            th.check_rejoins(self.HTML, pieces, PHRASES, "p")
        with self.assertRaisesRegex(PackError, r"\(P2\)"):
            th.check_regex_agrees(self.HTML, PHRASES, th.assemble(pieces, "p"), "p")

    def test_the_regex_path_agrees_on_every_synthetic_paragraph(self):
        from tests.ziydia_factory import ENTRIES

        for entry in ENTRIES:
            for _, html in entry["paragraphs"]:
                with self.subTest(html=html):
                    self.assertEqual(th.regex_text(html, PHRASES), convert(html))


if __name__ == "__main__":
    unittest.main()
