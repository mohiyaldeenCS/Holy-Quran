#!/usr/bin/env python3
"""Tests for ziydia_link.py. Run: py -m unittest test_ziydia_link (in this folder).

Every page here is made up. The quotations are invented words, never Quran text.
"""

import json
import os
import tempfile
import unittest

import ziydia_link as z

WORDS = "كلام تجريبي"
AR = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")


def ar(number):
    return str(number).translate(AR)


def para(inner):
    return '<p style="margin-top:1px;margin-bottom:1px">%s</p>' % inner


def head(inner):
    return '<p class="border-r-4 px-2" style="margin:4px">%s</p>' % inner


def quote(text=WORDS):
    return '<span style="color: #00AA00;font-family: Ziydia-Q;">%s</span>' % text


def ref(text):
    return chr(0x2063) + '<span style="font-size: 0.8em;">[%s]</span>' % text


def red(text):
    return '<span style="color: #be0000;">%s</span>' % text


def code(char):
    return '<span style="color: #800000;">%s</span>' % char


def page(number, *paragraphs, part=None):
    """A page as ziydia_fetch.py saves it; the site prints labels in these two forms."""
    label = "صفحة %d" % (number + 10)
    if part:
        label = "الجزء %d\n·\n%s" % (part, label)
    return {"url_page": str(number), "page_label": label, "html": "".join(paragraphs)}


RULE = para("- " * 33)


class LinkCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.inp = os.path.join(self.tmp.name, "in")
        self.out = os.path.join(self.tmp.name, "out")

    def write_book(self, book, pages, done=True):
        folder = os.path.join(self.inp, "book_%d" % book)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, "pages.jsonl"), "w", encoding="utf-8") as handle:
            for entry in pages:
                handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
        with open(os.path.join(folder, "state.json"), "w", encoding="utf-8") as handle:
            json.dump({"done": done}, handle)

    def link(self, book, pages, table=None, profile=None):
        self.write_book(book, pages)
        table_path = None
        if table is not None:
            table_path = os.path.join(self.tmp.name, "surahs.json")
            with open(table_path, "w", encoding="utf-8") as handle:
                json.dump(table, handle, ensure_ascii=False)
        if profile is not None:
            saved = z.PROFILES[book]
            z.PROFILES[book] = dict(saved, **profile)
            self.addCleanup(z.PROFILES.__setitem__, book, saved)
        return z.run_link(book, self.inp, self.out, table_path)

    def kinds(self, result):
        return [p["kind"] for p in result.passages]

    def note_kinds(self, result):
        return [n["kind"] for n in result.notes]

    def linked(self, result):
        return [p for p in result.passages if p["kind"] == "passage"]


class ReadingTest(unittest.TestCase):
    def test_text_outside_paragraphs_stops(self):
        with self.assertRaises(z.LinkError):
            z.split_paragraphs({"url_page": "3", "html": para("a") + "loose" + para("b")})

    def test_replacement_character_stops(self):
        with self.assertRaises(z.LinkError):
            z.split_paragraphs({"url_page": "3", "html": para("a" + chr(0xFFFD) + "b")})

    def test_page_without_a_paragraph_stops(self):
        for source in ("", None):
            with self.assertRaises(z.LinkError):
                z.split_paragraphs({"url_page": "3", "html": source})

    def test_page_reference_reads_the_labels_the_site_prints(self):
        self.assertEqual(
            z.page_ref({"url_page": "4094", "page_label": "الجزء 7\n·\nصفحة 618"}),
            {"site_page": 4094, "part": 7, "printed_page": 618},
        )
        self.assertEqual(
            z.page_ref({"url_page": "20", "page_label": "صفحة 92"}),
            {"site_page": 20, "part": 1, "printed_page": 92},
        )

    def test_label_that_cannot_be_read_stops(self):
        with self.assertRaises(z.LinkError):
            z.page_ref({"url_page": "20", "page_label": "92"})

    def test_site_page_that_comes_twice_stops(self):
        with self.assertRaises(z.LinkError):
            z.read_book([page(1, para("a")), page(1, para("b"))])

    def test_heading_key_drops_honorific_codes(self):
        self.assertEqual(z.heading_key(head("سورة مريم " + code("&"))), "سورة مريم")

    def test_name_key_folds_alif_and_marks_only(self):
        self.assertEqual(z.name_key("(الإسراء)"), "الاسراء")
        self.assertEqual(z.name_key("آل عِمران"), "ال عمران")
        self.assertNotEqual(z.name_key("الذريات"), z.name_key("الذاريات"))

    def test_named_reference_forms(self):
        self.assertEqual(z.parse_named_ref("[الحجر: ٩]"), ("الحجر", [[9, 9]]))
        self.assertEqual(z.parse_named_ref("[الحجر: ٩٢ - ٩٣]"), ("الحجر", [[92, 93]]))
        self.assertEqual(z.parse_named_ref("[الزمر: ٣٩، ٤٠]"), ("الزمر", [[39, 39], [40, 40]]))
        self.assertEqual(z.parse_named_ref("[الزخرف ٨١]"), ("الزخرف", [[81, 81]]))
        self.assertEqual(z.parse_named_ref("[الطور، ١١ - ١٥]"), ("الطور", [[11, 15]]))
        self.assertEqual(z.parse_named_ref("[الطور: ٢٣، ]"), ("الطور", [[23, 23]]))

    def test_named_reference_refuses_what_it_cannot_read(self):
        for text in ("[الأعراف: ٢٢ طه: ١٢١]", "[النحل: ٢٠، الفرقان: ٣]", "[الشورى: ]",
                     "[الزخرف]", "[ق ٣٦، - ٣٧]", "[أي]", "[٥]", "[الحجر: 9]"):
            self.assertIsNone(z.parse_named_ref(text), text)

    def test_bracket_number_forms(self):
        self.assertEqual(z.parse_bracket_number("[١٥٢]"), [152, 152])
        self.assertEqual(z.parse_bracket_number("[٣ - ٥]"), [3, 5])
        self.assertIsNone(z.parse_bracket_number("[أي]"))

    def test_quotation_is_read_to_its_own_closing_tag(self):
        nested = "قبل <span>داخل</span> بعد"
        html = para("{" + quote("أول") + "} ثم {" + quote(nested) + "}" + ref("٧") + " و {" + z.QUOTE_OPEN + "ثالث")
        self.assertEqual(z.quotations_with_refs(html), [("أول", None), (nested, "[٧]")])

    def test_ornament_is_a_line_of_asterisks_and_nothing_else(self):
        self.assertTrue(z.is_ornament(para("* * *")))
        for other in (chr(0xFDFD), "٣", "- - -", "* ا *"):
            self.assertFalse(z.is_ornament(para(other)), other)

    def test_label_in_another_form_stops(self):
        for label in ("المجلد 2 صفحة 7", "صفحة 7 من 9"):
            with self.assertRaises(z.LinkError):
                z.page_ref({"url_page": "20", "page_label": label})


