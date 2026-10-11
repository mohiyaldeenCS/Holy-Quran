"""Tests of the strict XML reader on synthetic bytes (Latin and `\\u` escapes)."""

import unittest

from hqpack import strict_xml
from hqpack.errors import PackError

DECLARATION = '<?xml version="1.0" encoding="utf-8" ?>\n'
SECRET = "Zqxjv"
ARABIC = "\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a"


def xml(body, declaration=DECLARATION):
    return (declaration + body).encode("utf-8")


def values(document):
    found = list(document.comments)
    pending = [document.root]
    while pending:
        element = pending.pop()
        found.extend(element.attributes.values())
        pending.extend(element.children)
    return found


class StrictXmlTestCase(unittest.TestCase):
    def assert_exact(self, data, document):
        for value in values(document):
            self.assertEqual(
                data[value.offset : value.offset + value.length],
                value.value.encode("utf-8"),
            )

    def assert_refused(self, data, *needles):
        with self.assertRaises(PackError) as caught:
            strict_xml.parse(data)
        message = str(caught.exception)
        self.assertTrue(message.isascii(), message)
        self.assertNotIn(SECRET, message)
        for needle in needles:
            self.assertIn(needle, message)
        return message


class AcceptedTest(StrictXmlTestCase):
    def test_round_trip_keeps_every_value_and_offset(self):
        data = xml(
            "<!-- a notice -->\n"
            '<root first="  %s  b " second=\'%s\'>\n'
            '  <child name="x"/>\n'
            "  <child name='y'></child>\n"
            "  <child name=\"z\">\n    <leaf a=\"1\" />\n  </child>\n"
            "</root>\n<!-- after\n\tthe root -->\n" % (SECRET, ARABIC)
        )
        document = strict_xml.parse(data)
        root = document.root
        self.assertEqual(root.name, "root")
        self.assertEqual(list(root.attributes), ["first", "second"])
        self.assertEqual(root.attributes["first"].value, "  %s  b " % SECRET)
        self.assertEqual(root.attributes["second"].value, ARABIC)
        self.assertEqual([c.name for c in root.children], ["child"] * 3)
        self.assertEqual(root.children[2].children[0].name, "leaf")
        self.assertEqual(root.children[0].children, [])
        self.assertEqual(root.offset, data.index(b"<root"))
        self.assertEqual(
            [c.value for c in document.comments], [" a notice ", " after\n\tthe root "]
        )
        self.assertEqual(document.comments[0].offset, data.index(b" a notice"))
        self.assert_exact(data, document)

    def test_combining_marks_and_decomposed_letters_stay_distinct(self):
        decomposed = "\u0627\u0653 e\u0301 \u0646\u064e"
        precomposed = "\u0622 \u00e9 \u0646\u064e"
        data = xml('<r a="%s" b="%s"/>' % (decomposed, precomposed))
        document = strict_xml.parse(data)
        self.assertEqual(document.root.attributes["a"].value, decomposed)
        self.assertEqual(document.root.attributes["b"].value, precomposed)
        self.assertNotEqual(decomposed, precomposed)
        self.assert_exact(data, document)

    def test_supplementary_character_offsets(self):
        data = xml('<r a="\U00010000x" b="y"/>')
        document = strict_xml.parse(data)
        self.assertEqual(document.root.attributes["a"].length, 5)
        self.assert_exact(data, document)

    def test_declaration_is_optional_and_its_forms(self):
        for declaration in (
            "",
            '<?xml version="1.0"?>',
            "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>",
            '<?xml version="1.0" standalone="no" ?>',
        ):
            document = strict_xml.parse(xml("<r/>", declaration))
            self.assertEqual(document.root.name, "r")

    def test_white_space_around_equals_and_in_end_tags(self):
        document = strict_xml.parse(xml('<r\n\ta = "1"\r\n></r >'))
        self.assertEqual(document.root.attributes["a"].value, "1")


class DeclarationRefusalTest(StrictXmlTestCase):
    def test_byte_order_mark(self):
        self.assert_refused(b"\xef\xbb\xbf" + xml("<r/>"), "byte order mark", "byte 0")

    def test_other_version(self):
        self.assert_refused(xml("<r/>", '<?xml version="1.1"?>'), "version")

    def test_missing_version(self):
        self.assert_refused(xml("<r/>", '<?xml encoding="utf-8"?>'), "declaration")

    def test_other_encoding(self):
        self.assert_refused(
            xml("<r/>", '<?xml version="1.0" encoding="latin-1"?>'), "encoding"
        )

    def test_invalid_standalone(self):
        self.assert_refused(
            xml("<r/>", '<?xml version="1.0" standalone="maybe"?>'), "standalone"
        )

    def test_attributes_out_of_order(self):
        self.assert_refused(
            xml("<r/>", '<?xml encoding="utf-8" version="1.0"?>'), "misordered"
        )

    def test_unknown_attribute(self):
        self.assert_refused(xml("<r/>", '<?xml version="1.0" zz="1"?>'), "unknown")

    def test_declaration_not_at_byte_zero(self):
        self.assert_refused(xml("<r/>", " " + DECLARATION), "processing instruction")

    def test_unterminated_declaration(self):
        self.assert_refused(b'<?xml version="1.0"', "unterminated")


