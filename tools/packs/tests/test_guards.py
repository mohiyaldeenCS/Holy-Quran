"""Guards over the pipeline's own code: PRD 9.4, "no Unicode normalisation on text fields", and D-035."""

import ast
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PIPELINE = sorted(ROOT.glob("hqpack/*.py")) + [ROOT / "pack.py", ROOT / "synthetic_source.py"]
EVERY_PY = sorted(ROOT.rglob("*.py"))

TEXT_CHANGING_METHODS = {"normalize", "casefold"}
LOSSY_ERROR_HANDLERS = {"replace", "ignore", "surrogateescape", "backslashreplace"}
# A tolerant XML parser expands references and folds white space in values.
TOLERANT_PARSERS = {"xml", "pyexpat"}
LOCAL = {"hqpack", "tests", "synthetic_source"}
# The parts of the html module that decode entities or repair markup (D-185).
HTML_DECODERS = {"unescape", "parser", "entities", "HTMLParser"}


def _tree(path):
    return ast.parse(path.read_text(encoding="utf-8"), filename=str(path))


def _imports(tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                yield alias.name.split(".")[0]
        elif isinstance(node, ast.ImportFrom) and node.level == 0:
            yield node.module.split(".")[0]


class GuardTest(unittest.TestCase):
    def test_no_text_changing_call_in_the_pipeline(self):
        for path in PIPELINE:
            for node in ast.walk(_tree(path)):
                if isinstance(node, ast.Attribute):
                    self.assertNotIn(node.attr, TEXT_CHANGING_METHODS, "%s:%d" % (path.name, node.lineno))
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr in (
                    "decode",
                    "encode",
                ):
                    arguments = list(node.args) + [k.value for k in node.keywords]
                    for argument in arguments:
                        if isinstance(argument, ast.Constant):
                            self.assertNotIn(argument.value, LOSSY_ERROR_HANDLERS, "%s:%d" % (path.name, node.lineno))

    def test_no_html_decoder_in_the_pipeline(self):
        # The tafsir conversion is a closed tokenizer; html.escape (review_html.py) only writes a page.
        for path in sorted(ROOT.glob("hqpack/*.py")):
            for node in ast.walk(_tree(path)):
                where = "%s:%d" % (path.name, getattr(node, "lineno", 0))
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        self.assertNotIn(alias.name, ("html.parser", "html.entities"), where)
                elif isinstance(node, ast.ImportFrom) and (node.module or "").split(".")[0] == "html":
                    self.assertEqual(node.module, "html", where)
                    for alias in node.names:
                        self.assertNotIn(alias.name, HTML_DECODERS, where)
                elif isinstance(node, ast.Attribute) and node.attr in HTML_DECODERS:
                    self.assertFalse(isinstance(node.value, ast.Name) and node.value.id == "html", where)
                    self.assertNotEqual(node.attr, "unescape", where)
                elif isinstance(node, ast.Name):
                    self.assertNotIn(node.id, ("unescape", "HTMLParser"), where)

    def test_no_tolerant_xml_parser(self):
        for path in PIPELINE:
            for module in _imports(_tree(path)):
                self.assertNotIn(module, TOLERANT_PARSERS, "%s imports %s" % (path.name, module))

    def test_every_python_file_is_ascii(self):
        # Non-ASCII test data is written as \u escapes, so no editor can recompose it.
        for path in EVERY_PY:
            self.assertTrue(path.read_bytes().isascii(), "%s holds a non-ASCII byte" % path.relative_to(ROOT))

    @unittest.skipUnless(hasattr(sys, "stdlib_module_names"), "needs Python 3.10 to list the standard library")
    def test_standard_library_only(self):
        allowed = set(sys.stdlib_module_names) | LOCAL
        for path in EVERY_PY:
            for module in _imports(_tree(path)):
                self.assertIn(module, allowed, "%s imports %s" % (path.relative_to(ROOT), module))


if __name__ == "__main__":
    unittest.main()