class BracketNumbersTest(LinkCase):
    def book(self, *body):
        return [
            page(1, para("مقدمة")),
            page(2, head("(١) سورة الأولى"), *body),
        ]

    def numbered(self, *numbers):
        return [para(quote() + ref(ar(n))) for n in numbers]

    def test_links_by_heading_and_number_and_carries_what_follows(self):
        first = para("قوله " + quote() + ref("٣") + " معناه كذا")
        follow = para("تتمة بلا رقم")
        result = self.link(183, self.book(first, follow, para(quote() + ref("٤ - ٥"))))
        self.assertEqual(self.kinds(result), ["unlinked", "heading", "passage", "passage"])
        passage = result.passages[2]
        self.assertEqual((passage["surah"], passage["refs"], passage["basis"]), (1, [[3, 3]], "heading+number"))
        self.assertEqual([e["html"] for e in passage["paragraphs"]], [first, follow])
        self.assertEqual([e.get("carried", False) for e in passage["paragraphs"]], [False, True])
        self.assertEqual(passage["paragraphs"][0]["printed_page"], 12)
        self.assertEqual(result.passages[3]["refs"], [[4, 5]])
        self.assertEqual(result.counts["linked_passages_needing_review"], 0)

    def test_every_number_of_a_paragraph_is_kept(self):
        body = para(quote() + ref("٣") + " وهو " + quote() + ref("٣") + " و " + quote() + ref("٦"))
        result = self.link(183, self.book(body))
        self.assertEqual(result.passages[-1]["refs"], [[3, 3], [3, 3], [6, 6]])
        self.assertNotIn("review", result.passages[-1])
        self.assertEqual(result.checks["passages_with_more_than_one_number"], 1)

    def test_numbers_that_go_back_inside_a_paragraph_are_flagged(self):
        body = para(quote() + ref("٦") + " و " + quote() + ref("٢"))
        result = self.link(183, self.book(body))
        self.assertEqual(result.passages[-1]["review"], ["ayah_number_out_of_order"])

    def test_paragraph_before_any_number_is_linked_to_the_surah_only(self):
        result = self.link(183, self.book(para("تمهيد"), para(quote() + ref("١"))))
        note = result.passages[2]
        self.assertEqual((note["kind"], note["surah"], note["refs"], note["basis"]), ("unlinked", 1, [], "heading"))

    def test_unnumbered_quotation_is_not_given_the_ayah_before_it(self):
        own = para("وقوله " + quote() + " معناه كذا")
        result = self.link(183, self.book(para(quote() + ref("٣")), own, para("تتمته")))
        self.assertEqual(self.kinds(result)[-2:], ["passage", "unlinked"])
        self.assertEqual(len(result.passages[-2]["paragraphs"]), 1)
        self.assertEqual([e["html"] for e in result.passages[-1]["paragraphs"]], [own, para("تتمته")])
        self.assertIn("quotation_without_a_number", self.note_kinds(result))

    def test_ornament_line_is_kept_apart(self):
        result = self.link(183, self.book(para(quote() + ref("٣")), para("* * *"), para("خاتمة")))
        self.assertEqual(self.kinds(result)[-3:], ["passage", "ornament", "unlinked"])
        self.assertEqual(result.counts["paragraphs_carried"], 0)

    def test_number_before_the_first_heading_links_nothing(self):
        result = self.link(183, [page(1, para(quote() + ref("٣"))), page(2, head("(١) سورة الأولى"))])
        self.assertEqual(self.kinds(result), ["unlinked", "heading"])
        self.assertIsNone(result.passages[0]["surah"])

    def test_heading_out_of_order_stops(self):
        with self.assertRaises(z.LinkError):
            self.link(183, [page(1, head("(٢) سورة الثانية"))])

    def test_heading_that_cannot_be_read_stops(self):
        with self.assertRaises(z.LinkError):
            self.link(183, [page(1, head("فصل"))])

    def test_bracket_that_is_not_a_number_is_noted_not_linked(self):
        result = self.link(183, self.book(para(quote() + ref("أي") + " شرح")))
        self.assertEqual(self.kinds(result)[-1], "unlinked")
        self.assertIn("bracket_is_not_a_number", self.note_kinds(result))

    def test_number_out_of_order_is_flagged_never_corrected(self):
        result = self.link(183, self.book(*self.numbered(35, 36, 28, 39)))
        passages = self.linked(result)
        self.assertEqual([p["refs"][0][0] for p in passages], [35, 36, 28, 39])
        self.assertEqual([p.get("review") for p in passages],
                         [None, None, ["ayah_number_out_of_order"], None])
        self.assertEqual(result.counts["linked_passages_needing_review"], 1)
        self.assertIn("ayah_order_goes_back", self.note_kinds(result))

    def test_number_too_high_flags_the_one_before_the_step_back(self):
        result = self.link(183, self.book(*self.numbered(9, 19, 11, 12)))
        self.assertEqual([p["refs"][0][0] for p in result.passages if "review" in p], [19])

    def test_when_the_neighbours_do_not_decide_both_are_flagged(self):
        for numbers, expected in (((45, 46, 40, 41, 47), [46, 40]), ((36, 28, 39), [36, 28]), ((2, 1), [2, 1])):
            result = self.link(183, self.book(*self.numbered(*numbers)))
            self.assertEqual([p["refs"][0][0] for p in result.passages if "review" in p], expected)

    def test_number_beyond_the_surah_is_flagged_when_a_table_is_given(self):
        table = {"names": {}, "ayat": {"1": 7}}
        result = self.link(183, self.book(*self.numbered(7, 8)), table=table)
        self.assertEqual([p.get("review") for p in self.linked(result)],
                         [None, ["ayah_beyond_the_end_of_the_surah"]])

    def test_range_that_is_not_one_is_flagged(self):
        result = self.link(183, self.book(para(quote() + ref("٩ - ٧")), para(quote() + ref("٠"))))
        self.assertEqual(result.passages[-2]["refs"], [[9, 7]])
        self.assertIn("range_is_not_valid", result.passages[-2]["review"])
        self.assertIn("range_is_not_valid", result.passages[-1]["review"])


