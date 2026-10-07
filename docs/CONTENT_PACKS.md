# Content packs — format v1

This file defines what a content pack is on disk, so that the app (stream A) and the
pipeline in `tools/packs/` (stream B) agree without sharing code (D-035, D-064). The
app's verification and the integrity suite in `test/integrity/` decide whether a pack
is accepted. Written in M0.3; the planning session reviews it in the pull request.

Version 1 defines the text pack (`kind: "text"`), which carries the Hafs base text,
its word offsets, surah metadata and the reference edition's divisions. Other kinds
(pages, tafsir, timing, recitation, tajweed, linguistic) are added with their
milestones as new `kind` values and new versions of this file.

Nothing in this file is Quran text. Every value shown below is a placeholder.

## Directory

```
<pack-id>/<version>/
  manifest.json        UTF-8 without BOM; its exact bytes are what is signed
  manifest.json.sig    detached signature over manifest.json (format fixed by D-024; absent until then)
  text.sqlite          kind "text": exactly one data file with this name
```

## Manifest (`manifest.json`)

The fields of PRD §9.2. Every field is required; `riwaya` is `null` when it does not
apply. Unknown fields are rejected.

```json
{
  "format": "holyquran-pack",
  "format_version": 1,
  "id": "base-hafs-tanzil",
  "kind": "text",
  "version": 1,
  "changelog": [{"version": 1, "date": "YYYY-MM-DD", "summary": "<text>"}],
  "riwaya": "hafs",
  "edition": "kfgqpc-madinah-1421",
  "font": {"family": "Amiri Quran", "version": "1.003", "sha256": "<hex>"},
  "sources": [
    {"role": "text", "registry_row": 1, "name": "<name>", "publisher": "<body>",
     "url": "<url>", "version": "<source version>", "fetched_on": "YYYY-MM-DD",
     "file_sha256": "<hex>", "trust_grade": "A",
     "options": {"<option name>": "<value>"},
     "licence": {"text": "<licence text or null>", "permission_ref": "<reference or null>",
                 "notice": "<notice the licence requires, or null>", "allows_export": true}},
    {"role": "edition_map", "registry_row": 4, "...": "same fields"}
  ],
  "files": [{"name": "text.sqlite", "sha256": "<hex>", "bytes": 0}],
  "surah_sha256": {"1": "<hex>", "2": "<hex>"},
  "counts": {"surahs": 0, "ayat": 0, "words": 0, "marks": 0,
             "divisions": {"juz": 0, "hizb": 0, "rub": 0, "page": 0}, "sajdas": 0},
  "reviews": [{"reviewer": "<name or role>", "date": "YYYY-MM-DD", "scope": "<what was reviewed>"}]
}
```

Rules:

- `format` is `holyquran-pack`. `format_version` outside the versions the app knows
  (today `1`) makes the pack unsupported: it is hidden, not opened.
