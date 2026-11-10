"""D-189: pairing footnote marks with their notes per page, each case that stops the build, and the passage-level P2."""

from __future__ import annotations

import unittest

from hqpack import tafsir_footnotes as tf
from hqpack.errors import PackError
from hqpack.tafsir_passages import Chosen
from tests.ziydia_factory import BOLD, END, HR, NOTE, SEPARATOR, code, digits, mark, note, para

PHRASES = {"\u00f7": "Synthetic honorific"}


def page(*paragraphs):
    return "\n".join(paragraphs)


BODY = para("Synthetic body" + mark(2) + " and" + mark(1))
NOTES = (note(1, "Synthetic one"), note(None, "Synthetic one more"), note(2, "Synthetic two"))
PAGES = {10: page(BODY, SEPARATOR, *NOTES), 11: page(para("Synthetic next"))}


class ReadPageTest(unittest.TestCase):
    def test_marks_notes_and_their_paragraphs(self):
        notes = tf.read_page(PAGES[10], 10)
        self.assertEqual(dict(notes.marks), {digits(1): 1, digits(2): 1})
        self.assertEqual(notes.order, (digits(1), digits(2)))
        self.assertEqual(notes.notes, {digits(1): NOTES[:2], digits(2): NOTES[2:]})
        self.assertEqual(notes.problems, ())

    def test_a_page_without_footnotes(self):
        notes = tf.read_page(page(para("Synthetic")), 3)
        self.assertEqual((dict(notes.marks), notes.notes, notes.problems), ({}, {}, ()))

    def test_a_number_may_follow_an_nbsp_or_a_span(self):
        for head in ("&nbsp", " ", BOLD):
            with self.subTest(head=head):
                html = NOTE + head + "(" + digits(7) + ") Synthetic" + (END if head == BOLD else "") + "</p>"
                self.assertEqual(tf.read_page(page(SEPARATOR, html), 3).order, (digits(7),))

    def test_problems_of_the_page_alone(self):
        cases = (
            (page(SEPARATOR, note(None, "Synthetic"), note(1, "Synthetic")), ("unnumbered_note_opens_page", "")),
            (page(SEPARATOR, note(1, "Synthetic"), note(1, "Synthetic")), ("number_repeated_on_page", digits(1))),
            (page(NOTE + HR + "x</p>", note(1, "Synthetic")), ("separator_not_empty", "")),
            (page(para("&nbsp" + HR)), ("separator_not_empty", "")),
            (page(SEPARATOR, note(1, "Synthetic"), SEPARATOR), ("page_layout", "")),
            (page(note(1, "Synthetic"), SEPARATOR), ("page_layout", "")),
            (page(SEPARATOR, para("Synthetic")), ("page_layout", "")),
            (page(SEPARATOR, note(1, "Synthetic" + mark(1))), ("page_layout", "")),
        )
        for html, problem in cases:
            with self.subTest(problem=problem):
                self.assertIn(problem, tf.read_page(html, 3).problems)

    def test_an_unnumbered_number_form_is_not_a_number(self):
        for head in ("(1)", "(" + digits(1), code("\u00f7") + "(" + digits(1) + ")"):
            with self.subTest(head=head):
                self.assertEqual(tf.read_page(page(SEPARATOR, NOTE + head + "</p>"), 3).problems, (("unnumbered_note_opens_page", ""),))