def text_block(*parts):
    """A paragraph of quotation only; numbers are written inside the quotation."""
    return para("{" + quote(" ".join(parts)) + "}")


def opens(*numbers, red_span=True):
    text = "(%s)" % " - ".join(ar(n) for n in numbers)
    return para((red(text) if red_span else text) + " {" + quote() + "} شرح")


class TextAndCommentaryTest(LinkCase):
    PROFILE = {"surahs": 2}

    def book(self, extra_first=(), extra_second=()):
        return [
            page(1, head("تقديم"), para("كلمة الناشر")),
            page(2, para("سورة الأولى")),
            page(3, head("سورة الأولى"),
                 text_block(WORDS, ar(1), WORDS, ar(2), WORDS),
                 RULE,
                 para("تفسير (سورة الأولى)"),
                 opens(1),
                 para("تتمة الشرح")),
            page(4, text_block(WORDS, ar(3)),
                 RULE,
                 para("تتمة ثانية"),
                 opens(2, 3, red_span=False),
                 *extra_first),
            page(5, para("سورة الثانية")),
            page(6, head("سورة الثانية"),
                 text_block(WORDS),
                 text_block(WORDS, ar(1), WORDS, ar(2)),
                 RULE,
                 opens(1),
                 opens(2),
                 *extra_second),
        ]

    def run_book(self, **changes):
        return self.link(514, self.book(**changes), profile=self.PROFILE)

    def test_text_above_the_rule_commentary_below_it(self):
        result = self.run_book()
        self.assertEqual(
            self.kinds(result),
            ["heading", "unlinked", "title_page", "heading", "text", "unlinked", "passage", "text",
             "passage", "title_page", "heading", "text", "text", "passage", "passage"],
        )
        linked = self.linked(result)
        self.assertEqual([(p["surah"], p["refs"]) for p in linked],
                         [(1, [[1, 1]]), (1, [[2, 3]]), (2, [[1, 1]]), (2, [[2, 2]])])
        self.assertEqual([e["site_page"] for e in linked[0]["paragraphs"]], [3, 3, 4])
        self.assertEqual([e.get("carried", False) for e in linked[0]["paragraphs"]], [False, True, True])
        self.assertEqual(result.surahs[1]["last_ayah_number"], 3)
        self.assertEqual(result.surahs[2]["last_ayah_number"], 2)
        self.assertEqual(result.checks["surahs_whose_every_ayah_is_opened"], 2)
        self.assertEqual(result.checks["title_pages"], 2)
        self.assertEqual(result.counts["rules_dropped"], 3)
        self.assertEqual(result.notes, [])
        self.assertEqual([p for p in result.passages if "review" in p], [])

    def test_text_blocks_record_the_ayat_they_touch(self):
        blocks = [p for p in self.run_book().passages if p["kind"] == "text"]
        self.assertEqual(blocks[0]["refs"], [[1, 3]])
        self.assertEqual((blocks[0]["starts_inside_ayah"], blocks[0]["ends_inside_ayah"]), (False, True))
        self.assertEqual(blocks[1]["refs"], [[3, 3]])
        self.assertEqual((blocks[1]["starts_inside_ayah"], blocks[1]["ends_inside_ayah"]), (True, False))

    def test_only_the_first_line_of_a_surah_can_be_its_opening_line(self):
        pages = self.book()
        pages[3]["html"] = text_block(WORDS) + pages[3]["html"]
        result = self.link(514, pages, profile=self.PROFILE)
        blocks = [p for p in result.passages if p["kind"] == "text"]
        self.assertEqual(blocks[1]["refs"], [[3, 3]])
        self.assertNotIn("role", blocks[1]["paragraphs"][0])
        opening = [p for p in blocks if p["surah"] == 2][0]
        self.assertEqual((opening["refs"], opening["paragraphs"][0]["role"]), ([], "opening"))
        self.assertEqual(
            result.checks["opening_lines"],
            {"surahs_with_one": 1, "surahs_without": [1], "different_lines": 1},
        )

    def test_commentary_before_the_first_number_belongs_to_the_surah(self):
        intro = self.run_book().passages[5]
        self.assertEqual((intro["kind"], intro["surah"], intro["basis"]), ("unlinked", 1, "heading"))

    def test_rule_joined_to_the_first_commentary_paragraph(self):
        pages = self.book()
        joined = para("- " * 33 + "تتمة ثانية")
        pages[3] = page(4, text_block(WORDS, ar(3)), joined, opens(2, 3))
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertEqual(self.linked(result)[0]["paragraphs"][-1]["html"], joined)
        self.assertEqual(result.counts["rules_dropped"], 2)

    def test_rule_joined_to_a_numbered_paragraph_still_opens_its_ayat(self):
        pages = self.book()
        joined = para("- " * 33 + "(%s - %s) شرح" % (ar(2), ar(3)))
        pages[3] = page(4, text_block(WORDS, ar(3)), joined)
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertEqual(self.linked(result)[1]["refs"], [[2, 3]])
        self.assertEqual(self.linked(result)[1]["paragraphs"][0]["html"], joined)

    def test_only_the_first_rule_of_a_page_is_left_out(self):
        result = self.run_book(extra_first=[RULE])
        self.assertEqual(result.counts["rules_dropped"], 3)
        self.assertEqual(self.linked(result)[1]["paragraphs"][-1]["html"], RULE)

    def test_heading_repeated_below_the_rule_joins_its_heading(self):
        pages = self.book()
        pages[5]["html"] = pages[5]["html"].replace(RULE, RULE + head("(سورة الثانية)"), 1)
        result = self.link(514, pages, profile=self.PROFILE)
        heading = [p for p in result.passages if p["kind"] == "heading" and p["surah"] == 2][0]
        self.assertEqual(len(heading["paragraphs"]), 2)
        self.assertEqual(len(result.surahs), 2)

    def test_heading_repeated_on_a_later_page_stops(self):
        pages = self.book() + [page(7, head("سورة الثانية"), text_block(WORDS, ar(3)))]
        with self.assertRaises(z.LinkError):
            self.link(514, pages, profile=self.PROFILE)

    def test_surah_heading_below_the_rule_or_lower_on_the_page_stops(self):
        below = self.book()[:4] + [page(5, text_block(WORDS, ar(4)), RULE, head("سورة الثانية"))]
        lower = self.book()[:4] + [page(5, text_block(WORDS, ar(4)), head("سورة الثانية"))]
        for pages in (below, lower):
            with self.assertRaises(z.LinkError):
                self.link(514, pages, profile=self.PROFILE)

    def test_surah_heading_printed_again_later_stops(self):
        pages = self.book() + [page(7, head("سورة الأولى"))]
        with self.assertRaises(z.LinkError):
            self.link(514, pages, profile={"surahs": 3})

    def test_heading_that_cannot_be_read_stops(self):
        pages = self.book() + [page(7, head("فصل في كذا"))]
        with self.assertRaises(z.LinkError):
            self.link(514, pages, profile=self.PROFILE)

    def test_wrong_number_of_surahs_stops(self):
        with self.assertRaises(z.LinkError):
            self.link(514, self.book(), profile={"surahs": 3})

    def test_title_page_that_differs_from_its_heading_is_noted(self):
        pages = self.book()
        pages[4] = page(5, para("سورة أخرى"))
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertEqual(self.note_kinds(result), ["title_page_differs_from_the_heading"])

    def test_page_of_one_line_inside_a_surah_is_not_a_title_page(self):
        pages = self.book()
        pages.insert(4, page(40, para("سطر وحيد")))
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertEqual(result.checks["title_pages"], 2)
        self.assertIn("paragraph_above_the_rule_is_not_a_quotation", self.note_kinds(result))
        lone = [p for p in result.passages if p["paragraphs"][0]["site_page"] == 40][0]
        self.assertEqual((lone["kind"], lone["surah"]), ("unlinked", 1))

    def test_printed_numbers_are_kept_and_flagged(self):
        result = self.run_book(extra_first=[opens(3, 1), opens(1, 3, 4)])
        flagged = {tuple(p["refs"][0]): p["review"] for p in result.passages if "review" in p}
        self.assertIn("range_is_not_valid", flagged[(3, 1)])
        self.assertIn("numbers_are_not_a_range", flagged[(1, 4)])
        self.assertIn("ayah_beyond_the_end_of_the_surah", flagged[(1, 4)])

    def test_three_numbers_in_a_row_are_a_range(self):
        result = self.run_book(extra_second=[opens(1, 2, 3)])
        last = self.linked(result)[-1]
        self.assertEqual(last["refs"], [[1, 3]])
        self.assertNotIn("numbers_are_not_a_range", last.get("review", []))

    def test_opening_number_in_another_form_is_noted(self):
        result = self.run_book(extra_second=[para("(2، 3) شرح")])
        self.assertIn("opening_number_not_understood", self.note_kinds(result))

    def test_ayah_no_number_opens_is_noted_and_the_passage_before_it_flagged(self):
        pages = self.book()
        pages[3]["html"] = pages[3]["html"].replace(opens(2, 3, red_span=False), opens(3))
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertIn("ayat_not_opened_by_any_number", self.note_kinds(result))
        self.assertEqual(result.surahs[1]["ayat_without_commentary_number"], [2])
        self.assertEqual(result.checks["surahs_whose_every_ayah_is_opened"], 1)
        self.assertEqual(self.linked(result)[0]["review"], ["the_ayat_after_it_have_no_number"])

    def test_last_ayat_that_no_number_opens_flag_the_last_passage(self):
        pages = self.book()
        pages[5]["html"] = pages[5]["html"].replace(opens(2), "")
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertEqual(self.linked(result)[-1]["review"], ["the_ayat_after_it_have_no_number"])

    def test_ayah_inside_an_earlier_range_leaves_no_gap(self):
        pages = self.book()
        pages[3]["html"] = pages[3]["html"].replace(
            opens(2, 3, red_span=False), opens(1, 3, red_span=False) + opens(2))
        pages[2]["html"] = pages[2]["html"].replace(opens(1), "")
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertEqual([p["refs"] for p in self.linked(result)][:2], [[[1, 3]], [[2, 2]]])
        self.assertEqual([p for p in self.linked(result) if "review" in p], [])

    def test_ayah_opened_twice_is_noted(self):
        result = self.run_book(extra_second=[opens(2)])
        self.assertEqual(self.note_kinds(result), ["ayah_opened_twice"])

    def test_text_number_out_of_sequence_is_noted(self):
        pages = self.book()
        pages[3]["html"] = pages[3]["html"].replace(ar(3), ar(4), 1)
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertIn("text_number_out_of_sequence", self.note_kinds(result))
        self.assertIn("text_numbers_not_printed", self.note_kinds(result))

    def test_surah_that_ends_inside_an_ayah_is_noted(self):
        pages = self.book()
        pages[3]["html"] = pages[3]["html"].replace(text_block(WORDS, ar(3)), text_block(WORDS, ar(3), WORDS))
        result = self.link(514, pages, profile=self.PROFILE)
        self.assertIn("surah_ends_inside_an_ayah", self.note_kinds(result))

    def test_no_paragraph_is_lost_or_changed(self):
        pages = self.book()
        result = self.link(514, pages, profile=self.PROFILE)
        given = [p for entry in pages for p in z.split_paragraphs(entry) if p != RULE]
        kept = sorted(e["html"] for p in result.passages for e in p["paragraphs"])
        self.assertEqual(kept, sorted(given))


