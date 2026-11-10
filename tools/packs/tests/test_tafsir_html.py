"""D-185: the closed conversion of a paragraph's html, its refusals and its proofs, on synthetic paragraphs."""

from __future__ import annotations

import unittest
from unittest import mock

from hqpack import tafsir_html as th
from hqpack.errors import PackError
from tests.ziydia_factory import (
    BOLD,
    CODE,
    END,
    HONORIFIC,
    HR,
    NOTE,
    PHRASE,
    QUOTE,
    RED,
    SEPARATOR,
    SMALL,
    code,
    digits,
    mark,
    note,
    para,
)

PHRASES = {"\u00f7": HONORIFIC, "&": "Synthetic honorific"}
CODE_2 = '<span  style="color: #800000;">'  # the code span with two spaces, as the site writes most of them


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
            (para('x<sup style="color: #800000;">(\u20631)</sup>'), "the <sup> at offset 45 is not a footnote mark (U+2063 N)"),
            (para("<hr>"), "<hr> at offset 44; the footnote line stands only in its empty paragraph"),
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


class SiteMarkupTest(unittest.TestCase):
    """The markup of the eight books, each string as pages.jsonl holds it."""

    def test_the_heading_paragraph(self):
        html = th.HEADING_OPEN + "Synthetic heading " + CODE_2 + "\u00f7" + END + "</p>"
        self.assertEqual(convert(html), "Synthetic heading " + HONORIFIC)

    def test_both_forms_of_the_code_span(self):
        for span in th.CODE_SPANS:
            with self.subTest(span=span):
                paragraph = th.convert_paragraph(para("Synthetic " + span + "\u00f7" + END), PHRASES, "p")
                self.assertEqual(paragraph.text, "Synthetic " + HONORIFIC)
                self.assertEqual(paragraph.replaced, {"\u00f7": 1})
        self.assertEqual(convert(para("Synthetic " + CODE_2 + "..." + END)), "Synthetic ...")

    def test_a_centred_div_where_the_books_put_it(self):
        self.assertEqual(convert(para("&nbsp&nbsp" + th.DIV_OPEN + CODE_2 + "\ufdfd" + END + th.DIV_CLOSE)), "\ufdfd")
        self.assertEqual(convert(para("&nbsp" + th.DIV_OPEN + CODE_2 + "\u00f7" + END + th.DIV_CLOSE)), HONORIFIC)

    def test_the_regex_path_agrees_on_the_site_markup(self):
        for html in (
            th.HEADING_OPEN + "Synthetic " + CODE_2 + "&" + END + "</p>",
            para("&nbsp" + th.DIV_OPEN + CODE_2 + "\u00f7" + END + th.DIV_CLOSE),
        ):
            with self.subTest(html=html):
                self.assertEqual(th.regex_text(html, PHRASES), convert(html))

    def test_refusals(self):
        div = th.DIV_OPEN + "centred" + th.DIV_CLOSE
        centred = th.DIV_OPEN + CODE_2 + "\ufdfd" + END + th.DIV_CLOSE
        misplaced = "is not &nbsp, then a <div> holding one code span, then </p>"
        cases = (
            (para("Synthetic" + div), misplaced),
            (para("&nbsp" + div), misplaced),
            (para(centred), misplaced),
            (para("Synthetic " + centred), misplaced),
            (para("&nbsp" + centred + " "), misplaced),
            (para("&nbsp" + centred + "Synthetic"), misplaced),
            (para("&nbsp" + centred + "&nbsp"), misplaced),
            (para("&nbsp" + th.DIV_OPEN + CODE_2 + "\ufdfd" + END + ":" + th.DIV_CLOSE), misplaced),
            (para("&nbsp" + th.DIV_OPEN + " " + CODE_2 + "\ufdfd" + END + th.DIV_CLOSE), misplaced),
            (para("&nbsp" + th.DIV_OPEN + CODE_2 + "\ufdfd" + END + CODE_2 + "\ufdfd" + END + th.DIV_CLOSE), misplaced),
            (para("&nbsp" + th.DIV_OPEN + BOLD + "x" + END + th.DIV_CLOSE), misplaced),
            (para("&nbsp" + th.DIV_OPEN + th.DIV_CLOSE), misplaced),
            (th.HEADING_OPEN + "&nbsp" + centred + "</p>", misplaced),
            (para(BOLD + div + END), "the <div> at offset 82 is not directly inside the paragraph"),
            (para(th.DIV_OPEN + th.DIV_OPEN + th.DIV_CLOSE + th.DIV_CLOSE), "is not directly inside the paragraph"),
            (para("x" + th.DIV_CLOSE), "</div> at offset 45 has no <div>"),
            (para(th.DIV_OPEN + BOLD + "x" + th.DIV_CLOSE + END), "</div> at offset"),
            (para(th.DIV_OPEN + "x"), "</p> at offset 78 closes a <div>"),
            ('<div style="text-align: center;">' + para("x") + "</div>", "unknown markup <div> at offset 0"),
            (para('<span style="color: #800000;" >x</span>'), "unknown markup <span>"),
        )
        for html, expected in cases:
            with self.subTest(expected=expected):
                with self.assertRaises(PackError) as caught:
                    convert(html)
                self.assertIn(expected, str(caught.exception))
                self.assertNotIn("Synthetic", str(caught.exception))

    def test_format_characters_are_passed_over_to_find_the_neighbour(self):
        for html in (
            para("\u0646\u2063" + code("&")),
            para(code("&") + "\u200f\u0646"),
            para("Synthetic\u2063" + BOLD + "\u200e" + END + code("\u00f7")),
        ):
            with self.subTest(html=html):
                with self.assertRaisesRegex(PackError, "touches a letter"):
                    convert(html)
        self.assertEqual(convert(para("Synthetic\u2063 " + code("&"))), "Synthetic\u2063 Synthetic honorific")


