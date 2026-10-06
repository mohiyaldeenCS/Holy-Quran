#!/usr/bin/env python3
"""Build offline, view-only pages for the approved identity.

The identity files in design/ cannot simply be opened in a browser:

* each design-system/components/<Name>/preview.html is a fragment that expects the
  tokens, the stylesheet, React and the component bundle to be loaded already;
* each identity-boards/<Name>.dc.html asks for a script that is not part of the
  export and takes its fonts from Google Fonts.

This script writes complete pages into design/preview/out/ that load everything
from the files in design/, including the identity's own fonts, and an index page.
Nothing in design/ is changed. The output is ignored by Git and is rebuilt at any
time:

    python3 design/preview/build.py        (Windows: py design\\preview\\build.py)

Then open design/preview/out/index.html in a browser.
"""
import html
import pathlib
import re
import shutil

HERE = pathlib.Path(__file__).resolve().parent
DESIGN = HERE.parent
DS = DESIGN / "design-system"
BOARDS = DESIGN / "identity-boards"
OUT = HERE / "out"
UP = "../../../design-system"

COMPONENT_HEAD = """<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="stylesheet" href="{up}/tokens.css">
<link rel="stylesheet" href="{up}/components/bundle.css">
<style>
  body {{ margin: 0; padding: 24px; background: var(--ground); color: var(--ink);
         font-family: var(--font-sans); }}
</style>
<script src="{up}/components/lib/react.production.min.js"></script>
<script src="{up}/components/lib/react-dom.production.min.js"></script>
<script src="{up}/components/bundle.js"></script>
</head>
"""

INDEX_HEAD = """<!doctype html>
<html lang="en" dir="ltr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Identity previews</title>
<link rel="stylesheet" href="../../design-system/tokens.css">
<style>
  body { margin: 0; padding: 24px; background: var(--ground); color: var(--ink);
         font-family: var(--font-sans); }
  h1 { font-size: 22px; }
  h2 { font-size: 18px; margin: 32px 0 8px; }
  h3 { font-size: 15px; margin: 24px 0 8px; }
  h3 small { color: var(--ink-muted); font-weight: 400; margin-inline-start: 8px; }
  ul { padding-inline-start: 20px; line-height: 2; }
  a { color: var(--primary); }
  iframe { width: 100%; border: 1px solid var(--line); border-radius: 12px;
           background: var(--ground); }
</style>
</head>
<body>
<h1>Identity previews (generated, view only)</h1>
"""


def build_components():
    out = OUT / "components"
    out.mkdir(parents=True)
    cards = []
    for src in sorted(DS.glob("components/*/preview.html")):
        name = src.parent.name
        text = src.read_text(encoding="utf-8")
        meta = re.search(r'@dsCard group="([^"]*)" height=(\d+)', text)
        group, height = (meta.group(1), int(meta.group(2))) if meta else ("", 200)
        body = re.search(r"<body[^>]*>(.*)</body>", text, flags=re.S)
        if not body:
            raise SystemExit("no <body> in %s" % src)
        page = (
            COMPONENT_HEAD.format(title=html.escape(name), up=UP)
            + "<body>"
            + body.group(1)
            + "</body>\n</html>\n"
        )
        (out / (name + ".html")).write_text(page, encoding="utf-8")
        cards.append((group, name, height))
    return cards


def build_boards():
    out = OUT / "boards"
    out.mkdir(parents=True)
    names = []
    local_fonts = '<link rel="stylesheet" href="%s/tokens.css">' % UP
    for src in sorted(BOARDS.glob("*.dc.html")):
        text = src.read_text(encoding="utf-8")
        text, scripts = re.subn(r'<script src="\./support\.js"></script>\s*', "", text)
        text, fonts = re.subn(
            r'<link rel="stylesheet" href="https://fonts\.googleapis\.com/[^"]*">',
            lambda _: local_fonts,
            text,
        )
        if scripts != 1 or fonts != 1:
            raise SystemExit("unexpected markup in %s" % src)
        name = src.name[: -len(".dc.html")]
        (out / (name + ".html")).write_text(text, encoding="utf-8")
        title = re.search(r"<title>(.*?)</title>", text, flags=re.S)
        names.append((name, title.group(1).strip() if title else name))
    return names


def build_index(cards, boards):
    parts = [INDEX_HEAD, "<h2>Identity boards</h2>\n<ul>"]
    for name, title in boards:
        parts.append(
            '<li><a href="boards/%s.html">%s</a> <span dir="rtl">%s</span></li>'
            % (name, html.escape(name), html.escape(title))
        )
    parts.append("</ul>\n<h2>Design-system components</h2>")
    for group, name, height in cards:
        parts.append(
            '<section><h3><a href="components/%s.html">%s</a> <small dir="rtl">%s</small></h3>'
            '<iframe src="components/%s.html" title="%s" style="height:%dpx"></iframe></section>'
            % (name, html.escape(name), html.escape(group), name, html.escape(name), height + 60)
        )
    parts.append("</body>\n</html>\n")
    (OUT / "index.html").write_text("\n".join(parts), encoding="utf-8")


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    cards = build_components()
    boards = build_boards()
    build_index(cards, boards)
    print("wrote %d component pages, %d boards and index.html to %s" % (len(cards), len(boards), OUT))


if __name__ == "__main__":
    main()
