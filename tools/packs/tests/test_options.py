import unittest

from hqpack.errors import PackError
from hqpack.options import option_problems, options_from_url

TANZIL_STYLE = (
    "https://example.invalid/download?marks=true&sajdah=true&rub=false"
    "&outType=xml&agree=true"
)
NOON = "\u0646"
PAUSES = [chr(cp) for cp in range(0x06D6, 0x06DC)]
SAJDA = "\u06e9"
RUB = "\u06de"


class OptionsFromUrlTest(unittest.TestCase):
    def test_tanzil_style_url(self):
        options = options_from_url(TANZIL_STYLE)
        self.assertEqual(
            list(options.items()),
            [("marks", "true"), ("sajdah", "true"), ("rub", "false"), ("outType", "xml")],
        )

    def test_none_without_choices(self):
        self.assertIsNone(options_from_url("https://example.invalid/file.xml"))
        self.assertIsNone(options_from_url("https://example.invalid/file.xml?"))
        self.assertIsNone(options_from_url("https://example.invalid/file.xml#a=b"))
        self.assertIsNone(options_from_url("https://example.invalid/d?agree=true"))

    def test_values_are_decoded_strings(self):
        options = options_from_url("https://example.invalid/d?a=x%20y+z&b=&c=%D9%86&n=1")
        self.assertEqual(options, {"a": "x y z", "b": "", "c": NOON, "n": "1"})
        for value in options.values():
            self.assertIsInstance(value, str)

    def test_ignores_fragment(self):
        self.assertEqual(options_from_url("https://example.invalid/d?a=1#b=2"), {"a": "1"})

    def test_refuses_repeated_name(self):
        for query in ("rub=true&rub=false", "agree=true&agree=true", "a=1&b=2&a=1"):
            with self.subTest(query=query):
                with self.assertRaises(PackError) as caught:
                    options_from_url("https://example.invalid/d?" + query)
                self.assertIn("repeats the query parameter", str(caught.exception))
        with self.assertRaises(PackError) as caught:
            options_from_url("https://example.invalid/d?rub=1&rub=2")
        self.assertTrue(str(caught.exception).endswith(" rub"))

    def test_names_non_ascii_name_by_code_points(self):
        with self.assertRaises(PackError) as caught:
            options_from_url("https://example.invalid/d?%D9%86a=1&%D9%86a=2")
        message = str(caught.exception)
        message.encode("ascii")
        self.assertIn("U+0646 U+0061", message)

    def test_refuses_empty_name(self):
        with self.assertRaises(PackError) as caught:
            options_from_url("https://example.invalid/d?=1&a=2")
        self.assertIn("no name", str(caught.exception))

    def test_refuses_malformed_query(self):
        for query in ("a", "a=1&&b=2", "a=%FF"):
            with self.subTest(query=query):
                with self.assertRaises(PackError) as caught:
                    options_from_url("https://example.invalid/d?" + query)
                self.assertIn("malformed query", str(caught.exception))


class OptionProblemsTest(unittest.TestCase):
    def test_no_options_no_problems(self):
        self.assertEqual(option_problems(None, [("ayah 1:1", RUB)]), [])

    def test_unknown_options_are_not_checked(self):
        options = {"outType": "xml", "quranType": "uthmani"}
        self.assertEqual(option_problems(options, [("ayah 1:1", RUB)]), [])

    def test_agreeing_file(self):
        texts = [
            ("ayah 1:1", NOON + " " + PAUSES[0]),
            ("ayah 1:2", NOON + " " + SAJDA),
        ]
        options = options_from_url(TANZIL_STYLE)
        self.assertEqual(option_problems(options, texts), [])

    def test_false_reports_first_occurrence_and_total(self):
        texts = iter([
            ("ayah 1:1", NOON),
            ("ayah 1:2", RUB + " " + NOON + " " + RUB),
            ("ayah 1:3", RUB),
        ])
        problems = option_problems({"rub": "false"}, texts)
        self.assertEqual(problems, ["option rub=false, but ayah 1:2 holds U+06DE (3 in all)"])

    def test_false_reports_each_code_point(self):
        texts = [("ayah 2:1", PAUSES[3]), ("ayah 2:2", PAUSES[1] + PAUSES[3])]
        problems = option_problems({"marks": "false"}, texts)
        self.assertEqual(
            problems,
            [
                "option marks=false, but ayah 2:2 holds U+06D7 (1 in all)",
                "option marks=false, but ayah 2:1 holds U+06D9 (2 in all)",
            ],
        )

    def test_true_needs_one_occurrence(self):
        texts = [("ayah 1:1", NOON + " " + PAUSES[0])]
        problems = option_problems({"marks": "true", "sajdah": "true"}, texts)
        self.assertEqual(problems, ["option sajdah=true, but no text holds any of U+06E9"])
        problems = option_problems({"marks": "true"}, [("ayah 1:1", NOON)])
        self.assertEqual(
            problems,
            [
                "option marks=true, but no text holds any of U+06D6, U+06D7, U+06D8, "
                "U+06D9, U+06DA, U+06DB"
            ],
        )

    def test_small_high_seen_is_not_taken_for_a_pause_mark(self):
        # U+06DC is also written inside words, so it proves nothing about marks.
        self.assertEqual(len(option_problems({"marks": "true"}, [("ayah 1:1", "\u06dc")])), 1)
        self.assertEqual(option_problems({"marks": "false"}, [("ayah 1:1", "\u06dc")]), [])

    def test_every_pause_mark_satisfies_marks_true(self):
        for pause in PAUSES:
            with self.subTest(pause=hex(ord(pause))):
                self.assertEqual(option_problems({"marks": "true"}, [("ayah 1:1", pause)]), [])

    def test_other_values(self):
        for value in ("1", "TRUE", "", "yes", True, None):
            with self.subTest(value=value):
                problems = option_problems({"rub": value}, [])
                self.assertEqual(problems, ["option rub has a value other than true or false"])

    def test_messages_are_ascii_and_hide_the_text(self):
        texts = [("ayah 3:4", "zebra" + RUB + NOON)]
        for problem in option_problems({"rub": "false", "sajdah": "true"}, texts):
            problem.encode("ascii")
            self.assertNotIn("zebra", problem)

    def test_texts_read_once(self):
        texts = (pair for pair in [("ayah 1:1", SAJDA + RUB)])
        problems = option_problems({"sajdah": "true", "rub": "false", "marks": "true"}, texts)
        self.assertEqual(
            problems,
            [
                "option rub=false, but ayah 1:1 holds U+06DE (1 in all)",
                "option marks=true, but no text holds any of U+06D6, U+06D7, U+06D8, "
                "U+06D9, U+06DA, U+06DB",
            ],
        )


if __name__ == "__main__":
    unittest.main()
