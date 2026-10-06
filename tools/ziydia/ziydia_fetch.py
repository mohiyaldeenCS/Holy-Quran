#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ziydia_fetch.py

Reads books from ziydia.com (with the site owner's permission) slowly and saves
their text page by page in a structured form.

Needs Python 3.8+ only. No extra packages.

USAGE
  1) List the books of a category (default: 5 = Tafsir and Quran sciences):
         py ziydia_fetch.py list
         py ziydia_fetch.py list 5 19

  2) Short test first (30 pages of each book), then upload the result:
         py ziydia_fetch.py books 183 466 --max-pages 30

  3) Full run for chosen books (can be stopped with Ctrl+C and resumed later
     with the same command; it continues where it stopped):
         py ziydia_fetch.py books 183 466 471

  4) Pack everything into one zip to upload:
         py ziydia_fetch.py pack

OUTPUT (folder "ziydia_out")
  books_index.csv              list of books found by "list"
  book_<id>/meta.json          title, author, publisher/edition lines, category
  book_<id>/toc.json           table of contents entries
  book_<id>/pages.jsonl        one line per page: part, page, chapter, html, text
  book_<id>/state.json         where to resume
"""

import csv
import gzip
import hashlib
import html as htmllib
import http.client
import io
import json
import os
import random
import re
import ssl
import sys
import time
import zipfile
import zlib
from urllib.parse import urljoin, urlparse

# ----------------------------------------------------------------------------
# Settings
# ----------------------------------------------------------------------------

HOST = "ziydia.com"
BASE = "https://" + HOST
OUT = "ziydia_out"

DELAY = 3.0            # seconds between requests (plus a little random extra)
TIMEOUT = 60           # seconds per request
RETRIES = 7            # attempts per page before giving up for this run
MAX_FAILS_IN_ROW = 3   # stop a book after this many pages fail completely

# Optional e-mail so the site owner can recognise the requests. May stay empty.
CONTACT = ""

# Contemporary works. They are left out of a run unless you pass
# --include-skipped, so that a long run does not fetch them by accident. The
# product owner confirmed on 2026-10-07 that the permission covers them.
SKIP_IDS = {
    204,  # I'rab al-Quran wa Bayanuh (Darwish)
    425,  # Al-Jadwal fi I'rab al-Quran (Safi)
    74,   # Zubar min al-Fawa'id al-Qur'aniyya (contemporary)
    108,  # Al-Fiqh al-Qur'ani (contemporary)
    102,  # Muhadarat Ramadaniyya (contemporary)
}

USER_AGENT = "QuranAppStudy/0.2 (non-profit Quran app; permitted by site owner%s)" % (
    "; contact: " + CONTACT if CONTACT else ""
)

# ----------------------------------------------------------------------------
# Network: one kept-alive connection, retries with growing waits
# ----------------------------------------------------------------------------


class Session:
    def __init__(self):
        self.conn = None
        self.last = 0.0

    def _connect(self):
        self.close()
        self.conn = http.client.HTTPSConnection(
            HOST, timeout=TIMEOUT, context=ssl.create_default_context()
        )

    def close(self):
        try:
            if self.conn:
                self.conn.close()
        except Exception:
            pass
        self.conn = None

    def _once(self, path):
        if self.conn is None:
            self._connect()
        self.conn.request(
            "GET",
            path,
            headers={
                "Host": HOST,
                "User-Agent": USER_AGENT,
                "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "ar,en;q=0.8",
                "Accept-Encoding": "gzip, deflate",
                "Connection": "keep-alive",
            },
        )
        resp = self.conn.getresponse()
        raw = resp.read()
        headers = {k.lower(): v for k, v in resp.getheaders()}
        enc = headers.get("content-encoding", "").lower()
        try:
            if "gzip" in enc:
                raw = gzip.GzipFile(fileobj=io.BytesIO(raw)).read()
            elif "deflate" in enc:
                try:
                    raw = zlib.decompress(raw)
                except zlib.error:
                    raw = zlib.decompress(raw, -zlib.MAX_WBITS)
        except Exception:
            pass
        return resp.status, headers, raw

    def get(self, path):
        """Return (status, final_path, text). status 0 means it failed."""
        path = to_path(path)
        redirects = 0
        attempt = 0
        while attempt < RETRIES:
            wait = DELAY + random.uniform(0, 1.5) - (time.time() - self.last)
            if wait > 0:
                time.sleep(wait)
            try:
                status, headers, raw = self._once(path)
                self.last = time.time()
            except Exception as e:
                self.last = time.time()
                self.close()
                attempt += 1
                pause = min(90, 6 * (2 ** (attempt - 1)))
                say("      network problem (%s), try %d/%d, waiting %ds"
                    % (type(e).__name__, attempt, RETRIES, pause))
                time.sleep(pause)
                continue

            if status in (301, 302, 303, 307, 308) and headers.get("location"):
                redirects += 1
                if redirects > 6:
                    return 0, path, ""
                path = to_path(urljoin(BASE + path, headers["location"]))
                if not path:
                    return 0, "", ""       # redirected away from the site
                continue
            if status in (429, 500, 502, 503, 504, 520, 521, 522, 523, 524):
                attempt += 1
                pause = min(180, 15 * (2 ** (attempt - 1)))
                say("      server said %s, try %d/%d, waiting %ds"
                    % (status, attempt, RETRIES, pause))
                self.close()
                time.sleep(pause)
                continue
            if status == 403:
                say("      403 Forbidden: the site is blocking this program.")
                return 403, path, ""
            return status, path, raw.decode("utf-8", errors="replace")
        return 0, path, ""


def to_path(url):
    """Keep only same-site URLs and return path+query. '' if it leaves the site."""
    p = urlparse(url)
    if p.netloc and p.netloc.lower() not in (HOST, "www." + HOST):
        return ""
    path = p.path or "/"
    return path + ("?" + p.query if p.query else "")


def say(msg):
    try:
        print(msg, flush=True)
    except Exception:
        print(msg.encode("ascii", "replace").decode("ascii"), flush=True)


# ----------------------------------------------------------------------------
# Parsing (regular expressions only; the structure was read from real pages)
# ----------------------------------------------------------------------------


def clean_text(fragment):
    """HTML fragment -> plain text, keeping paragraph breaks."""
    t = re.sub(r"<script.*?</script>|<style.*?</style>", " ", fragment, flags=re.S | re.I)
    t = re.sub(r"<br\s*/?>", "\n", t, flags=re.I)
    t = re.sub(r"</(p|div|h\d|li|tr|blockquote)\s*>", "\n", t, flags=re.I)
    t = re.sub(r"<[^>]+>", "", t)
    t = t.replace("&nbsp", "&nbsp;").replace("&nbsp;;", "&nbsp;")
    t = htmllib.unescape(t).replace("\xa0", " ")
    lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in t.split("\n")]
    return "\n".join(ln for ln in lines if ln)


def inner_div(page, div_id):
    """Return the inner HTML of <div id="div_id"> with nested divs balanced."""
    m = re.search(r'<div\b[^>]*\bid="%s"[^>]*>' % re.escape(div_id), page, flags=re.I)
    if not m:
        return None
    start = m.end()
    depth = 1
    for t in re.finditer(r"<(/?)div\b[^>]*>", page[start:], flags=re.I):
        depth += -1 if t.group(1) else 1
        if depth == 0:
            return page[start:start + t.start()]
    return page[start:]


def parse_reader(page, book_id):
    out = {"html": None, "text": "", "chapter": "", "page_label": "", "next": "", "toc": [], "parts": []}

    content = inner_div(page, "bookContent")
    if content is not None:
        out["html"] = content.strip()
        out["text"] = clean_text(content)

    m = re.search(r'class="reader-chapter__title"[^>]*>(.*?)</h\d>', page, flags=re.S | re.I)
    if m:
        out["chapter"] = clean_text(m.group(1))
    m = re.search(r'class="reader-chapter__meta"[^>]*>(.*?)</p>', page, flags=re.S | re.I)
    if m:
        out["page_label"] = clean_text(m.group(1))

    for m in re.finditer(r'<a\b[^>]*href="([^"]+)"[^>]*class="reader-pager__btn[^"]*"[^>]*>(.*?)</a>',
                         page, flags=re.S | re.I):
        if "التالية" in m.group(2):
            out["next"] = to_path(urljoin(BASE, htmllib.unescape(m.group(1))))

    seen = set()
    for m in re.finditer(r'<a\b[^>]*href="([^"]*/book/%d/title/(\d+)[^"]*)"[^>]*>(.*?)</a>' % book_id,
                         page, flags=re.S | re.I):
        n = int(m.group(2))
        if n in seen:
            continue
        seen.add(n)
        out["toc"].append({"n": n, "label": clean_text(m.group(3)),
                           "href": to_path(urljoin(BASE, htmllib.unescape(m.group(1))))})

    m = re.search(r'<script[^>]*id="readerPdfConfig"[^>]*>(.*?)</script>', page, flags=re.S | re.I)
    if m:
        try:
            cfg = json.loads(m.group(1))
            out["parts"] = [p.get("part") for p in cfg.get("parts", []) if p.get("part") is not None]
        except Exception:
            pass
    return out


def parse_book(page, book_id):
    meta = {"id": book_id, "url": "%s/book/%d" % (BASE, book_id)}
    m = re.search(r'<script[^>]*application/ld\+json[^>]*>\s*(\{.*?\})\s*</script>', page, flags=re.S | re.I)
    if m:
        try:
            ld = json.loads(m.group(1))
            meta["title"] = ld.get("name", "")
            meta["author"] = (ld.get("author") or {}).get("name", "")
            meta["category"] = ", ".join(ld.get("genre") or [])
            meta["date_added"] = ld.get("datePublished", "")
        except Exception:
            pass
    if not meta.get("title"):
        m = re.search(r"<title[^>]*>(.*?)</title>", page, flags=re.S | re.I)
        meta["title"] = clean_text(m.group(1)) if m else ""
    m = re.search(r'href="[^"]*/authors/(\d+)"[^>]*>(.*?)</a>', page, flags=re.S | re.I)
    if m:
        meta["author_id"] = int(m.group(1))
        meta["author_line"] = clean_text(m.group(2))
    m = re.search(r'href="[^"]*/categories/(\d+)"[^>]*class="book-detail__stat"', page, flags=re.I)
    if m:
        meta["category_id"] = int(m.group(1))
    # The "book card": lines such as "الناشر: ..." and "الطبعة: ..."
    card = []
    text = clean_text(page)
    for label in ("الكتاب", "المؤلف", "المحقق", "تحقيق", "الناشر", "الطبعة",
                  "عدد الصفحات", "عدد الأجزاء", "الأجزاء", "عدد المجلدات"):
        m = re.search(r"^%s\s*:\s*(.+)$" % label, text, flags=re.M)
        if m:
            card.append({"label": label, "value": m.group(1).strip()[:400]})
    meta["card"] = card
    return meta


def part_of(path):
    m = re.search(r"/book/\d+/page/[^/?]+/(\d+)", path or "")
    return int(m.group(1)) if m else 1


def page_of(path):
    m = re.search(r"/book/\d+/page/([^/?]+)", path or "")
    return m.group(1) if m else ""


# ----------------------------------------------------------------------------
# Commands
# ----------------------------------------------------------------------------


def cmd_list(sess, cat_ids):
    os.makedirs(os.path.join(OUT, "_raw"), exist_ok=True)
    rows = {}
    before_count = {}
    for cat in cat_ids:
        queue = ["/categories/%d" % cat]
        seen = set(queue)
        n = 0
        while queue and n < 40:
            path = queue.pop(0)
            n += 1
            say("[category %d] %s" % (cat, path))
            status, final, page = sess.get(path)
            if status != 200 or not page:
                say("      could not read it (status %s)" % status)
                continue
            raw_name = "category_%d_%d.html" % (cat, n)
            with open(os.path.join(OUT, "_raw", raw_name), "w", encoding="utf-8") as f:
                f.write(page)
            for m in re.finditer(r'<a\b[^>]*href="[^"]*/book/(\d+)"[^>]*>(.*?)</a>', page, flags=re.S | re.I):
                bid = int(m.group(1))
                label = re.sub(r"\s+", " ", clean_text(m.group(2))).strip()
                if bid not in rows or len(label) > len(rows[bid]["label"]):
                    rows[bid] = {"id": bid, "category": cat, "label": label,
                                 "skipped_by_default": "yes" if bid in SKIP_IDS else ""}
            # The site pages its lists without links; ask for the next page
            # by number and stop when a page brings no new book.
            now = len(rows)
            if now > before_count.get(cat, -1) and re.search(r'wire:click="nextPage"', page):
                before_count[cat] = now
                nxt = "/categories/%d?page=%d" % (cat, n + 1)
                if nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)

    # Also keep the terms page, so the conditions of use can be read.
    status, final, page = sess.get("/terms-of-service")
    if status == 200 and page:
        with open(os.path.join(OUT, "_raw", "terms-of-service.html"), "w", encoding="utf-8") as f:
            f.write(page)

    path = os.path.join(OUT, "books_index.csv")
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["id", "category", "label", "skipped_by_default"])
        w.writeheader()
        for bid in sorted(rows):
            w.writerow(rows[bid])
    say("Found %d books. Saved: %s" % (len(rows), path))
    say("Note: the list may also contain books shown as suggestions on the page.")


def load_state(folder):
    try:
        with open(os.path.join(folder, "state.json"), encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_json(folder, name, data):
    tmp = os.path.join(folder, name + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    os.replace(tmp, os.path.join(folder, name))


def cmd_book(sess, book_id, max_pages):
    folder = os.path.join(OUT, "book_%d" % book_id)
    os.makedirs(folder, exist_ok=True)
    state = load_state(folder)
    if state.get("done") and not max_pages:
        say("[book %d] already complete (%d pages). Skipping." % (book_id, state.get("pages", 0)))
        return True

    if not os.path.exists(os.path.join(folder, "meta.json")):
        status, final, page = sess.get("/book/%d" % book_id)
        if status != 200 or not page:
            say("[book %d] could not read the book page (status %s)" % (book_id, status))
            return status != 403
        save_json(folder, "meta.json", parse_book(page, book_id))

    path = state.get("next") or "/book/%d/read" % book_id
    count = state.get("pages", 0)
    seen = set(state.get("seen_tail", []))
    first_hash = state.get("first_hash", "")
    known_parts = state.get("parts", [])
    fails = 0
    this_run = 0
    say("[book %d] starting at %s (already saved: %d pages)" % (book_id, path, count))

    with open(os.path.join(folder, "pages.jsonl"), "a", encoding="utf-8") as out:
        while path:
            if max_pages and this_run >= max_pages:
                say("[book %d] reached the test limit of %d pages." % (book_id, max_pages))
                break
            status, final, page = sess.get(path)
            if status == 403:
                return False
            if status != 200 or not page:
                fails += 1
                say("      page failed (status %s) [%d/%d]" % (status, fails, MAX_FAILS_IN_ROW))
                if fails >= MAX_FAILS_IN_ROW:
                    say("[book %d] stopping for now. Run the same command later to resume." % book_id)
                    break
                continue
            fails = 0
            r = parse_reader(page, book_id)
            if r["html"] is None:
                say("      no text block found at %s ; saving the page for inspection." % final)
                with open(os.path.join(folder, "problem_page.html"), "w", encoding="utf-8") as f:
                    f.write(page)
                break

            h = hashlib.sha1(r["html"].encode("utf-8")).hexdigest()
            if count == 0:
                first_hash = h
                save_json(folder, "toc.json", r["toc"])
                known_parts = r["parts"]
                with open(os.path.join(folder, "first_reader_page.html"), "w", encoding="utf-8") as f:
                    f.write(page)

            rec = {
                "book": book_id,
                "seq": count + 1,
                "part": part_of(final),
                "url_page": page_of(final),
                "page_label": r["page_label"],
                "chapter": r["chapter"],
                "url": BASE + final,
                "html": r["html"],
                "text": r["text"],
            }
            out.write(json.dumps(rec, ensure_ascii=False) + "\n")
            out.flush()
            count += 1
            this_run += 1
            seen.add(final)
            if count % 25 == 0:
                say("      %d pages saved (part %s, %s)" % (count, rec["part"], "site page %s" % rec["url_page"]))

            nxt = r["next"]
            if nxt and nxt in seen:
                say("      next link points to a page already read; stopping to avoid a loop.")
                nxt = ""
            if not nxt:
                # End of this part. If the book has more parts, try the next one.
                cur = part_of(final)
                later = sorted(p for p in known_parts if isinstance(p, int) and p > cur)
                if later:
                    cand = "/book/%d/p/0/%d" % (book_id, later[0])
                    st2, fin2, pg2 = sess.get(cand)
                    r2 = parse_reader(pg2, book_id) if st2 == 200 and pg2 else None
                    if r2 and r2["html"] is not None and part_of(fin2) == later[0] and \
                            hashlib.sha1(r2["html"].encode("utf-8")).hexdigest() != first_hash:
                        nxt = fin2
                        say("      moving to part %d" % later[0])
                    else:
                        say("      could not open part %d automatically; noted in state.json" % later[0])
                        state["unreached_parts"] = later
            path = nxt
            state.update({"next": path, "pages": count, "first_hash": first_hash,
                          "parts": known_parts, "seen_tail": sorted(seen)[-400:],
                          "done": (not path) and not (max_pages and this_run >= max_pages)})
            if True:
                save_json(folder, "state.json", state)

    state.update({"pages": count})
    save_json(folder, "state.json", state)
    say("[book %d] saved %d pages in total. %s" % (book_id, count, "COMPLETE" if state.get("done") else "not finished yet"))
    return True


def cmd_pack():
    name = "ziydia_out.zip"
    with zipfile.ZipFile(name, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(OUT):
            for fn in files:
                if fn.endswith(".tmp"):
                    continue
                full = os.path.join(root, fn)
                z.write(full, arcname=full)
    say("Packed: %s  (%.1f MB)" % (os.path.abspath(name), os.path.getsize(name) / 1e6))


def main(argv):
    try:
        sys.stdout.reconfigure(errors="replace")
    except Exception:
        pass
    if len(argv) < 2 or argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    os.makedirs(OUT, exist_ok=True)
    cmd = argv[1]
    args = argv[2:]

    if cmd == "pack":
        cmd_pack()
        return 0

    sess = Session()
    try:
        if cmd == "list":
            cats = [int(a) for a in args if a.isdigit()] or [5]
            cmd_list(sess, cats)
        elif cmd == "books":
            max_pages = 0
            include_skipped = "--include-skipped" in args
            if "--max-pages" in args:
                max_pages = int(args[args.index("--max-pages") + 1])
            ids = []
            skip_next = False
            for a in args:
                if skip_next:
                    skip_next = False
                    continue
                if a == "--max-pages":
                    skip_next = True
                elif a.isdigit():
                    ids.append(int(a))
            if not ids:
                say("Give one or more book numbers, e.g.:  py ziydia_fetch.py books 183 466")
                return 1
            for bid in ids:
                if bid in SKIP_IDS and not include_skipped:
                    say("[book %d] skipped by default. Add --include-skipped to fetch it." % bid)
                    continue
                if not cmd_book(sess, bid, max_pages):
                    say("Stopped: the site refused the program (403). Ask the owner to allow it.")
                    return 2
        else:
            say("Unknown command. Run:  py ziydia_fetch.py help")
            return 1
    finally:
        sess.close()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except KeyboardInterrupt:
        print("\nStopped by you. Run the same command again to resume.")
        sys.exit(1)
