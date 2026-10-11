"""Tests of the Tanzil metadata reader on synthetic bytes (Latin and `\\u` escapes)."""

import unittest

from hqpack.errors import PackError
from hqpack.tanzil_metadata import read_tanzil_metadata

DECLARATION = '<?xml version="1.0" encoding="utf-8" ?>\n'
NOTICE = "<!-- synthetic notice -->\n"
ROOT = '<quran type="metadata" version="1.0" copyright="c" license="l">'
SECRET = "Zqxjv"
PHRASE = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"

SURA = (
    '<sura index="%s" ayas="%s" start="%s" name="%s" tname="Tname %s" '
    'ename="The  Ename" type="%s" order="%s" rukus="%s"/>'
)


def point(item, index, sura, aya):
    return '<%s index="%s" sura="%s" aya="%s"/>' % (item, index, sura, aya)


def containers():
    return [
        (
            "suras",
            ' alias="chapters"',
            [
                SURA % (1, 7, 0, PHRASE, "A", "Meccan", 5, 1),
                SURA % (2, 3, 7, "Second", "B", "Medinan", 87, 2),
            ],
        ),
        ("juzs", ' alias="juz"', [point("juz", 1, 1, 1), point("juz", 2, 2, 2)]),
        ("hizbs", ' alias="quarters"', [point("quarter", 1, 1, 1)]),
        ("manzils", ' alias="stations"', [point("manzil", 1, 1, 1)]),
        (
            "rukus",
            ' alias="sections"',
            [point("ruku", 1, 1, 1), point("ruku", 2, 2, 1), point("ruku", 3, 2, 3)],
        ),
        ("pages", "", [point("page", 1, 1, 1), point("page", 2, 2, 1)]),
        (
            "sajdas",
            "",
            [
                '<sajda index="1" sura="2" aya="3" type="recommended"/>',
                '<sajda index="2" sura="2" aya="1" type="obligatory"/>',
            ],
        ),
    ]


def document(parts=None, root=ROOT, before=NOTICE, after=""):
    body = "".join(
        "  <%s%s>\n    %s\n  </%s>\n" % (name, attrs, "\n    ".join(items), name)
        for name, attrs, items in (containers() if parts is None else parts)
    )
    return (DECLARATION + before + root + "\n" + body + "</quran>\n" + after).encode(
        "utf-8"
    )


def replaced(old, new):
    data = document()
    assert data.count(old.encode("utf-8")) == 1
    return data.replace(old.encode("utf-8"), new.encode("utf-8"))


class TanzilMetadataTestCase(unittest.TestCase):
    def assert_refused(self, data, *needles):
        with self.assertRaises(PackError) as caught:
            read_tanzil_metadata(data)
        message = str(caught.exception)
        self.assertTrue(message.isascii(), message)
        self.assertNotIn(SECRET, message)
        self.assertTrue(message.startswith("Tanzil metadata: "), message)
        for needle in needles:
            self.assertIn(needle, message)
        return message


class AcceptedTest(TanzilMetadataTestCase):
    def test_reads_every_list(self):
        data = document()
        meta = read_tanzil_metadata(data)
        first, second = meta.suras
        self.assertEqual(
            (first.index, first.ayas, first.start, first.type),
            (1, 7, 0, "Meccan"),
        )
        self.assertEqual((first.order, first.rukus), (5, 1))
        self.assertEqual(
            (second.index, second.ayas, second.rukus),
            (2, 3, 2),
        )
        self.assertEqual((second.start, second.type, second.order), (7, "Medinan", 87))
        self.assertEqual(first.name.value, PHRASE)
        self.assertEqual(first.tname.value, "Tname A")
        self.assertEqual(first.ename.value, "The  Ename")
        self.assertEqual(
            [(p.index, p.sura, p.aya) for p in meta.juzs], [(1, 1, 1), (2, 2, 2)]
        )
        self.assertEqual(len(meta.quarters), 1)
        self.assertEqual(len(meta.manzils), 1)
        self.assertEqual([p.aya for p in meta.rukus], [1, 1, 3])
        self.assertEqual([p.sura for p in meta.pages], [1, 2])
        self.assertEqual(
            [(s.index, s.sura, s.aya, s.type) for s in meta.sajdas],
            [(1, 2, 3, "recommended"), (2, 2, 1, "obligatory")],
        )
        self.assertEqual(meta.notice.value, " synthetic notice ")
        for s in meta.suras:
            for value in (s.name, s.tname, s.ename):
                self.assertEqual(
                    data[value.offset : value.offset + value.length],
                    value.value.encode("utf-8"),
                )
        notice = meta.notice
        self.assertEqual(
            data[notice.offset : notice.offset + notice.length], b" synthetic notice "
        )

    def test_root_without_attributes(self):
        meta = read_tanzil_metadata(document(root="<quran>"))
        self.assertEqual(len(meta.suras), 2)

    def test_sura_type_returned_as_given(self):
        meta = read_tanzil_metadata(replaced('type="Medinan"', 'type="Other"'))
        self.assertEqual(meta.suras[1].type, "Other")

    def test_notice_after_the_root(self):
        meta = read_tanzil_metadata(document(before="", after="<!-- n -->"))
        self.assertEqual(meta.notice.value, " n ")


