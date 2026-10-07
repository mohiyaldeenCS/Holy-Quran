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
     "licence": {"text": "<licence text or null>", "permission_ref": "<reference or null>",
                 "notice": "<notice the licence requires, or null>", "allows_export": true}},
    {"role": "edition_map", "registry_row": 4, "...": "same fields"}
  ],
  "files": [{"name": "text.sqlite", "sha256": "<hex>", "bytes": 0}],
  "surah_sha256": {"1": "<hex>", "2": "<hex>"},
  "counts": {"surahs": 0, "ayat": 0, "words": 0,
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
  licence and grade (question P1 of the M0.3 review).
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
  number       INTEGER NOT NULL,                  -- 1..n per ayah, contiguous (D-038 decides mark-only tokens)
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

### Word offsets

Offsets are UTF-16 code units, because Flutter's text spans, hit testing and glyph
boxes all count in them, so the app slices with no conversion. In Python:
`len(s[:i].encode('utf-16-le')) // 2` for code-point index `i`.

Spans of one ayah are ordered, do not overlap and lie within the ayah. What lies
between them is the source's own separator. The ayah reassembled from its spans and
the gaps between them is identical to the stored ayah; the integrity suite checks it.

### Surah digest

`surah_sha256` holds, per surah, the lowercase hex SHA-256 over a sequence of fields:
first the basmala, if the surah has one, with number 0; then every ayah in order,
with its number. Each field is written as

```
u32be(number) ‖ u32be(byte_length) ‖ UTF-8 bytes
```

In Python, standard library only: `h.update(struct.pack('>II', n, len(b))); h.update(b)`.

Test vectors (synthetic, computed independently in Python and in Dart):

| Input | SHA-256 |
| --- | --- |
| ayat `['Synthetic ayah one', 'Synthetic é two', ' نص تجريبي  ']`, basmala `'Synthetic opening line'` | `881415c778b801345a189d02c780cfc9d52a5f92e4390af1e176e02c12b73bb8` |
| the same ayat, no basmala | `1e0042fff89902b157ace9af9ce04a42b5059b3babd38e73e803480413d8051c` |

And for offsets: in `'ab \u{1F600} cd'` the word `cd` starts at UTF-16 offset 6
(code-point index 5).

### File hash

`files[].sha256` is the lowercase hex SHA-256 of the whole file; `bytes` is its size.

## Verification order in the app (PRD §9.5, `OF-05`)

1. Read `manifest.json` and `manifest.json.sig`; check the signature (D-024; until a
   key exists the check reports "not checked", and no pack ships).
2. Parse the manifest strictly.
3. For each file: size, then SHA-256.
4. Open read-only and immutable; check `application_id`, `user_version` and the
   header bytes.
5. The first time a surah is read in a session, compare its digest with
   `surah_sha256`. On a mismatch the pack is disabled for the session and no text from
   it is shown.

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

## Open questions for the planning session

Raised in the M0.3 pull request:

- **P1.** A list of `sources`, each with its own licence and grade, instead of the
  single source of PRD §9.2. Acceptable?
- **P2.** Do all juz, hizb, rub and page units of the 1421H edition start at an ayah
  boundary in the source data? Are hizb and rub taken from the source rather than
  derived? If any starts mid-ayah, format v1 changes.
- **P3.** Under D-038, does a mark-only token fall inside the span of the word before
  it, and how is `counts.words` defined?
- **P4.** Is the basmala taken per surah from the separate field of the Tanzil XML,
  and `NULL` where the source has none?
- **P5.** Can B0.10 provide an independent reference file (per-surah ayah counts from
  the KFGQPC file, with its hash), so that the app suite has a witness other than the
  pack's own manifest?
- **P6.** Do `revelation_place` and `revelation_order` come from the Tanzil metadata
  (B0.9)?
- **P7.** Is SQLite 3.37 or later (for `STRICT`) available in the owner's Python?
- **Signing (O-03).** The Python standard library has no Ed25519; the signing step
  needs a tool outside it, such as the OpenSSL command line or the `cryptography`
  package.