class ItemsTest(LinkCase):
    TABLE = {"names": {"الاولى": 1, "الثانية": 2, "الثالثة": 3}, "ayat": {"1": 7, "2": 10, "3": 5}}

    def numbered(self, *body):
        return [page(1, head("[مقدمة]"), para("تمهيد")),
                page(2, head("[%s - سورة الأولى]" % ar(1)), *body)]

    def item(self, number, reference=None, tail=" بيان"):
        inner = red("[%s]" % ar(number)) + " قوله: {" + quote() + "}"
        return para(inner + (ref(reference) if reference else "") + tail)

    def test_item_linked_by_heading_and_reference(self):
        answer = para("جواب")
        result = self.link(276, self.numbered(self.item(1, "الأولى: ٣"), answer), table=self.TABLE)
        passage = result.passages[-1]
        self.assertEqual((passage["kind"], passage["surah"], passage["refs"], passage["basis"], passage["item"]),
                         ("passage", 1, [[3, 3]], "heading+reference", 1))
        self.assertEqual(passage["paragraphs"][1],
                         {"site_page": 2, "part": 1, "printed_page": 12, "html": answer, "carried": True})
        self.assertEqual(result.checks, {"items": 1, "items_linked": 1, "items_linked_by_heading_and_reference": 1})
        self.assertEqual(result.notes, [])

    def test_reference_to_another_surah_is_kept_and_flagged(self):
        result = self.link(276, self.numbered(self.item(1, "الثانية: ٤")), table=self.TABLE)
        passage = result.passages[-1]
        self.assertEqual((passage["surah"], passage["refs"], passage["basis"]), (2, [[4, 4]], "reference"))
        self.assertEqual(passage["review"], ["reference_names_another_surah_than_the_heading"])

    def test_reference_beyond_the_surah_is_flagged(self):
        result = self.link(276, self.numbered(self.item(1, "الأولى: ٨")), table=self.TABLE)
        self.assertEqual(result.passages[-1]["review"], ["ayah_beyond_the_end_of_the_surah"])

    def test_item_without_reference_is_linked_to_the_surah_only(self):
        result = self.link(276, self.numbered(self.item(1), para("جواب")), table=self.TABLE)
        passage = result.passages[-1]
        self.assertEqual((passage["kind"], passage["surah"], passage["refs"], passage["basis"]),
                         ("unlinked", 1, [], "heading"))
        self.assertEqual(len(passage["paragraphs"]), 2)
        self.assertIn("item_without_a_reference", self.note_kinds(result))

    def test_name_with_a_misprint_is_not_guessed(self):
        result = self.link(276, self.numbered(self.item(1, "الأولي: ٣")), table=self.TABLE)
        self.assertEqual(result.passages[-1]["kind"], "unlinked")
        self.assertIn("surah_name_not_in_the_table", self.note_kinds(result))

    def test_reference_that_cannot_be_read_is_noted(self):
        result = self.link(276, self.numbered(self.item(1, "الأولى: ٣ الثانية: ٤")), table=self.TABLE)
        self.assertEqual(result.passages[-1]["kind"], "unlinked")
        self.assertIn("reference_not_understood", self.note_kinds(result))

    def test_only_the_first_reference_of_the_item_paragraph_links(self):
        body = self.item(1, "الأولى: ٣", tail=" نسخها {" + quote() + "}" + ref("الثانية: ٩"))
        answer = para("دليله {" + quote() + "}" + ref("الثالثة: ٢"))
        result = self.link(276, self.numbered(body, answer), table=self.TABLE)
        passage = result.passages[-1]
        self.assertEqual((passage["surah"], passage["refs"]), (1, [[3, 3]]))
        self.assertNotIn("review", passage)

    def test_ornament_does_not_end_an_item(self):
        body = [self.item(1, "الأولى: ٣"), para("* * *"), para("تتمة الجواب")]
        result = self.link(276, self.numbered(*body), table=self.TABLE)
        self.assertEqual(self.kinds(result)[-2:], ["passage", "ornament"])
        self.assertEqual(len(result.passages[-2]["paragraphs"]), 2)

    def test_carried_paragraph_that_cites_inside_its_words_is_not_flagged(self):
        answer = para("قال: دليله {" + quote() + "}" + ref("الأولى: ٥"))
        result = self.link(276, self.numbered(self.item(1, "الأولى: ٣"), answer), table=self.TABLE)
        self.assertNotIn("review", result.passages[-1])

    def test_carried_paragraph_that_opens_like_an_item_is_flagged(self):
        unit = para("{" + quote() + "}" + ref("الأولى: ٥") + " بيان آخر")
        result = self.link(276, self.numbered(self.item(1, "الأولى: ٣"), unit), table=self.TABLE)
        self.assertEqual(result.passages[-1]["review"], ["carried_paragraph_opens_with_its_own_reference"])

    def test_heading_number_that_does_not_rise_gives_no_surah(self):
        pages = self.numbered(self.item(1, "الأولى: ٣")) + [
            page(3, head("[%s - سورة الثانية]" % ar(1)), self.item(1, "الثانية: ٤")),
        ]
        result = self.link(276, pages, table=self.TABLE)
        self.assertEqual(self.note_kinds(result), ["heading_number_does_not_rise"])
        last = result.passages[-1]
        self.assertEqual((last["surah"], last["basis"]), (2, "reference"))
        self.assertNotIn("review", last)

    def test_heading_number_that_contradicts_the_table_gives_no_surah(self):
        pages = [page(1, head("[%s - سورة الأولى]" % ar(2)), self.item(1, "الأولى: ٣"))]
        result = self.link(276, pages, table=self.TABLE)
        self.assertEqual(self.note_kinds(result), ["heading_number_differs_from_the_table"])
        self.assertEqual(result.passages[-1]["basis"], "reference")

    def test_name_the_table_lacks_is_taken_from_a_numbered_heading_and_noted(self):
        pages = [page(1, head("[%s - سورة الرابعة]" % ar(4)), self.item(1, "الرابعة: ٣"))]
        result = self.link(276, pages, table={"names": {}, "ayat": {}})
        self.assertEqual(self.note_kinds(result), ["surah_name_taken_from_the_heading"])
        self.assertEqual((result.passages[-1]["surah"], result.passages[-1]["basis"]), (4, "heading+reference"))

    def test_surah_heading_in_another_form_is_noted(self):
        pages = [page(1, head("[(٧٨)، (٧٩) سورة كذا وكذا]"), self.item(1, "الأولى: ٣"))]
        result = self.link(276, pages, table=self.TABLE)
        self.assertEqual(self.note_kinds(result), ["surah_heading_not_understood"])
        self.assertEqual(result.passages[-1]["basis"], "reference")

    def test_item_numbers_may_restart_after_a_heading_only(self):
        pages = self.numbered(self.item(1, "الأولى: ١"), self.item(2, "الأولى: ٢"), self.item(1, "الأولى: ٤")) + [
            page(3, head("[%s - سورة الثانية]" % ar(2)), self.item(1, "الثانية: ١")),
        ]
        result = self.link(276, pages, table=self.TABLE)
        self.assertEqual([(n["kind"], n["site_page"]) for n in result.notes], [("item_number_out_of_sequence", 2)])

    def test_headings_named_without_a_number_use_the_table(self):
        question = para(red("%s -" % ar(1)) + " سألته عن {" + quote() + "}" + ref("الثانية: ٥ - ٦") + "؟")
        pages = [page(1, head("مقدمة المؤلف"), para("تمهيد")),
                 page(2, head("ومن سورة (الثانية)"), para("قال الراوي"), question, para("فقال: كذا")),
                 page(3, head("تفسير سورة المجهولة"), para("شرح متصل"))]
        result = self.link(471, pages, table=self.TABLE)
        self.assertEqual(self.kinds(result),
                         ["heading", "unlinked", "heading", "unlinked", "passage", "heading", "unlinked"])
        linked = result.passages[4]
        self.assertEqual((linked["surah"], linked["refs"], linked["basis"]), (2, [[5, 6]], "heading+reference"))
        self.assertEqual(result.passages[3]["surah"], 2)
        self.assertIsNone(result.passages[6]["surah"])
        self.assertEqual(self.note_kinds(result), ["surah_heading_not_understood"])
        self.assertEqual(result.counts["paragraphs_linked_to_a_surah_only"], 1)
        self.assertEqual(result.counts["paragraphs_with_no_link"], 2)

    def test_red_opening_that_is_not_an_item_number_is_ordinary_text(self):
        result = self.link(276, self.numbered(para(red("تنبيه") + " كلام")), table=self.TABLE)
        self.assertEqual(result.checks["items"], 0)

    def test_items_need_the_table(self):
        with self.assertRaises(z.LinkError):
            self.link(276, self.numbered(self.item(1, "الأولى: ٣")))


