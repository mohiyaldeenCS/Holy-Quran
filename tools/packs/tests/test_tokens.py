import random
import unittest

from hqpack import tokens
from hqpack.errors import PackError

# Synthetic text only: Latin words and the letters of the synthetic phrase
# "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a".
NOON = "\u0646"
SAD = "\u0635"
TATWEEL = "\u0640"
SMALL_WAW = "\u06e5"
FATHA = "\u064e"
PAUSE = "\u06d6"
SAJDA = "\u06e9"
EMOJI = "\U0001F600"
MARKS = frozenset({0x06D6, 0x06D7, 0x06E9, 0x1F600})


def spans(text, marks=MARKS):
    return tokens.spans(text, marks, "ayah 2:5")


def slice16(text, start, end):
    return text.encode("utf-16-le")[2 * start : 2 * end].decode("utf-16-le")


class Utf16LengthTest(unittest.TestCase):
    def test_counts_code_units(self):
        self.assertEqual(tokens.utf16_length(""), 0)
        self.assertEqual(tokens.utf16_length("ab"), 2)
        self.assertEqual(tokens.utf16_length(NOON + SAD), 2)
        self.assertEqual(tokens.utf16_length("a" + EMOJI), 3)


class IsLetterTest(unittest.TestCase):
    def test_letters(self):
        for cp in (0x41, 0x61, 0x01C5, 0x02B0, 0x0646, 0x0640, 0x06E5, 0x06E6):
            self.assertTrue(tokens.is_letter(cp), hex(cp))

    def test_non_letters(self):
        for cp in (0x20, 0x30, 0x064E, 0x06D6, 0x06E9, 0x06DE, 0x1F600, 0x00A0):
            self.assertFalse(tokens.is_letter(cp), hex(cp))