class FootnoteMarkupTest(unittest.TestCase):
    """D-189: the three footnote markups, exactly as books 165, 440, 473 and 514 write them."""

    def test_the_site_strings(self):
        self.assertEqual(th.NOTE_OPEN, NOTE)
        self.assertEqual(th.MARK_OPEN + th.MARK_CLOSE, '<sup style="color: #800000;"></sup>')
        self.assertEqual(th.SEPARATOR, NOTE + HR + "</p>")
        self.assertEqual(SEPARATOR, th.SEPARATOR)

    def test_a_mark_stays_as_printed(self):
        for number in (1, 2, 12):
            with self.subTest(number=number):
                paragraph = th.convert_paragraph(para("Synthetic" + mark(number) + " tail"), PHRASES, "p")
                self.assertEqual(paragraph.text, "Synthetic\u2063(\u2063" + digits(number) + ") tail")
                self.assertEqual(paragraph.marks, (digits(number),))
                self.assertFalse(paragraph.note)
        two = th.convert_paragraph(th.HEADING_OPEN + "Synthetic" + mark(2) + BOLD + mark(1) + END + "</p>", PHRASES, "p")
        self.assertEqual(two.marks, (digits(2), digits(1)))

    def test_a_note_paragraph(self):
        paragraph = th.convert_paragraph(note(3, "Synthetic " + code("\u00f7")), PHRASES, "p")
        self.assertEqual(paragraph.text, "(" + digits(3) + ") Synthetic " + HONORIFIC)
        self.assertTrue(paragraph.note)
        self.assertEqual(convert(note(None, BOLD + "Synthetic" + END + " more")), "Synthetic more")

    def test_the_regex_path_agrees(self):
        for html in (
            para("Synthetic" + mark(1) + "," + mark(12)),
            note(2, "Synthetic " + QUOTE + "quoted" + END),
            note(None, "&nbsp Synthetic"),
        ):
            with self.subTest(html=html):
                self.assertEqual(th.regex_text(html, PHRASES), convert(html))

    def test_refusals(self):
        sup = '<sup style="color: #800000;">'
        cases = (
            (note(1, "Synthetic" + mark(2)), "a footnote mark stands in a note paragraph"),
            (para("x" + sup + "(1)</sup>"), "the <sup> at offset 45 is not a footnote mark (U+2063 N)"),
            (para("x" + sup + "(" + digits(1) + ")</sup>"), "is not a footnote mark"),
            (para("x" + sup + "(\u2063" + digits(1) + "</sup>"), "is not a footnote mark"),
            (para("x" + sup + "(\u2063" + digits(1) + ") </sup>"), "is not a footnote mark"),
            (para("x" + sup + "(\u2063" + digits(1) + ")"), "is not a footnote mark"),
            (para("x" + sup + BOLD + "(\u2063" + digits(1) + ")" + END + "</sup>"), "is not a footnote mark"),
            (para('x<sup style="color: #800000">(\u2063' + digits(1) + ")</sup>"), "unknown markup <sup>"),
            (para("x</sup>"), "unknown markup <sup>"),
            (sup + "(\u2063" + digits(1) + ")</sup>", "unknown markup <sup> at offset 0"),
            (SEPARATOR, "<hr> at offset %d; the footnote line stands only in its empty paragraph" % len(NOTE)),
            (para(HR), "<hr> at offset 44"),
            (note(1, HR), "<hr> at offset"),
        )
        for html, expected in cases:
            with self.subTest(expected=expected):
                with self.assertRaises(PackError) as caught:
                    convert(html)
                self.assertIn(expected, str(caught.exception))
                self.assertTrue(str(caught.exception).isascii())

    def test_a_mark_piece_must_hold_a_mark_and_keep_it(self):
        html = para("Synthetic" + mark(1))
        pieces = th.tokenize(html, PHRASES, "p")
        at = next(k for k, p in enumerate(pieces) if p.kind == "mark")
        for source, text in (
            (pieces[at].source, pieces[at].text[:-1]),
            (pieces[at].source.replace("\u2063", ""), pieces[at].text.replace("\u2063", "")),
        ):
            with self.subTest(text=text):
                changed = list(pieces)
                changed[at] = th.Piece("mark", source, text)
                with self.assertRaisesRegex(PackError, r"\(P1\)"):
                    th.check_rejoins(html, changed, PHRASES, "p")

    def test_a_mark_piece_whose_slice_is_not_a_mark_fails_p1(self):
        sup = '<sup style="color: #800000;">(1)</sup>'
        html = para("Synthetic" + sup)
        pieces = [th.Piece("open", th.P_OPEN, ""), th.Piece("text", "Synthetic", "Synthetic"), th.Piece("mark", sup, "(1)"), th.Piece("close", "</p>", "")]
        with self.assertRaisesRegex(PackError, r"piece 2 is not converted by the rule \(P1\)"):
            th.check_rejoins(html, pieces, PHRASES, "p")

    def test_a_tokenizer_that_drops_a_mark_character_fails_both_proofs(self):
        original = th._mark
        html = para("Synthetic" + mark(1) + " tail")

        def mutated(html, at, where):
            stop, piece = original(html, at, where)
            return stop, th.Piece("mark", piece.source, piece.text[:-1])

        with mock.patch.object(th, "_mark", mutated):
            pieces = th.tokenize(html, PHRASES, "p")
            with self.assertRaisesRegex(PackError, r"\(P1\)"):
                th.check_rejoins(html, pieces, PHRASES, "p")
            with self.assertRaisesRegex(PackError, r"\(P2\)"):
                th.check_regex_agrees(html, PHRASES, th.assemble(pieces, "p"), "p")

    def test_a_tokenizer_that_drops_a_note_character_fails_both_proofs(self):
        original = th._text_run
        html = note(1, "Synthetic note words")

        def mutated(html, at):
            end, piece = original(html, at)
            if "note" in piece.source:
                piece = th.Piece("text", piece.source.replace("note", "noe"), piece.text.replace("note", "noe"))
            return end, piece

        with mock.patch.object(th, "_text_run", mutated):
            with self.assertRaisesRegex(PackError, r"\(P1\)"):
                th.convert_paragraph(html, PHRASES, "p")
            pieces = th.tokenize(html, PHRASES, "p")
            with self.assertRaisesRegex(PackError, r"\(P2\)"):
                th.check_regex_agrees(html, PHRASES, th.assemble(pieces, "p"), "p")


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

    def test_a_piece_whose_slice_is_not_one_its_kind_may_have_fails_p1(self):
        pieces = th.tokenize(self.HTML, PHRASES, "p")
        at = next(k for k, p in enumerate(pieces) if p.kind == "text" and p.source.strip())
        for kind in ("open", "close", "nbsp", "kept", "unknown"):
            with self.subTest(kind=kind):
                changed = list(pieces)
                changed[at] = th.Piece(kind, pieces[at].source, "" if kind != "kept" else pieces[at].source)
                with self.assertRaisesRegex(PackError, r"piece %d is not converted by the rule \(P1\)" % at):
                    th.check_rejoins(self.HTML, changed, PHRASES, "p")
        empty = th.Piece("text", "", "")
        with self.assertRaisesRegex(PackError, r"piece 0 is not converted by the rule \(P1\)"):
            th.check_rejoins(self.HTML, [empty] + pieces, PHRASES, "p")

    def test_the_regex_path_agrees_on_every_synthetic_paragraph(self):
        from tests.ziydia_factory import ENTRIES

        for entry in ENTRIES:
            for _, html in entry["paragraphs"]:
                with self.subTest(html=html):
                    self.assertEqual(th.regex_text(html, PHRASES), convert(html))


if __name__ == "__main__":
    unittest.main()