# Made-up words, so that a comparison has letters to work on.
ONE, TWO, THREE = "قرمزد بلطنش", "جفدلك سمرطب", "هنكفض غبشتل"


class CompareTest(LinkCase):
    def text_book(self):
        return [
            page(1, head("سورة الأولى"),
                 text_block("ثمكرن ضبطلف"),
                 text_block(ONE, ar(1), "جفدلك"),
                 RULE,
                 para(red("(%s)" % ar(1)) + " {" + quote("ثمكرن ضبطلف " + ONE) + "} شرح"),
                 para(red("(%s)" % ar(2)) + " {" + quote(THREE) + "} شرح")),
            page(2, text_block("سمرطب", ar(2), THREE + " مسماوات", ar(3)),
                 RULE,
                 para(red("(%s)" % ar(3)) + " شرح بلا نص")),
        ]

    def link_text_book(self):
        self.link(514, self.text_book(), profile={"surahs": 1})

    def compare(self, book, *paragraphs, table=None):
        self.link_text_book()
        heading = "(١) سورة الأولى" if book == 183 else "[١ - سورة الأولى]"
        self.link(book, [page(1, head(heading), *paragraphs)], table=table)
        counts = z.run_compare(book, self.out)
        with open(os.path.join(self.out, "book_%d" % book, "compare.json"), encoding="utf-8") as handle:
            return counts, json.load(handle)

    def outcome(self, quotation, number):
        counts, report = self.compare(183, para("{" + quote(quotation) + "}" + ref(ar(number)) + " شرح"))
        return [name for name in z.OUTCOMES if counts[name]], report["not_confirmed"]

    def test_quotation_found_in_its_ayah_even_across_a_page(self):
        self.assertEqual(self.outcome(TWO, 2), (["same"], []))

    def test_vowel_marks_do_not_count(self):
        self.assertEqual(self.outcome("جَفْدَلك سمرطب", 2), (["same"], []))

    def test_spelling_of_weak_letters_is_reported_apart(self):
        self.assertEqual(self.outcome(THREE + " مسموت", 3), (["same_but_for_spelling"], []))

    def test_printed_number_that_points_elsewhere_is_listed_with_where(self):
        self.assertEqual(self.outcome(TWO, 1)[0], ["in_a_neighbouring_ayah"])
        self.assertEqual(self.outcome(TWO, 3)[0], ["in_a_neighbouring_ayah"])
        outcomes, listed = self.outcome(THREE, 1)
        self.assertEqual(outcomes, ["elsewhere_in_the_surah"])
        self.assertEqual((listed[0]["refs"], listed[0]["found_at"]), ([[1, 1]], [3]))

    def test_quotation_found_nowhere(self):
        outcomes, listed = self.outcome("زغفطص كمبلد", 2)
        self.assertEqual((outcomes, listed[0]["outcome"]), (["not_found"], "not_found"))

    def test_short_quotation_is_not_compared(self):
        self.assertEqual(self.outcome("قرم", 2), (["too_short_to_compare"], []))

    def test_words_between_braces_inside_a_quotation_are_the_authors(self):
        self.assertEqual(self.outcome(THREE + "} إلى قوله: {" + ONE, 3)[0], ["partly_found"])
        self.assertEqual(self.outcome(ONE + "} إلى قوله: {" + TWO, 1)[0], ["in_a_neighbouring_ayah"])
        self.assertEqual(self.outcome("قرمزد ... بلطنش", 1)[0], ["same"])

    def test_the_worst_of_several_quotations_decides(self):
        for first, second in (((ONE, 1), (TWO, 3)), ((TWO, 3), (ONE, 1))):
            body = "".join("{" + quote(q) + "}" + ref(ar(n)) + " و " for q, n in (first, second))
            counts, report = self.compare(183, para(body))
            self.assertEqual(counts["in_a_neighbouring_ayah"], 1)
            self.assertEqual(len(report["not_confirmed"]), 1)

    def test_number_printed_twice_in_the_text_keeps_both_runs_of_words(self):
        passages = [{"kind": "text", "surah": 1, "paragraphs": [
            {"html": text_block(ONE, ar(1), TWO, ar(1))}]}]
        ayat, _ = z.printed_text(passages)
        self.assertEqual(z.letters(ayat[(1, 1)]), z.letters(ONE + TWO))

    def test_the_opening_line_counts_with_the_first_ayah(self):
        self.link_text_book()
        counts = z.run_compare(514, self.out)
        self.assertEqual((counts["same"], counts["in_a_neighbouring_ayah"], counts["no_quotation"]), (1, 1, 1))

    def test_item_is_compared_by_the_quotation_before_its_reference(self):
        table = {"names": {"الاولى": 1}, "ayat": {"1": 3}}
        item = para(red("[%s]" % ar(1)) + " {" + quote(TWO) + "}" + ref("الأولى: ٢") + " ثم {" + quote(ONE) + "}")
        counts, report = self.compare(276, item, table=table)
        self.assertEqual(counts["same"], 1)
        self.assertEqual(report["text_from_book"], 514)

    def test_every_quotation_before_the_items_reference_is_compared(self):
        table = {"names": {"الاولى": 1}, "ayat": {"1": 3}}

        def item(first):
            return para(red("[%s]" % ar(1)) + " من {" + quote(first) + "} إلى {" + quote(THREE) + "}"
                        + ref("الأولى: ٢ - ٣"))

        self.assertEqual(self.compare(276, item(TWO), table=table)[0]["same"], 1)
        counts, report = self.compare(276, item("زغفطص كمبلد"), table=table)
        self.assertEqual((counts["same"], len(report["not_confirmed"])), (0, 1))

    def test_quotation_that_holds_another_span_is_compared_whole(self):
        inner = "جفدلك <span>سمرطب</span>"
        counts, _ = self.compare(183, para("{" + quote(inner) + "}" + ref("٢")))
        self.assertEqual(counts["same"], 1)

    def test_item_whose_reference_follows_no_quotation_is_not_compared(self):
        table = {"names": {"الاولى": 1}, "ayat": {"1": 3}}
        item = para(red("[%s]" % ar(1)) + " الآية" + ref("الأولى: ٢") + " ثم {" + quote(ONE) + "}" + ref("الأولى: ١"))
        counts, _ = self.compare(276, item, table=table)
        self.assertEqual(counts["no_quotation"], 1)

    def test_range_that_is_not_one_is_set_aside(self):
        counts, report = self.compare(183, para("{" + quote(ONE) + "}" + ref("٣ - ١")))
        self.assertEqual((counts["range_not_usable"], report["not_confirmed"]), (1, []))

    def test_flagged_passage_that_the_text_confirms_is_counted(self):
        body = [para("{" + quote(q) + "}" + ref(ar(n))) for q, n in ((TWO, 2), (ONE, 1))]
        counts, _ = self.compare(183, *body)
        self.assertEqual((counts["same"], counts["flagged_by_the_linker_and_confirmed"]), (2, 2))

    def test_compare_changes_no_link_and_writes_no_text_of_its_own(self):
        self.link_text_book()
        self.link(183, [page(1, head("(١) سورة الأولى"), para("{" + quote(THREE) + "}" + ref("١")))])
        folder = os.path.join(self.out, "book_183")
        before = z.file_sha256(os.path.join(folder, "passages.jsonl"))
        z.run_compare(183, self.out)
        self.assertEqual(z.file_sha256(os.path.join(folder, "passages.jsonl")), before)
        with open(os.path.join(folder, "compare.json"), encoding="utf-8") as handle:
            report = handle.read()
        self.assertIsNone(z.ARABIC_LETTER.search(report))
        self.assertEqual(json.loads(report)["text_passages_sha256"],
                         z.file_sha256(os.path.join(self.out, "book_514", "passages.jsonl")))
        with open(os.path.join(folder, "compare.html"), encoding="utf-8") as handle:
            self.assertIn("elsewhere_in_the_surah at ayah 3", handle.read())

    def test_compare_needs_the_text_book(self):
        self.link(183, [page(1, head("(١) سورة الأولى"), para("{" + quote(ONE) + "}" + ref("١")))])
        with self.assertRaises(z.LinkError):
            z.run_compare(183, self.out)