- `kind` is one of the known kinds (today `text`). `trust_grade` is `A`, `B` or `C`.
- Every hash is lowercase hexadecimal SHA-256: `^[0-9a-f]{64}$`.
- `files[].name` is a bare file name: no `/`, `\` or `..`.
- The keys of `surah_sha256` are exactly `"1"` to `"<counts.surahs>"`.
- `sources` is a list because a pack may draw on several registry rows (the base pack
  takes its text from row 1 and its divisions from row 4). Each entry carries its own
  licence and grade (question P1 of the M0.3 review). `role` is `text` or
  `edition_map`; a text pack has at least one `text` source. Every licence has a
  non-null `text` or `permission_ref`, so no content is shown without a source and a
  permission (PRD §9.1).
- `options` holds the choices the source file was produced with (on Tanzil's
  download page: the text type and whether pause marks, sajda signs and other signs
  are included), with names and values as the source gives them. Values are strings,
  numbers or booleans; names are not empty. It is `null` when the source offers no
  choices (D-077); an empty object is refused.
- `id` and `version` equal the names of the two directories the pack sits in
  (`<pack-id>/<version>/`), so a manifest cannot be moved under another pack or
  version.
- `font` names the font the text is drawn with; text and font are one pair (PRD §9.1).
  The integrity suite checks it against the app's pinned font file.

## Text pack (`text.sqlite`)

- SQLite 3, `PRAGMA encoding = 'UTF-8'` set before any table is created.
- `PRAGMA application_id = 1213288523` (ASCII `HQPK`).
- `PRAGMA user_version = 1`, equal to `format_version`.
- `journal_mode = DELETE`, so bytes 18 and 19 of the file header are both 1. No WAL.
  The build ends with `VACUUM`.
- The tables are `STRICT`, so the pipeline needs SQLite 3.37 or later.
- No text value begins with U+FEFF. The pipeline stops on one; it never strips it.
  (Dart's UTF-8 decoders silently drop a leading U+FEFF, so it would reach the screen
  changed while the digest still passed.)
- The app opens the file read-only and immutable (`file:<path>?mode=ro&immutable=1`).
  A released file is never edited in place; a change is a new pack version.

```sql
CREATE TABLE surah (
  number           INTEGER PRIMARY KEY,           -- 1..counts.surahs, contiguous
  name             TEXT NOT NULL,                 -- as in the source metadata
  ayah_count       INTEGER NOT NULL,
  revelation_place TEXT CHECK (revelation_place IN ('makki','madani')), -- NULL if the source has none
  revelation_order INTEGER,                       -- NULL if the source has none
  basmala          TEXT                           -- the source's separate basmala field; NULL where it has none
) STRICT;

CREATE TABLE ayah (
  surah  INTEGER NOT NULL REFERENCES surah(number),
  number INTEGER NOT NULL,                        -- 1..ayah_count, contiguous
  text   TEXT NOT NULL,                           -- verbatim from the source
  PRIMARY KEY (surah, number)
) STRICT, WITHOUT ROWID;