class SpansTest(unittest.TestCase):
    def test_words_only(self):
        result = spans("ab cd")
        self.assertEqual(result.words, [(0, 2), (3, 5)])
        self.assertEqual(result.marks, [])

    def test_empty_and_spaces_only(self):
        self.assertEqual(spans(""), tokens.Spans(words=[], marks=[]))
        self.assertEqual(spans("   "), tokens.Spans(words=[], marks=[]))

    def test_leading_trailing_and_double_spaces(self):
        result = spans("  ab   cd  ")
        self.assertEqual(result.words, [(2, 4), (7, 9)])
        self.assertEqual(result.marks, [])

    def test_mark_before_first_word(self):
        result = spans(PAUSE + " ab")
        self.assertEqual(result.words, [(2, 4)])
        self.assertEqual(result.marks, [(0, 0, 1)])

    def test_mark_between_words(self):
        result = spans(NOON + SAD + " " + PAUSE + " " + NOON)
        self.assertEqual(result.words, [(0, 2), (5, 6)])
        self.assertEqual(result.marks, [(1, 3, 4)])

    def test_mark_after_last_word(self):
        result = spans("ab cd " + SAJDA)
        self.assertEqual(result.words, [(0, 2), (3, 5)])
        self.assertEqual(result.marks, [(2, 6, 7)])

    def test_mark_only_text(self):
        result = spans(" " + PAUSE + "  " + SAJDA + " ")
        self.assertEqual(result.words, [])
        self.assertEqual(result.marks, [(0, 1, 2), (0, 4, 5)])

    def test_multi_code_point_mark(self):
        result = spans("ab " + PAUSE + SAJDA)
        self.assertEqual(result.marks, [(1, 3, 5)])

    def test_tatweel_and_small_waw_tokens_are_words(self):
        result = spans(TATWEEL + " " + SMALL_WAW + " " + TATWEEL + FATHA)
        self.assertEqual(result.words, [(0, 1), (2, 3), (4, 6)])
        self.assertEqual(result.marks, [])

    def test_letter_with_mark_code_point_stays_one_word(self):
        result = spans(NOON + PAUSE + SAD + " " + SAJDA + NOON)
        self.assertEqual(result.words, [(0, 3), (4, 6)])
        self.assertEqual(result.marks, [])

    def test_combining_marks_inside_words(self):
        result = spans(NOON + FATHA + SAD + FATHA + " x" + "\u0301")
        self.assertEqual(result.words, [(0, 4), (5, 7)])

    def test_combining_mark_alone_must_be_in_table(self):
        with self.assertRaises(PackError) as caught:
            spans("ab " + FATHA)
        self.assertIn("mark 1 holds U+064E", str(caught.exception))
        self.assertEqual(spans("ab " + FATHA, MARKS | {0x064E}).marks, [(1, 3, 4)])

    def test_non_bmp_offsets(self):
        text = "ab " + EMOJI + " cd"
        result = spans(text)
        self.assertEqual(result.words, [(0, 2), (6, 8)])
        self.assertEqual(result.marks, [(1, 3, 5)])
        self.assertEqual(slice16(text, 6, 8), "cd")

    def test_non_bmp_letter_in_word(self):
        gothic_ahsa = "\U00010330"
        result = spans(gothic_ahsa + "b c")
        self.assertEqual(result.words, [(0, 3), (4, 5)])

    def test_refuses_other_separators_and_controls(self):
        for cp in (0x00A0, 0x2009, 0x3000, 0x2028, 0x2029, 0x0009, 0x000A, 0x000D, 0x0000, 0x007F):
            with self.subTest(cp=hex(cp)):
                with self.assertRaises(PackError) as caught:
                    spans("zebra" + chr(cp) + "lion")
                message = str(caught.exception)
                self.assertIn("ayah 2:5", message)
                self.assertIn("U+%04X" % cp, message)
                self.assertNotIn("zebra", message)
                message.encode("ascii")

    def test_refuses_lone_surrogate(self):
        with self.assertRaises(PackError) as caught:
            spans("ab \ud800")
        self.assertIn("U+D800", str(caught.exception))

    def test_refuses_mark_outside_table(self):
        with self.assertRaises(PackError) as caught:
            spans("zebra " + PAUSE + " lion 7")
        message = str(caught.exception)
        self.assertEqual(
            message, "ayah 2:5 mark 2 holds U+0037, which is not in the mark table"
        )

    def test_refuses_mark_with_one_code_point_outside_table(self):
        with self.assertRaises(PackError) as caught:
            spans(PAUSE + "\u06dc")
        self.assertIn("mark 1 holds U+06DC", str(caught.exception))

    def test_messages_are_ascii_and_hide_the_text(self):
        for text in (NOON + SAD + "\u00a0" + NOON, NOON + " " + "\u06dd"):
            with self.assertRaises(PackError) as caught:
                spans(text)
            message = str(caught.exception)
            message.encode("ascii")
            self.assertNotIn(NOON, message)

    def test_does_not_change_the_text(self):
        text = " " + NOON + "\u0301" + " e\u0301 "
        copy = text.encode("utf-8")
        spans(text)
        self.assertEqual(text.encode("utf-8"), copy)

    def test_rejoin_property(self):
        letters = ["a", "Z", NOON, SAD, TATWEEL, SMALL_WAW, "\U00010330"]
        combining = [FATHA, "\u0301", PAUSE]
        marks = [PAUSE, "\u06d7", SAJDA, EMOJI]
        generator = random.Random(20261011)
        for _ in range(500):
            text = self._random_text(generator, letters, combining, marks)
            result = spans(text)
            self._check_rejoin(text, result)

    def _random_text(self, generator, letters, combining, marks):
        parts = [" " * generator.randint(0, 2)]
        for _ in range(generator.randint(0, 8)):
            if generator.random() < 0.3:
                token = "".join(generator.choice(marks) for _ in range(generator.randint(1, 2)))
            else:
                token = "".join(
                    generator.choice(letters) + generator.choice(["", ""] + combining)
                    for _ in range(generator.randint(1, 3))
                )
                if generator.random() < 0.2:
                    token = generator.choice(marks) + token
            parts.append(token)
            parts.append(" " * generator.randint(1, 3))
        return "".join(parts)

    def _check_rejoin(self, text, result):
        units = text.encode("utf-16-le")
        everything = sorted(
            [(start, end, True) for start, end in result.words]
            + [(start, end, False) for _, start, end in result.marks]
        )
        rebuilt = b""
        at = 0
        words_seen = 0
        for start, end, is_word in everything:
            gap = units[2 * at : 2 * start]
            self.assertEqual(gap, " ".encode("utf-16-le") * (start - at))
            piece = units[2 * start : 2 * end]
            token = piece.decode("utf-16-le")
            self.assertNotIn(" ", token)
            has_letter = any(tokens.is_letter(ord(c)) for c in token)
            self.assertEqual(has_letter, is_word)
            if not is_word:
                self.assertIn((words_seen, start, end), result.marks)
            words_seen += is_word
            rebuilt += gap + piece
            at = end
        tail = units[2 * at :]
        self.assertEqual(tail, " ".encode("utf-16-le") * (len(tail) // 2))
        self.assertEqual(rebuilt + tail, units)


if __name__ == "__main__":
    unittest.main()