class OutputTest(LinkCase):
    def pages(self):
        return [page(1, head("(١) سورة الأولى"),
                     para(quote() + ref("٢") + " شرح " + code("#")),
                     para(quote() + ref("١")))]

    def test_files_are_written_and_repeatable(self):
        self.link(183, self.pages())
        folder = os.path.join(self.out, "book_183")
        self.assertEqual(sorted(os.listdir(folder)),
                         ["passages.jsonl", "report.json", "review.html", "sample.html"])
        with open(os.path.join(folder, "report.json"), encoding="utf-8") as handle:
            report = json.load(handle)
        self.assertEqual(report["passages_sha256"], z.file_sha256(os.path.join(folder, "passages.jsonl")))
        self.assertEqual(report["input"], {
            "pages_sha256": z.file_sha256(os.path.join(self.inp, "book_183", "pages.jsonl")),
            "surahs_table_sha256": None,
        })
        first = {name: z.file_sha256(os.path.join(folder, name)) for name in os.listdir(folder)}
        self.link(183, self.pages())
        second = {name: z.file_sha256(os.path.join(folder, name)) for name in os.listdir(folder)}
        self.assertEqual(first, second)

    def test_paragraphs_reach_the_file_byte_for_byte(self):
        awkward = para(
            "&nbsp&nbsp" + chr(0xA0) + " e" + chr(0x301) + " " + chr(0xE9) + " &amp; <sup>(1)</sup>  "
            + quote("ن" + chr(0x64E) + chr(0x651) + "ص <span>داخلي</span> تال") + ref("٢") + " \t"
        )
        pages = [page(1, head("(١) سورة الأولى"), awkward, para(" تابع "))]
        self.link(183, pages)
        with open(os.path.join(self.out, "book_183", "passages.jsonl"), "rb") as handle:
            lines = handle.read().split(b"\n")
        stored = [e["html"] for line in lines if line for e in json.loads(line.decode("utf-8"))["paragraphs"]]
        self.assertEqual([s.encode("utf-8") for s in stored],
                         [p.encode("utf-8") for p in z.split_paragraphs(pages[0])])
        self.assertNotIn(b"\r", b"".join(lines))

    def test_lost_or_doubled_paragraph_stops(self):
        book, refs = z.read_book(self.pages())
        result = z.Result(183, "bracket_numbers", refs)
        z.link_bracket_numbers(book, z.PROFILES[183], result, None)
        z.finish(result, book)
        result.passages[1]["paragraphs"][0]["html"] = result.passages[2]["paragraphs"][0]["html"]
        with self.assertRaises(z.LinkError):
            z.finish(result, book)

    def test_flagged_passages_go_to_the_review_page_not_the_sample(self):
        self.link(183, self.pages())
        folder = os.path.join(self.out, "book_183")
        with open(os.path.join(folder, "review.html"), encoding="utf-8") as handle:
            review = handle.read()
        self.assertEqual(review.count("<section>"), 2)
        self.assertIn("part 1, printed page 11 (site page 1)", review)
        with open(os.path.join(folder, "sample.html"), encoding="utf-8") as handle:
            self.assertEqual(handle.read().count("<section>"), 0)

    def test_stopped_run_leaves_no_earlier_result_behind(self):
        self.link(183, self.pages())
        folder = os.path.join(self.out, "book_183")
        with open(os.path.join(folder, "compare.json"), "w", encoding="utf-8") as handle:
            handle.write("{}")
        self.write_book(183, [page(1, head("فصل"))])
        with self.assertRaises(z.LinkError):
            z.run_link(183, self.inp, self.out)
        self.assertEqual(os.listdir(folder), [])

    def test_unfinished_extraction_is_noted(self):
        self.write_book(183, self.pages(), done=False)
        result = z.run_link(183, self.inp, self.out)
        self.assertIn("extraction_not_marked_complete", [n["kind"] for n in result.notes])

    def write_report(self, book, surahs):
        folder = os.path.join(self.out, "book_%d" % book)
        os.makedirs(folder)
        with open(os.path.join(folder, "report.json"), "w", encoding="utf-8") as handle:
            json.dump({"surahs": surahs}, handle)

    def test_names_table_refuses_one_name_for_two_surahs(self):
        for book in (183, 514):
            self.write_report(book, {str(i): {"name_in_book": "اسم %d" % i, "number": "printed"}
                                     for i in range(1, 115)})
        self.write_report(276, {str(i): {"name_in_book": "اسم %d" % (i % 114 + 1), "number": "printed"}
                                for i in range(1, 115)})
        z.run_names([183, 514], self.out)
        with self.assertRaises(z.LinkError):
            z.run_names([183, 276], self.out)

    def test_names_table_needs_every_surah(self):
        self.write_report(183, {str(i): {"name_in_book": "اسم %d" % i, "number": "printed"} for i in range(1, 114)})
        with self.assertRaises(z.LinkError):
            z.run_names([183], self.out)

    def test_names_table_is_written(self):
        self.write_report(514, {str(i): {"name_in_book": "اسم %d" % i, "number": "by order", "last_ayah_number": i}
                                for i in range(1, 115)})
        table = z.load_table(z.run_names([514], self.out))
        self.assertEqual(table["names"]["اسم 7"], 7)
        self.assertEqual(table["ayat"][114], 114)

    def test_exit_codes(self):
        base = ["ziydia_link.py", "--in", self.inp, "--out", self.out]
        self.write_book(183, [page(1, head("فصل"))])
        self.assertEqual(z.main(base + ["link", "183"]), 2)
        self.assertEqual(z.main(base + ["link", "999"]), 2)
        self.assertEqual(z.main(base + ["link", "514"]), 2)
        self.assertEqual(z.main(base + ["names", "183"]), 2)
        self.assertEqual(z.main(base + ["compare", "183"]), 2)
        self.assertEqual(z.main(base + ["link", "183", "--surahs", os.path.join(self.inp, "none.json")]), 2)
        for broken in ({"url_page": "1", "html": para("x")},
                       {"url_page": "x", "page_label": "صفحة 1", "html": para("x")},
                       {"url_page": "1", "page_label": 7, "html": para("x")}):
            self.write_book(183, [broken])
            self.assertEqual(z.main(base + ["link", "183"]), 2)
        self.write_book(183, self.pages())
        blocked = os.path.join(self.tmp.name, "a_file")
        with open(blocked, "w", encoding="utf-8"):
            pass
        self.assertEqual(z.main(["ziydia_link.py", "--in", self.inp, "--out", blocked, "link", "183"]), 2)
        self.write_book(183, self.pages())
        self.assertEqual(z.main(base + ["link", "183"]), 0)
        self.assertEqual(z.main(base + ["inspect", "183"]), 0)

    def test_wrong_command_line_exits_with_two(self):
        for arguments in (["link"], ["link", "183", "514"], ["link", "183", "--out"], ["link", "x"]):
            with self.assertRaises(SystemExit) as stopped:
                z.main(["ziydia_link.py"] + arguments)
            self.assertEqual(stopped.exception.code, 2)


if __name__ == "__main__":
    unittest.main(buffer=True)