CREATE TABLE word (
  surah        INTEGER NOT NULL,
  ayah         INTEGER NOT NULL,
  number       INTEGER NOT NULL,                  -- 1..n per ayah, contiguous; a token with no letter is a mark, not a word (D-078)
  start_offset INTEGER NOT NULL,                  -- UTF-16 code units into ayah.text, half-open
  end_offset   INTEGER NOT NULL,
  PRIMARY KEY (surah, ayah, number),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID;

CREATE TABLE mark (
  surah        INTEGER NOT NULL,
  ayah         INTEGER NOT NULL,
  number       INTEGER NOT NULL,                  -- 1..n per ayah, contiguous, in text order
  after_word   INTEGER NOT NULL,                  -- number of the word it follows; 0 when it precedes the first word
  start_offset INTEGER NOT NULL,                  -- UTF-16 code units into ayah.text, half-open
  end_offset   INTEGER NOT NULL,
  PRIMARY KEY (surah, ayah, number),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID;

CREATE TABLE division (
  kind   TEXT NOT NULL CHECK (kind IN ('juz','hizb','rub','page')),
  number INTEGER NOT NULL,                        -- 1..counts.divisions[kind], contiguous
  surah  INTEGER NOT NULL,                        -- first ayah of the unit in the reference edition
  ayah   INTEGER NOT NULL,
  PRIMARY KEY (kind, number),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID;

CREATE TABLE sajda (
  surah INTEGER NOT NULL,
  ayah  INTEGER NOT NULL,
  PRIMARY KEY (surah, ayah),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID;
```

### Word and mark offsets

The tokens of an ayah are separated by U+0020 only. A word is a token that holds at
least one letter, a code point of Unicode general category L (Lu, Ll, Lt, Lm or Lo,
so the tatweel U+0640 and the small waw and yeh U+06E5 and U+06E6 count); a token
with none (a pause mark, a sajda sign) is a mark (D-078). A mark has
no word number and lies outside every word span, so highlighting a spoken word does
not colour the mark after it. `counts.words` and `counts.marks` are the row counts of
`word` and `mark`. Which mark it is, is its slice; meanings come from their own
source (registry row 19), keyed by that slice.

Offsets are UTF-16 code units, because Flutter's text spans, hit testing and glyph
boxes all count in them, so the app slices with no conversion. In Python:
`len(s[:i].encode('utf-16-le')) // 2` for code-point index `i`.

Each word or mark span is exactly one token: it holds no U+0020, and the code unit
before it and the one at its end are U+0020 or the ayah's edge. So the spans of one
ayah, taken together, are ordered, do not overlap, lie within the ayah, and nothing
but U+0020 lies outside them; a source whose text uses any other separator is
refused by the pipeline, never rewritten. A mark's `after_word` is the number of
the last word before it (0 when no word precedes it). The integrity suite checks
all of this for every ayah.

### Surah digest

`surah_sha256` holds, per surah, the lowercase hex SHA-256 over a sequence of fields:
first the basmala when `basmala IS NOT NULL` (an empty string counts), with number 0;
then every ayah in order,
with its number. Each field is written as

```
u32be(number) ‖ u32be(byte_length) ‖ UTF-8 bytes
```

In Python, standard library only: `h.update(struct.pack('>II', n, len(b))); h.update(b)`.

Test vectors (synthetic, computed independently in Python and in Dart). The inputs
are written with escapes because an editor may silently recompose `e` + U+0301 into
U+00E9, which changes the bytes and the digest; that is exactly the kind of change
the digest exists to catch. `A` stands for the synthetic Arabic-script phrase
`\u0646\u0635 \u062a\u062c\u0631\u064a\u0628\u064a`.

| Ayat | Basmala | SHA-256 |
| --- | --- | --- |
| `'Synthetic ayah one'`, `'Synthetic e\u0301 two'`, `' A  '` | `'Synthetic opening line'` | `881415c778b801345a189d02c780cfc9d52a5f92e4390af1e176e02c12b73bb8` |
| the same | none | `1e0042fff89902b157ace9af9ce04a42b5059b3babd38e73e803480413d8051c` |
| `'Synthetic ayah one'`, `'Synthetic \u00e9 two'`, `' A  '` | `'Synthetic opening line'` | `3e93c75c683b8258ecc0e2698acd10f06c07c025ac7dada60a691f8e46edf177` |
| the same | none | `0b1fede8d41e15b1529f9a121f4a57a590759dd23159e12b707d840cc68816cb` |

And for offsets: in `'ab \u{1F600} cd'` the word `cd` starts at UTF-16 offset 6
(code-point index 5).

### File hash

`files[].sha256` is the lowercase hex SHA-256 of the whole file; `bytes` is its size.

## Verification order in the app (PRD §9.5, `OF-05`)

1. Read `manifest.json` and `manifest.json.sig`; check the signature (D-024; until a
   key exists the check reports "not checked", and no pack ships).
2. Parse the manifest strictly.
3. For each file: size, then SHA-256.
4. Open read-only and immutable; check the header bytes, `application_id`,
   `user_version`, and that the tables and columns are exactly those above, in
   order, with their types and `NOT NULL`, `STRICT`, and with no hidden or generated
   column (read through `pragma_table_list` and `pragma_table_xinfo`).
5. On the first read in a session, compare the row counts with `counts` and check
   that numbering is contiguous and every division and sajda points at an ayah.
6. The first time a surah is read in a session, compare its digest with
   `surah_sha256`, decode every text of the surah as strict UTF-8, and check its word
   and mark spans together (ordered, not overlapping, within the ayah, no offset
   inside a surrogate pair, each mark's `after_word` the last word before it).

Any failure in steps 5 and 6 disables the pack for the session (`PackInconsistent`,
`SurahHashMismatch`, `TextEncodingRejected`) and no text from it is shown. The app
keeps one open text repository per pack per session, so the disabled state holds
for the whole session.

When the whole pack is re-verified (first run after install or update) is wired in
M1.2 with the integrity alert. The bundled base pack is copied from the app's assets
to its support directory, verified, then opened (D-061).

## Accepting a pack

A pack built by the pipeline is accepted when the app's integrity suite passes on it:

```
flutter test test/integrity --dart-define=HOLYQURAN_PACK_DIR=<path to pack-id/version>
```

The suite takes its expected values from the manifest, which the pipeline checked
against the source (PRD §9.4) and the signature binds. No count of surahs or ayat is
written in Dart.

## Review by the planning session, 2026-10-07

Applied by stream A in the follow-up to M0.3 (D-083): the sections above now
include the `mark` table, `counts.marks` and `sources[].options`, and the app reads
and checks them. The review is kept as written.

Format v1 was read against PRD §9 and §10 and against what stream B knows of the
sources. It is accepted, with the two changes under "Changes requested". The text of
the format above is left as merged, so that it still describes the code; stream A
applies the changes and rewrites the sections they touch.

Stream B has not downloaded the source files yet. Answers that rest on the published
structure of a file, and not on the file itself, say so; the pipeline checks each of
them when B0.2 runs and stops if one does not hold.

### Answers

| | Question | Answer |
| --- | --- | --- |
| P1 | A list of `sources`, each with its licence and grade | Accepted. It is PRD §9.2 applied per source, and the base pack does draw on two registry rows. Stream B fills one entry per source file. See change 2 for one field to add |
| P2 | Do juz, hizb, rub and page units start at an ayah boundary? Are hizb and rub taken from the source? | In the source data, yes: the Tanzil metadata file gives every juz, quarter and page as a surah and an ayah, so it cannot express a start inside an ayah, and the KFGQPC file gives a page and a juz per ayah. The 240 quarters are the source's own list; a hizb is every fourth entry of that list, taken by position, with nothing computed. The page list is compared with the KFGQPC file for the 1421H edition (registry row 4), and a difference stops the build. Format v1 stands for Hafs. Other riwayat, in Phase 2, are checked again before their packs are specified. Rests on the published structure of both files |
| P3 | Mark-only tokens and `counts.words` | A word is a white-space-separated token of the ayah that contains at least one Arabic letter. A token with none (a pause mark, a sajda sign) is not a word, has no word number, and lies in the gap after the word before it: it is **outside** that word's span, so highlighting a spoken word does not colour the mark. `counts.words` is the number of rows of `word`. Marks get their own table: change 1. The pipeline decides "mark" from an explicit table of code points and stops on a letterless token that is not in it |
| P4 | Basmala from the separate field of the Tanzil XML | Yes. The pipeline reads the XML form, where the basmala is an attribute of the first ayah of a surah and not part of its text. It is `NULL` for surah 1, where it is ayah 1, and for surah 9, which has none. The pipeline stops if any other surah lacks it or if these two carry it. Rests on the published structure of the file |
| P5 | An independent reference file for the app suite | Yes, with B0.3. `testing/reference/kfgqpc-hafs-counts.json`: the name, version and SHA-256 of the KFGQPC Hafs file it was counted from, the date, the ayah count of each surah and the total. It is derived from the KFGQPC file alone, never from the pack. It holds counts, no text |
| P6 | `revelation_place` and `revelation_order` from the Tanzil metadata | Yes, both are attributes of each surah there (B0.9). The pipeline maps the source's two place values to `makki` and `madani` through a fixed table and stops on any other value. Reports on the order of revelation differ between scholars, so the app shows `revelation_order` only if the religious reviewer approves that list; the column is filled either way, and the mushaf order is the surah number |
| P7 | SQLite 3.37 or later in the owner's Python | Not known for his computer yet. The pipeline prints `sqlite3.sqlite_version` and refuses to run below 3.37. The planning session's own Python has 3.45.1, so packs can also be built there from files the owner uploads |
| | Signing | Agreed that it is a step outside the standard library, run by whoever holds the key (O-03). Proposed for D-024: `manifest.json.sig` is the raw 64-byte Ed25519 signature (RFC 8032) of the exact bytes of `manifest.json`; the app holds a list of accepted public keys, so that a key can be replaced; signing is one OpenSSL 3 command (`openssl pkeyutl -sign -rawin`), which needs nothing installed beyond OpenSSL |

### Changes requested

1. **A table for marks.** `WQ-01`…`WQ-03` need each pause mark to be addressable
   (tapping it opens its card), and D-038 keeps marks out of the word index.

   ```sql
   CREATE TABLE mark (
     surah        INTEGER NOT NULL,
     ayah         INTEGER NOT NULL,
     number       INTEGER NOT NULL,                  -- 1..n per ayah, contiguous, in text order
     after_word   INTEGER NOT NULL,                  -- number of the word it follows; 0 when it precedes the first word
     start_offset INTEGER NOT NULL,                  -- UTF-16 code units into ayah.text, half-open
     end_offset   INTEGER NOT NULL,
     PRIMARY KEY (surah, ayah, number),
     FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
   ) STRICT, WITHOUT ROWID;
   ```

   `counts.marks` is its row count. Word spans and mark spans together are ordered and
   do not overlap; the ayah rebuilt from all of them and the gaps between them equals
   the stored ayah. Which mark it is, is the slice itself; the meanings come from
   their own source (registry row 19, B0.8), keyed by that slice.

2. **The options a source file was produced with.** Tanzil builds its text file from
   choices made on its download page (the text type, and whether pause marks, sajda
   signs and other signs are included). They decide the bytes, so each `sources[]`
   entry gains `"options"`: an object of the option names and values as the source
   names them, or `null`.

Both are small enough to stay format version 1 if stream A agrees, because no pack
has been built or released under it.

### Which Tanzil file the base pack uses

Asked by stream A in `docs/plans/M0.4.md` (pull request #6). Proposed, and settled
in B0.2 with the proofreader (O-16):

| | |
| --- | --- |
| Text | Tanzil Uthmani, version 1.1, the XML output |
| Pause marks | Included. `WQ-01` shows them as they are in the text |
| Sajda signs | Included. `RD-15` takes the sign from the text |
| Rub-el-hizb signs | Not included. `RD-02` draws quarter, hizb and juz marks in the margin, from `division`; a sign inside the text as well would show every quarter twice, and it would travel with the ayah into cards, copies and shares |
| Metadata | Tanzil's `quran-data.xml`, for surah facts, divisions and sajdas |

The download address is the one the `spike-s1-text` task of M0.4 uses, with
`rub=false` in place of `rub=true`. The planning session cannot reach `tanzil.net`,
so it has not tried that address; the pipeline does not trust the address in any
case: it records the SHA-256 of the file it was given and stops if the file holds
U+06DE, or lacks the marks this table says it has.

The S1 measurements made on the site's default file (with the rub-el-hizb sign) stay
valid for shaping, hit-testing and timing. The checks that list code points and
mark-only tokens are worth one more run on the file above, since it is one input of
that task.

### Noted, with no change asked

- The per-surah digest covers the basmala and the ayat. Word and mark offsets,
  divisions and surah facts are covered by the file hash only, which is checked at
  install and not per session. That is enough: they cannot change the text shown.
- Search forms (`SR-03`) come with M1.8 as another `sources[]` role and their own
  table; stream B builds the mapping in B0.4.
- Tanzil's text has no character outside the Basic Multilingual Plane, so UTF-16
  offsets equal code-point indexes there. The pipeline still computes them as the
  format says, and stops if a text pack contains a code point its font lacks.
- The Tanzil copyright notice goes verbatim into `licence.notice` of the text source,
  and stays inside the downloaded file kept in `data/raw/`.

### What stream B delivers against this file

| Task | Delivers |
| --- | --- |
| B0.11 | `tools/packs/`: the builder for `kind: "text"`, with the checks of PRD §9.4 and the rules above; a synthetic source file and tests, so that the builder runs in CI without any Quran text |
| B0.2 | The base pack built from the downloaded Tanzil files; the proofreader's sign-off in `reviews` |
| B0.3 | `testing/reference/kfgqpc-hafs-counts.json` (P5) |
| B0.4 | The mark table of code points; mapping tables from the word index to KFGQPC words, search forms and timing data |