class NotesOfMarksTest(unittest.TestCase):
    def test_each_shipped_mark_gets_its_note(self):
        marks = {3: [(10, digits(2)), (10, digits(1))]}
        found, cases = tf.notes_of_marks(marks, PAGES)
        self.assertEqual(cases, [])
        self.assertEqual(found, {(10, digits(1)): NOTES[:2], (10, digits(2)): NOTES[2:]})

    def test_only_pages_with_a_shipped_mark_are_paired(self):
        pages = {**PAGES, 12: page(SEPARATOR, note(None, "Synthetic"), note(9, "Synthetic"))}
        self.assertEqual(tf.notes_of_marks({3: [(10, digits(1)), (10, digits(2))]}, pages)[1], [])

    def test_the_cases(self):
        def cases_of(marks, **pages):
            given = dict(PAGES)
            given.update({int(k[1:]): v for k, v in pages.items()})
            return sorted((c.kind, c.site_page, c.number, c.entries) for c in tf.notes_of_marks(marks, given)[1])

        both = {3: [(10, digits(2)), (10, digits(1))]}
        self.assertEqual(
            cases_of(both, p11=page(SEPARATOR, note(None, "Synthetic"))),
            [("unnumbered_note_opens_page", 11, "", (3,))],
        )
        self.assertEqual(
            cases_of(both, p10=page(BODY, SEPARATOR, note(None, "Synthetic"), *NOTES)),
            [("unnumbered_note_opens_page", 10, "", (3,))],
        )
        self.assertEqual(
            cases_of({3: [(10, digits(1))], 4: [(10, digits(1))]}, p10=page(BODY, para("x" + mark(1)), SEPARATOR, *NOTES)),
            [("number_repeated_on_page", 10, digits(1), (3, 4))],
        )
        self.assertEqual(
            cases_of(both, p10=page(BODY, SEPARATOR, *NOTES[:2])),
            [("mark_without_note", 10, digits(2), (3,))],
        )
        self.assertEqual(
            cases_of(both, p10=page(BODY, SEPARATOR, *NOTES, note(4, "Synthetic"))),
            [("note_without_mark", 10, digits(4), (3,))],
        )
        self.assertEqual(
            cases_of(both, p10=page(BODY, NOTE + HR + "&nbsp</p>", *NOTES)),
            [("separator_not_empty", 10, "", (3,))],
        )
        self.assertEqual(
            cases_of({3: [(10, digits(1))]}, p10=page(para("Synthetic" + mark(1)))),
            [("mark_without_note", 10, digits(1), (3,))],
        )

    def test_the_page_after_is_read_only_when_the_last_note_is_used(self):
        pages = dict(PAGES)
        pages[11] = page(SEPARATOR, note(None, "Synthetic"))
        self.assertEqual(tf.notes_of_marks({3: [(10, digits(1))], 4: [(10, digits(2))]}, pages)[1][0].entries, (4,))
        pages[10] = page(para("Synthetic" + mark(2)), para("x" + mark(1)), SEPARATOR, NOTES[2], *NOTES[:2])
        self.assertEqual(tf.notes_of_marks({3: [(10, digits(2))]}, pages)[1], [])


class RepeatedInPassageTest(unittest.TestCase):
    def test_a_number_repeated_among_a_passages_marks(self):
        first, second, third = Chosen(3, 1, 1, 2, ()), Chosen(4, 1, 2, 3, ()), Chosen(5, 1, 3, 3, ())
        marks = {3: [(10, digits(1))], 4: [(11, digits(1)), (11, digits(2))], 5: [(12, digits(3))]}
        cases = tf.repeated_in_passages([[first, third, second]], marks)
        self.assertEqual(cases, [tf.Case("number_repeated_in_passage", 11, digits(1), (3, 4))])
        self.assertEqual(tf.repeated_in_passages([[first], [second]], marks), [])


class RefuseTest(unittest.TestCase):
    def test_the_message_names_book_page_number_kind_and_entries(self):
        cases = [
            tf.Case("note_without_mark", 12, digits(12), (5,)),
            tf.Case("unnumbered_note_opens_page", 11, "", (3, 4)),
            tf.Case("note_without_mark", 12, digits(12), (5,)),
        ]
        with self.assertRaises(PackError) as caught:
            tf.refuse(440, cases)
        message = str(caught.exception)
        self.assertTrue(message.isascii())
        self.assertIn("book 440: 2 footnote cases stop the build (unnumbered_note_opens_page 1, note_without_mark 1)", message)
        self.assertIn("site page 11 unnumbered_note_opens_page (entries 3, 4); site page 12 N 12 note_without_mark (entries 5)", message)
        self.assertIn("settles one only by excluding its entries", message)
        tf.refuse(440, [])


class RegexPassageTextTest(unittest.TestCase):
    def test_body_then_notes_in_the_marks_order(self):
        self.assertEqual(
            tf.regex_passage_text([(10, BODY), (11, para("Synthetic next"))], PAGES, PHRASES),
            [
                "Synthetic body\u2063(\u2063" + digits(2) + ") and\u2063(\u2063" + digits(1) + ")",
                "Synthetic next",
                "(" + digits(2) + ") Synthetic two",
                "(" + digits(1) + ") Synthetic one",
                "Synthetic one more",
            ],
        )


if __name__ == "__main__":
    unittest.main()