class MarkupRefusalTest(StrictXmlTestCase):
    def test_processing_instructions(self):
        for data in (
            xml("<r/>", '<?xml-stylesheet href="a"?>'),
            xml('<?app x="1"?><r/>'),
            xml("<r><?app x?></r>"),
            xml("<r/><?app x?>"),
        ):
            self.assert_refused(data, "processing instruction")

    def test_doctype(self):
        self.assert_refused(
            xml("<!DOCTYPE r><r/>"), "DOCTYPE", "byte %d" % len(DECLARATION)
        )

    def test_markup_declaration_inside(self):
        self.assert_refused(xml("<r><!ELEMENT r ANY></r>"), "markup declaration")

    def test_cdata(self):
        self.assert_refused(xml("<r><![CDATA[%s]]></r>" % SECRET), "CDATA")

    def test_character_data(self):
        for body in (
            "<r>%s</r>" % SECRET,
            "<r><a/>%s<a/></r>" % SECRET,
            "%s<r/>" % SECRET,
            "<r/>%s" % SECRET,
            "<r>\u00a0</r>",
        ):
            self.assert_refused(xml(body))

    def test_reference_as_content(self):
        self.assert_refused(xml("<r>&amp;</r>"), "reference")

    def test_comment_inside_root(self):
        self.assert_refused(xml("<r><!-- %s --></r>" % SECRET), "comment inside")

    def test_double_hyphen_in_comment(self):
        self.assert_refused(xml("<!-- a -- %s --><r/>" % SECRET), '"--"')
        self.assert_refused(xml("<!-- %s ---><r/>" % SECRET), '"--"')

    def test_unterminated_comment(self):
        self.assert_refused(xml("<r/><!-- %s" % SECRET), "unterminated comment")

    def test_empty_comment(self):
        self.assert_refused(xml("<!----><r/>"), "empty")

    def test_control_character_in_comment(self):
        self.assert_refused(xml("<!-- \x01 --><r/>"), "U+0001")

    def test_content_after_root(self):
        self.assert_refused(xml("<r/><r/>"), "after the root")

    def test_no_root(self):
        self.assert_refused(xml("<!-- n -->"), "no root")

    def test_mismatched_end_tag(self):
        self.assert_refused(xml("<r><a></b></r>"), "does not match a")

    def test_unterminated_element(self):
        self.assert_refused(xml("<r><a/>"), "unterminated element r")

    def test_unterminated_tag(self):
        self.assert_refused(xml('<r a="1"'), "unterminated tag")

    def test_unterminated_end_tag(self):
        self.assert_refused(xml("<r></r"), "end tag")

    def test_element_names(self):
        for body in ("<R/>", "<r><Child/></r>", "<r1/>", "<x:r/>", "< r/>", "<r-a/>"):
            self.assert_refused(xml(body), "element name")

    def test_slash_without_closing_bracket(self):
        self.assert_refused(xml('<r a="1"/ >'), "unexpected byte")


class AttributeRefusalTest(StrictXmlTestCase):
    def test_reference_in_value(self):
        for reference in ("&amp;", "&#x41;", "&#65;", "&"):
            self.assert_refused(xml('<r a="%s%s"/>' % (SECRET, reference)), "reference")

    def test_less_than_in_value(self):
        self.assert_refused(xml('<r a="%s<"/>' % SECRET), '"<"')

    def test_tab_and_line_breaks_in_value(self):
        for c in ("\t", "\n", "\r"):
            self.assert_refused(xml('<r a="%s%s"/>' % (SECRET, c)), "tab or line break")

    def test_other_control_characters(self):
        for c in ("\x00", "\x01", "\x1f"):
            self.assert_refused(xml('<r a="%s%s"/>' % (SECRET, c)), "control character")

    def test_characters_xml_does_not_allow(self):
        for c in ("\ufffe", "\uffff"):
            message = self.assert_refused(xml('<r a="%s%s"/>' % (SECRET, c)))
            self.assertIn("U+%04X" % ord(c), message)
            self.assertIn("byte %d" % (len(DECLARATION) + 6 + len(SECRET)), message)

    def test_malformed_utf8(self):
        prefix = xml('<r a="%s' % SECRET)
        for bad in (b"\xff", b"\xc3", b"\xed\xa0\x80", b"\xc0\xaf", b"\x80"):
            message = self.assert_refused(prefix + bad + b'"/>', "malformed UTF-8")
            self.assertIn("byte %d" % len(prefix), message)

    def test_malformed_utf8_outside_values(self):
        self.assert_refused(xml("<r/>") + b"\xfe", "malformed UTF-8")

    def test_empty_value(self):
        self.assert_refused(xml('<r a=""/>'), "empty value")

    def test_value_beginning_with_bom(self):
        self.assert_refused(xml('<r a="\ufeff%s"/>' % SECRET), "U+FEFF")

    def test_repeated_attribute(self):
        self.assert_refused(xml('<r a="1" a="2"/>'), "repeated attribute a")

    def test_attribute_names(self):
        for body in ('<r A="1"/>', '<r x:a="1"/>', '<r a1="1"/>', '<r _a="1"/>'):
            self.assert_refused(xml(body), "attribute name")

    def test_unquoted_value(self):
        self.assert_refused(xml("<r a=%s/>" % SECRET), "unquoted")

    def test_mismatched_quotes(self):
        self.assert_refused(xml("<r a=\"%s'/>" % SECRET), "unterminated attribute")

    def test_missing_equals(self):
        self.assert_refused(xml('<r a "1"/>'), "without =")

    def test_no_space_between_attributes(self):
        self.assert_refused(xml('<r a="1"b="2"/>'), "unexpected byte")


if __name__ == "__main__":
    unittest.main()
