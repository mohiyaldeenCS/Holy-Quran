"""Tests of the Tanzil text reader on synthetic bytes (Latin and `\\u` escapes)."""

import unittest

from hqpack.errors import PackError
from hqpack.tanzil_text import read_tanzil_text

DECLARATION = '<?xml version="1.0" encoding="utf-8" ?>\n'
NOTICE = "<!-- synthetic notice\n  line two -->\n"
SECRET = "Zqxjv"
PHRASE = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"
OPENER = "\u0628\u0633\u0645 \u062a\u062c\u0631\u064a\u0628\u064a"


def aya(index, text="lorem ipsum", extra=""):
    return '<aya index="%s" text="%s"%s/>' % (index, text, extra)


def sura(index, *ayat, name="Name"):
    return '<sura index="%s" name="%s">%s</sura>' % (index, name, "".join(ayat))


def document(*suras, before=NOTICE, after=""):
    body = "<quran>\n%s\n</quran>\n" % "\n".join(suras)
    return (DECLARATION + before + body + after).encode("utf-8")


def valid():
    return document(
        sura(1, aya(1, PHRASE), aya(2, "  two  spaces "), name=PHRASE),
        sura(
            2,
            aya(1, "first", ' bismillah="%s"' % OPENER),
            "<aya index='2' text='single quoted'></aya>",
            '<aya text="text before index" index="3">\n</aya>',
            name="Second",
        ),
    )


class TanzilTextTestCase(unittest.TestCase):
    def assert_refused(self, data, *needles):
        with self.assertRaises(PackError) as caught:
            read_tanzil_text(data)
        message = str(caught.exception)
        self.assertTrue(message.isascii(), message)
        self.assertNotIn(SECRET, message)
        self.assertTrue(message.startswith("Tanzil text: "), message)
        for needle in needles:
            self.assertIn(needle, message)
        return message


class AcceptedTest(TanzilTextTestCase):
    def test_reads_suras_ayat_basmala_and_notice(self):
        data = valid()
        text = read_tanzil_text(data)
        self.assertEqual([s.index for s in text.suras], [1, 2])
        self.assertEqual(text.suras[0].name.value, PHRASE)
        first, second = text.suras
        self.assertEqual([(a.surah, a.number) for a in first.ayat], [(1, 1), (1, 2)])
        self.assertEqual([a.number for a in second.ayat], [1, 2, 3])
        self.assertEqual(first.ayat[0].text.value, PHRASE)
        self.assertEqual(first.ayat[1].text.value, "  two  spaces ")
        self.assertIsNone(first.ayat[0].basmala)
        self.assertEqual(second.ayat[0].basmala.value, OPENER)
        self.assertEqual(second.ayat[1].text.value, "single quoted")
        self.assertEqual(text.notice.value, " synthetic notice\n  line two ")

    def test_every_value_is_the_source_bytes(self):
        data = valid()
        text = read_tanzil_text(data)
        found = [text.notice]
        for s in text.suras:
            found.append(s.name)
            for a in s.ayat:
                found.append(a.text)
                if a.basmala is not None:
                    found.append(a.basmala)
        self.assertEqual(len(found), 9)
        for value in found:
            self.assertEqual(
                data[value.offset : value.offset + value.length],
                value.value.encode("utf-8"),
            )

    def test_notice_after_the_root(self):
        text = read_tanzil_text(
            document(sura(1, aya(1)), before="", after="<!-- after -->\n")
        )
        self.assertEqual(text.notice.value, " after ")


class RefusalTest(TanzilTextTestCase):
    def test_root_other_than_quran(self):
        data = (DECLARATION + NOTICE + "<koran><sura/></koran>").encode("utf-8")
        self.assert_refused(data, "root element")

    def test_root_with_attribute(self):
        data = document(sura(1, aya(1))).replace(b"<quran>", b'<quran type="x">')
        self.assert_refused(data, "unknown attribute type on quran")

    def test_no_suras(self):
        self.assert_refused(document(), "without sura")
        data = (DECLARATION + NOTICE + "<quran/>").encode("utf-8")
        self.assert_refused(data, "without sura")

    def test_unknown_element_in_quran(self):
        self.assert_refused(document(sura(1, aya(1)), "<surah/>"), "surah inside quran")

    def test_sura_without_name(self):
        data = document('<sura index="1">%s</sura>' % aya(1))
        self.assert_refused(data, "sura 1 without the name attribute")

    def test_sura_without_index(self):
        data = document('<sura name="n">%s</sura>' % aya(1))
        self.assert_refused(data, "sura 1 without the index")

    def test_sura_unknown_attribute(self):
        data = document(
            '<sura index="1" name="n" ename="%s">%s</sura>' % (SECRET, aya(1))
        )
        self.assert_refused(data, "unknown attribute ename on sura 1")

    def test_sura_without_ayat(self):
        self.assert_refused(document(sura(1)), "sura 1 without aya")
        data = document('<sura index="1" name="n"/>')
        self.assert_refused(data, "sura 1 without aya")

    def test_unknown_element_in_sura(self):
        self.assert_refused(document(sura(1, aya(1), "<ayah/>")), "ayah inside sura 1")

    def test_aya_without_text(self):
        self.assert_refused(
            document(sura(1, '<aya index="1"/>')), "sura 1 aya 1 without the text"
        )

    def test_aya_without_index(self):
        self.assert_refused(
            document(sura(1, '<aya text="t"/>')), "sura 1 aya 1 without the index"
        )

    def test_aya_unknown_attribute(self):
        self.assert_refused(
            document(sura(1, aya(1, extra=' basmala="%s"' % SECRET))),
            "unknown attribute basmala on sura 1 aya 1",
        )

    def test_aya_with_child(self):
        nested = '<aya index="1" text="t"><aya index="1" text="t"/></aya>'
        data = document(sura(1, nested))
        self.assert_refused(data, "inside sura 1 aya 1")

    def test_bismillah_on_aya_two(self):
        data = document(sura(1, aya(1), aya(2, extra=' bismillah="%s"' % SECRET)))
        self.assert_refused(data, "bismillah attribute on sura 1 aya 2")

    def test_aya_index_forms(self):
        for index in ("01", " 1", "1 ", "+1", "\u0661", "2"):
            self.assert_refused(
                document(sura(1, aya(index))), "sura 1 aya 1 has an index other than 1"
            )

    def test_aya_index_gap(self):
        self.assert_refused(
            document(sura(1, aya(1), aya(3))), "sura 1 aya 2 has an index other than 2"
        )

    def test_sura_index_gap_and_forms(self):
        self.assert_refused(
            document(sura(1, aya(1)), sura(3, aya(1))),
            "sura 2 has an index other than 2",
        )
        self.assert_refused(document(sura("01", aya(1))), "sura 1 has an index")

    def test_ayat_restart_in_each_sura(self):
        self.assert_refused(
            document(sura(1, aya(1)), sura(2, aya(2))), "sura 2 aya 1 has an index"
        )

    def test_no_comment(self):
        self.assert_refused(document(sura(1, aya(1)), before=""), "0 comments")

    def test_two_comments(self):
        self.assert_refused(
            document(sura(1, aya(1)), after="<!-- %s -->" % SECRET), "2 comments"
        )

    def test_strict_xml_refusals_are_prefixed(self):
        data = document(sura(1, aya(1, SECRET + "&amp;")))
        self.assert_refused(data, "reference")


if __name__ == "__main__":
    unittest.main()