class StructureRefusalTest(TanzilMetadataTestCase):
    def test_root_other_than_quran(self):
        data = document().replace(b"<quran ", b"<qurans ").replace(
            b"</quran>", b"</qurans>"
        )
        self.assert_refused(data, "root element")

    def test_root_unknown_attribute(self):
        self.assert_refused(
            document(root='<quran kind="%s">' % SECRET),
            "unknown attribute kind on quran",
        )

    def test_containers_out_of_order(self):
        parts = containers()
        parts[1], parts[2] = parts[2], parts[1]
        self.assert_refused(document(parts), "published order")

    def test_container_missing(self):
        parts = [p for p in containers() if p[0] != "manzils"]
        self.assert_refused(document(parts), "0 manzils elements")

    def test_container_repeated(self):
        parts = containers()
        parts.append(parts[3])
        self.assert_refused(document(parts), "2 manzils elements")

    def test_unknown_container(self):
        parts = containers() + [("quarters", "", [point("quarter", 1, 1, 1)])]
        self.assert_refused(document(parts), "quarters inside quran")

    def test_container_unknown_attribute(self):
        self.assert_refused(
            replaced(' alias="juz"', ' name="%s"' % SECRET),
            "unknown attribute name on juzs",
        )

    def test_empty_container(self):
        parts = containers()
        parts[5] = ("pages", "", [])
        self.assert_refused(document(parts), "pages without page")
        data = replaced(
            "<pages>\n    %s\n    %s\n  </pages>"
            % (point("page", 1, 1, 1), point("page", 2, 2, 1)),
            "<pages/>",
        )
        self.assert_refused(data, "pages without page")

    def test_wrong_item_element(self):
        self.assert_refused(
            replaced(point("quarter", 1, 1, 1), point("hizb", 1, 1, 1)),
            "hizb inside hizbs",
        )

    def test_item_with_child(self):
        self.assert_refused(
            replaced(
                point("manzil", 1, 1, 1),
                '<manzil index="1" sura="1" aya="1"><x/></manzil>',
            ),
            "inside manzil 1",
        )

    def test_no_comment(self):
        self.assert_refused(document(before=""), "0 comments")

    def test_two_comments(self):
        self.assert_refused(document(after="<!-- %s -->" % SECRET), "2 comments")


class ItemRefusalTest(TanzilMetadataTestCase):
    def test_missing_item_attribute(self):
        self.assert_refused(
            replaced(point("juz", 2, 2, 2), '<juz index="2" sura="2"/>'),
            "juz 2 without the aya",
        )
        data = replaced(' tname="Tname B"', "")
        self.assert_refused(data, "sura 2 without the tname")

    def test_extra_item_attribute(self):
        self.assert_refused(
            replaced(
                point("page", 2, 2, 1), '<page index="2" sura="2" aya="1" line="1"/>'
            ),
            "unknown attribute line on page 2",
        )

    def test_index_out_of_order(self):
        self.assert_refused(
            replaced(point("ruku", 3, 2, 3), point("ruku", 4, 2, 3)),
            "ruku 3 has an index other than 3",
        )

    def test_index_with_leading_zero(self):
        self.assert_refused(
            replaced(point("juz", 2, 2, 2), point("juz", "02", 2, 2)), "juz 2: index"
        )

    def test_integer_forms(self):
        for bad in ("+2", "-2", " 2", "2 ", "02", "2.0", "\u0662", "0x2"):
            self.assert_refused(
                replaced(point("juz", 2, 2, 2), point("juz", 2, bad, 2)),
                "juz 2: sura is not a decimal integer >= 1",
            )

    def test_start_zero_accepted_but_not_zero_zero(self):
        self.assertEqual(read_tanzil_metadata(document()).suras[0].start, 0)
        self.assert_refused(replaced('start="0"', 'start="00"'), "sura 1: start")

    def test_zero_counts_refused(self):
        self.assert_refused(replaced('ayas="7"', 'ayas="0"'), "sura 1: ayas")
        self.assert_refused(replaced('order="5"', 'order="0"'), "sura 1: order")
        self.assert_refused(replaced('rukus="2"', 'rukus="0"'), "sura 2: rukus")
        self.assert_refused(
            replaced(point("page", 2, 2, 1), point("page", 2, 2, 0)), "page 2: aya"
        )

    def test_unknown_sajda_type(self):
        self.assert_refused(
            replaced('type="obligatory"', 'type="%s"' % SECRET),
            "sajda 2 has an unknown type",
        )
        self.assert_refused(
            replaced('type="recommended"', 'type="Recommended"'),
            "sajda 1 has an unknown type",
        )


if __name__ == "__main__":
    unittest.main()
