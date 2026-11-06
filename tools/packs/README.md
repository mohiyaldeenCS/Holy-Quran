# tools/packs — the content pack pipeline

Turns a text source file and its metadata file into a verified text pack of format
v1 (`docs/CONTENT_PACKS.md`, D-064, as amended by D-077, D-078, D-079 and D-083).
Python 3.9 or later, standard library only (D-035); SQLite 3.37 or later. Task B0.11.

The pipeline stores what the source gives byte for byte. It splits an ayah only at
U+0020 to find word and mark spans, refuses anything outside the rules (it never
rewrites), and stops on a failed hash or count with a message that names
addresses, numbers and code points (`U+XXXX`) only, never a source value.

Nothing in this folder is Quran text. The synthetic source is written from `\u`
escapes in `synthetic_source.py`: Latin words and a plainly synthetic
Arabic-script phrase («نص تجريبي»), never an ayah.

## Plan (written before the code)

### Modules

All under `hqpack/`. Each raises `errors.PackError` with a message as above.

| Module | Does | Interface |
| --- | --- | --- |
| `errors.py` | The one error and `U+XXXX` naming | `PackError`, `code_point(c)` |
| `strict_xml.py` | A byte-level reader of the closed XML subset both Tanzil files use: elements, attributes, one declaration, comments outside the root. Refuses a BOM, malformed UTF-8, references, CDATA, DOCTYPE, processing instructions, text content, tabs or line breaks inside a value, repeated attributes. Every value is the exact bytes between its quotes | `parse(data: bytes) -> Document` with `Element(name, attributes: {name: SourceValue}, children, offset)` and `Document(root, comments: [SourceValue])`; `SourceValue(value: str, offset: int, length: int)` |
| `tanzil_text.py` | The Tanzil text XML: `<quran><sura index name><aya index text [bismillah]/></sura></quran>` and exactly one comment outside the root (the copyright notice) | `read_tanzil_text(data) -> TanzilText(suras: [TextSura], notice: SourceValue)`; `TextSura(index, name, ayat: [TextAya])`; `TextAya(surah, number, text, basmala or None)` |
| `tanzil_metadata.py` | Tanzil's `quran-data.xml`: `suras`, `juzs`, `hizbs` (of `quarter`), `manzils`, `rukus`, `pages`, `sajdas`, and none or one comment outside the root (the published file has none; two or more are refused) | `read_tanzil_metadata(data) -> TanzilMetadata(suras: [MetaSura], juzs, quarters, manzils, rukus, pages: [Point], sajdas: [MetaSajda], version: SourceValue or None, notice: SourceValue or None)`; `MetaSura(index, ayas, start, name: SourceValue, tname, ename, type, order, rukus)`; `Point(index, sura, aya)`; `MetaSajda(index, sura, aya, type)` |
| `tokens.py` | D-083: tokens are the maximal runs between U+0020; a token holding a code point of general category L is a word, any other a mark; UTF-16 offsets; refuses a separator of category Z other than U+0020 and a mark code point outside the mark table | `utf16_length(s)`, `spans(text, mark_code_points, where) -> Spans(words: [(start, end)], marks: [(after_word, start, end)])` |
| `mark_table.py` | The mark table of code points (B0.4 delivers the real one): `{"code_points": ["U+06D6", ...]}`, sorted, unique, none a letter or a separator | `read_mark_table(data) -> frozenset[int]` |
| `font.py` | The font file: SHA-256, family (name ID 16, else 1), version (`Version d.ddd` of name ID 5) and the code points of its `cmap` (formats 4 and 12) | `read_font(data) -> FontInfo(family, version, sha256, code_points)` |
| `options.py` | `sources[].options` from the download URL (every query parameter but `agree`, D-077), and the checks the options imply. Tanzil's download form is a GET form of checkboxes (`marks`, `sajdah`, `rub`, `tatweel`, `stanween`, each `true`) and the server reads a parameter's presence, not its value, so `rub=false` switches the rub-el-hizb sign on: a checkbox with any value other than `true` is refused (the URL must omit it), a present `sajdah` or `marks` means at least one of its code points occurs, and an absent `rub` means no U+06DE occurs | `options_from_url(url)`, `option_problems(options, texts)` |
| `digest.py` | The surah digest of `docs/CONTENT_PACKS.md` and file hashes | `surah_digest(fields: [(number, bytes)])`, `sha256_file(path)` |
| `database.py` | `text.sqlite` with the exact DDL, `encoding`, `application_id`, `user_version`, `STRICT`, `journal_mode = DELETE`, ending with `VACUUM`; read-back of every stored text as bytes | `require_sqlite()`, `write_text_database(path, surahs, divisions, sajdas)`, `read_stored_texts(path)` |
| `manifest.py` | The manifest's fields in the format's order, and its bytes (UTF-8, no BOM, two-space indent, final line break) | `build_manifest(...) -> dict`, `encode_manifest(dict) -> bytes` |
| `config.py` | The build description: pack identity, both sources' registry fields, expected source SHA-256, the mark table, reviews. Strict JSON | `read_build_config(path) -> BuildConfig` |
| `profiles.py` | What a riwaya must hold: surah and ayah totals, division counts, which surahs have no basmala, whether the KFGQPC comparison is required | `PROFILES`, `profile_for(riwaya, pack_id, unapproved=False)` |
| `build.py` | The pipeline: hash and read the sources, run every build check, write into a temporary directory, read back, write the manifest, run the verifier, then move into `<out>/<id>/<version>/` | `build_pack(config_path, font_path, out_root, unapproved=False) -> BuildResult` |
| `verify.py` | An independent verifier of a pack directory, sharing no code with the writer beyond `errors.py`: everything the app and its integrity suite check, recomputed from the stored bytes | `verify_pack(directory, mark_code_points=None, font=None) -> Report(problems, counts, signed)` |
| `signing.py` | The signing seam (D-080, O-03): `Signer` with `sign(data) -> 64 bytes`; `OpenSslEd25519Signer(key_path)` runs `openssl pkeyutl -sign -rawin`; `sign_pack` writes `manifest.json.sig` for a pack that verifies; `verify_signature` checks it with a public key | `sign_pack(directory, signer)`, `verify_signature(directory, public_key_path)` |
| `cli.py` | `build` (with `--unapproved-test-copy`, `--kfgqpc`, `--table`), `verify`, `sign`, `verify-signature`, `compare`, `kfgqpc-counts`; prints counts, hashes, paths and `U+XXXX` only | `main(argv) -> exit code` |
| `kfgqpc.py` | KFGQPC's `hafsData_v2-0.json` (registry row 2, B0.2, D-175, D-177): UTF-8 without a BOM, as published (a BOM is refused), an array of objects with exactly the read.me's eleven columns, integers and strings typed strictly, ids 1..n in order, ayat in mushaf order; the published file name | `read_kfgqpc(data, ayat) -> [KfgqpcAya(id, surah, number, juz, page, text)]`, `read_kfgqpc_file(path, ayat) -> (ayat, sha256)` |
| `known_differences.py` | The table of known encoding differences, `tools/packs/known_differences.json` | `read_table(data) -> Table(version, ayah_end, ayah_end_separators, quarter_start, surah_opening_quarter_start, equivalences)`, `Table.ayah_end_rule_at(address) -> Rule or None` |
| `compare.py` | The comparison of PRD 9.4 and the page, juz and quarter comparison of P2; the report | `run_comparison(text, metadata, kfgqpc_path, table_path, profile, tanzil_sha256) -> report` (`tanzil_sha256` is `{"text": hex, "metadata": hex}`), `compare(text, metadata, witness, table) -> report`, `summary(report)`, `encode_report(report) -> bytes` |
| `kfgqpc_counts.py` | The P5 reference counts from the KFGQPC file alone (B0.3) | `kfgqpc_counts(path, date, profile)`, `encode_counts(counts) -> bytes` |

`pack.py` (next to this file) runs the CLI; `synthetic_source.py` writes the synthetic
source files, mark table and build description into a directory.

### Tests

`tests/test_<module>.py` for each module, plus `tests/test_build.py` (end to end on
the synthetic source, and one refusal per build check) and `tests/test_cli.py`.


As built, `build.py` delegates the checks that compare the two source files and
the profile to `source_checks.py`, and the verifier is split into `verify.py`,
`verify_manifest.py`, `verify_database.py` and `verify_spans.py`; the interfaces
are as planned.

## Running

From the repository root (Python 3.9+, SQLite 3.37+, nothing to install):

```
python3 -m unittest discover -s tools/packs/tests -t tools/packs
```

The command line prints paths, counts, hashes and `U+XXXX` only. Exit codes: `0`
done, `64` usage, `65` a source or a pack breaks a rule, `70` anything else
(printed by its type alone).

```
python3 tools/packs/pack.py build --config <build.json> --font assets/fonts/AmiriQuran-Regular.ttf --out data/build
python3 tools/packs/pack.py build --unapproved-test-copy --config <build.json> --font assets/fonts/AmiriQuran-Regular.ttf --out <folder outside every Git tree>
python3 tools/packs/pack.py verify <out>/<id>/<version> [--font <ttf>] [--mark-table <marks.json>]
python3 tools/packs/pack.py sign <out>/<id>/<version> --key <ed25519 private key> --font <ttf> --mark-table <marks.json> [--openssl openssl]
python3 tools/packs/pack.py verify-signature <out>/<id>/<version> --public-key <ed25519 public key> [--openssl openssl]
python3 tools/packs/pack.py build --config <build.json> --font assets/fonts/AmiriQuran-Regular.ttf --out data/build --kfgqpc <hafsData_v2-0.json> --table tools/packs/known_differences.json
python3 tools/packs/pack.py compare --text <tanzil xml> --metadata <quran-data.xml> --kfgqpc <hafsData_v2-0.json> --table tools/packs/known_differences.json --report <out.json>
python3 tools/packs/pack.py kfgqpc-counts --kfgqpc <hafsData_v2-0.json> --date <YYYY-MM-DD> --out testing/reference/kfgqpc-hafs-counts.json
```

| Command | Does |
| --- | --- |
| `build` | Reads the build description, runs every build check below, and writes `<out>/<id>/<version>/` with `manifest.json` and `text.sqlite`, unsigned. An existing version directory is refused: a released pack is never rebuilt in place. A `hafs` build needs `--kfgqpc` and `--table` and runs the KFGQPC comparison after every other check; any other build refuses both. Today a `hafs` build stops there even when the comparison passes (see "The KFGQPC comparison"). `--unapproved-test-copy` builds the owner's local test copy (see "Test-copy mode") |
| `verify` | Runs the independent verifier on a pack directory; with `--font` and `--mark-table` it also checks the font pair and every mark |
| `sign` | Verifies the pack, with its font and mark table (both required), then writes `manifest.json.sig` with OpenSSL (D-080). Refuses a pack that already has one |
| `verify-signature` | Checks `manifest.json.sig` against a public key |
| `compare` | Runs the KFGQPC comparison against the `hafs` profile (6,236 ayat) and writes the report; exits 65 when the report has any problem, 0 when it has none |
| `kfgqpc-counts` | Writes the P5 reference counts of the KFGQPC file; `--date` is the day they are taken, so the same file and date give the same bytes |

To try it on the synthetic source:

```
python3 tools/packs/synthetic_source.py /tmp/synthetic
python3 tools/packs/pack.py build --config /tmp/synthetic/build.json --font assets/fonts/AmiriQuran-Regular.ttf --out /tmp/packs
flutter test test/integrity --dart-define=HOLYQURAN_PACK_DIR=/tmp/packs/synthetic-text/1
```

### The build description

A strict JSON file next to the source files (`config.py`); `synthetic_source.py`
writes an example. Every key is required and no other is accepted.

| Key | Holds |
| --- | --- |
| `id`, `version`, `changelog`, `riwaya`, `edition`, `reviews` | Copied to the manifest. `id` and `version` name the output directories |
| `sources.text`, `sources.edition_map` | Each: `file` (relative path), `file_sha256` (the SHA-256 the file must have), `registry_row`, `name`, `publisher`, `url`, `version`, `fetched_on`, `trust_grade`, and `licence` with `text`, `permission_ref` and `allows_export`. There is no `notice`: it is taken verbatim from the comment of the source file, and is `null` for a file with none (Tanzil's metadata). `options` come from the query of `url` (every parameter but `agree`), `null` when there is none; they record what the URL holds, so a box left unticked has no key. The edition-map source's `version` must be the `version` attribute of the metadata file's root element |
| `mark_table` | Path of the mark table, `{"code_points": ["U+06D6", ...]}`. The real table is B0.4's |

The totals a riwaya must reach are in `profiles.py`, not in the description, so a
description cannot relax them. `riwaya: "synthetic"` is the synthetic source's
shape and goes with ids that begin with `synthetic-`, and only with them.

## Checks

Every check stops the build with a message naming addresses, numbers and code
points only. The build then runs the verifier on the finished pack before moving
it into place, so every verifier check is also a build check.

### PRD §9.4

| §9.4 check | Where |
| --- | --- |
| 114 surahs; ayat and words as in the source | `profiles.py`: `hafs` needs 114 surahs and 6,236 ayat (registry row 1), and 30 juz, 60 hizb, 240 rub and 604 pages. `source_checks.check_structure`: the text file's surahs and ayat per surah equal the metadata's `ayas` and `start`. The word and mark rows are counted from the tokens and recounted independently by the verifier |
| Tanzil compared with KFGQPC character by character under a table of known differences | `compare.py` with `known_differences.json` (B0.2, D-175; see "The KFGQPC comparison"). A `hafs` build runs it and refuses on any undocumented difference; it then stops because manifest format 1 cannot record the KFGQPC file. The unapproved test copy skips it (below); the synthetic profile does not need it |
| Displayed text equals pack text | App side (`test/integrity/`). The pipeline's part: every stored text is read back as bytes and compared with the source bytes at its offset |
| No Unicode normalisation in code | `tests/test_guards.py`: no `normalize` or `casefold` call, no lossy decoding, no tolerant XML parser in the pipeline; every Python file is ASCII, so test data is written as `\u` escapes |
| Every record points to an existing address | `source_checks.divisions`, `sajdas`, `check_points` (juz, quarter, page, manzil, ruku, sajda, each after the one before); verifier: divisions, sajdas, words and marks, plus `foreign_key_check` |
| First and last word of each line of the 604 pages | Page packs only; not a text-pack check |
| Manifest signature and file hash | File size and SHA-256 in the verifier at build time; the source files' SHA-256 against `file_sha256` before reading; the signature through `sign` and `verify-signature` |

### The format and the review (docs/CONTENT_PACKS.md)

| Rule | Where |
| --- | --- |
| Values stored byte for byte; no value begins with U+FEFF | `strict_xml.py` keeps each value's offset and length and refuses a leading U+FEFF; `build._read_back` compares the stored bytes with the source bytes; the database and manifest writers refuse a leading U+FEFF again |
| SQLite 3.37 or later; its version printed | `database.require_sqlite`; `build` prints it |
| `encoding`, `application_id`, `user_version`, `STRICT`, no WAL, `VACUUM` | `database.py`; verifier: header bytes 18, 19, 36, 56, 60, 68 and the schema through `pragma_table_list` and `pragma_table_xinfo` |
| Words and marks (D-078, D-083): only U+0020 separates (categories Z and Cc, and the zero-width U+200B and U+2060, are refused); a token with a letter (category L) is a word, any other a mark; UTF-16 offsets; `after_word` | `tokens.py`; the verifier recomputes every span and compares row by row |
| P3: a letterless token outside the mark table stops the build | `tokens.spans` with `mark_table.py` |
| P2: juz, quarters and pages from the metadata; a hizb is every fourth quarter by position | `source_checks.divisions`; refuses a quarter count that is not a multiple of 4. `compare.py` compares the page and the juz of every ayah with the KFGQPC file's `page` and `jozz`, and the metadata's quarter starts with KFGQPC's (the ayat that open with its quarter sign, and the surah openings P-3 accepts); any difference stops |
| P4: basmala from the separate field; none for surahs 1 and 9, present elsewhere | `tanzil_text.py` (only on ayah 1); `source_checks.check_structure` with the profile's `without_basmala` |
| P6: revelation place through a fixed table, others refused; order from the metadata | `source_checks.revelation`: `Meccan` to `makki`, `Medinan` to `madani`; the orders must be 1 to n, each once |
| D-077: `options` from the source | `options.options_from_url` |
| D-079: no U+06DE; pause marks and sajda signs present | Whatever the URL says: `source_checks.check_profile_signs` with the profile's `forbidden_code_points` (U+06DE) and `required_code_points` (a pause mark U+06D6 to U+06DB, and U+06E9), over every ayah and basmala. In addition `options.options_from_url` refuses a checkbox option whose value is not `true` before any file is read, and `options.option_problems` checks what the URL says: `sajdah` and `marks` present mean a sign occurs, `rub` absent means U+06DE does not, and `source_checks.check_sajda_signs`, with sajda signs, that the ayat holding U+06E9 are exactly the metadata's sajdas |
| Notice kept verbatim | The single comment of the text file goes into its `licence.notice` and must name `Version <version>` of the description. The metadata file has no comment: its `licence.notice` is `null`, and a comment, if the file ever has one, is kept verbatim; two are refused. The metadata `version` is the root element's `version` attribute, checked against the description (`source_checks.check_metadata_version`); the text's version is checked in its notice |
| A code point the font lacks stops the build | `source_checks.check_font_coverage` over every ayah and basmala; the font must be Amiri Quran (PRD §9.1, text and font are one pair) |
| `id` and `version` equal the directory names; strict manifest | Verifier, mirroring `lib/data/models/pack_manifest_json.dart` |
| A failed build leaves no pack and no partial file | Built in `<out>/.build-*`, moved into place only after the verifier passes; removed on any failure (the output directories it created may stay, empty) |

The font is read once, by `font.py`; the verifier and the build's coverage check
both use what it read, so font coverage has one implementation. The font's hash,
family and version are checked independently by the app's integrity suite against
the pinned font file; the app has no coverage check.

What the verifier adds to the app's checks: it refuses any file in the pack
directory besides `manifest.json`, `text.sqlite` and `manifest.json.sig`; a
signature that is not 64 bytes; views, triggers and indexes other than automatic
ones; and, with `--font`, code points the font lacks.

### Test-copy mode (D-165)

`build --unapproved-test-copy` builds a Hafs pack for the owner's own phone before B0.2
to B0.4 exist (D-162 (13)). It skips the KFGQPC comparison, and nothing else. It
refuses `--kfgqpc` and `--table`, so a test copy cannot appear compared: the totals, the Tanzil notice and version, the options, the font
coverage, the mark check, the read-back, the digests and the independent verifier all
run as for any pack. It has its own refusals, each a `PackError` (exit 65) before
anything is written, and each proved by a test:

| Refusal | Where | Test |
| --- | --- | --- |
| The flag with an id that does not begin with `unapproved-` | `profiles.profile_for` | `test_profiles.py`, `test_build.py` (`test_the_flag_without_the_prefix`) |
| The prefix without the flag, for any riwaya | `profiles.profile_for` | `test_profiles.py`, `test_build.py`, `test_cli.py` |
| The flag for a riwaya other than `hafs` | `profiles.profile_for` | `test_profiles.py`, `test_build.py` (`test_the_flag_for_a_riwaya_other_than_hafs`) |
| A non-empty `reviews`: a review would present the copy as approved | `build._check_test_copy` | `test_build.py`, `test_cli.py` |
| An output folder inside a Git working tree: itself or any parent holds `.git` (a folder, or a file in a worktree or a submodule), links followed, so no `git` program is needed | `build._git_tree` | `test_build.py` (folder, file, symbolic link), `test_cli.py` |
| A plain `hafs` build, and any build without the flag | `build.build_pack` | `test_build.py`, `test_cli.py`: as before |

The totals of the real `hafs` profile are not relaxed: the mode on a source of another
shape stops at the surah count (`test_every_other_check_still_runs_on_the_real_hafs_profile`).
The pack carries no marker field, since the manifest accepts none: the `unapproved-`
id is the marker, and the app will refuse it unless it is told to read a test copy
(D-163, T1 of `docs/plans/TEST_COPY.md`: not built yet). The mark table comes from the build description, as always; the test copy
uses `tools/test_copy/provisional_marks.json`. `tools/test_copy/` holds the owner's
script and steps (`tools/test_copy/README.md`). `sign` and `verify-signature` take PEM
keys through OpenSSL and need no change for it.

The tests cannot build a real Hafs pack: they patch the `hafs` profile with the
synthetic source's totals (`tests/build_support.hafs_shaped_profiles`) and use the
synthetic source. No real Quran text or metadata is in the repository or fetched by
any test.

## The KFGQPC comparison (B0.2, B0.3, D-175, D-177)

PRD 9.4: a `hafs` pack is approved only if the Tanzil text equals the KFGQPC Hafs
text character by character, except for differences listed in a documented table;
P2: the page of every ayah agrees between the two sources. The comparison also
reports the juz of every ayah and the quarter starts. The owner decided (D-176) that
pages, juz and quarters will come from the KFGQPC file; the build still takes them
from Tanzil's metadata until a manifest change after his reciter's review, and a
disagreement still fails the comparison either way. The KFGQPC file is a
witness. Nothing of it reaches a pack.

### Inputs

- The Tanzil text XML and `quran-data.xml`, read by the same readers as `build`.
- `hafsData_v2-0.json` from `UthmanicHafs_v2-0.zip`, KFGQPC Hafs update 2.0 (read.me:
  "Version: 2.0, Date: 2022-09-07, Update: 13.0"), under that name, exactly as
  published: UTF-8 without a BOM (its first bytes are `5B 0A 09`; the CSV of the same
  zip is the file with the BOM). A file that begins with a BOM is not the published
  form and is refused. `kfgqpc.py` reads
  `id`, `jozz`, `page`, `sura_no`, `aya_no` and `aya_text`. It type-checks
  `sura_name_en`, `sura_name_ar`, `line_start`, `line_end` and `aya_text_emlaey`
  but does not compare them. The report records the file's SHA-256, registry
  row 2 and version "2.0 (update 13.0)". The published MD5 and SHA-1 are of the
  zip; whoever extracts the JSON checks them first.
- `known_differences.json`, the table.

### The table

ASCII only, strict JSON: `{"format": "holyquran-known-differences", "version": n,
"rules": [...]}`. Every rule has `id`, `kind`, `code_points` (each written `U+XXXX`),
`applies_to`, `reason`, `approved_by` and `date`; nothing else.

| Kind | `applies_to` | `code_points` | What the comparison does |
| --- | --- | --- | --- |
| `presentation` | `ayah_end` | `separator`, `first_number_glyph` | Checks that the KFGQPC ayah n ends with the separator and the code point `first_number_glyph + n - 1`, then removes both. Any other ending is a problem, and the ending is then left in place, so it also shows as a difference |
| `presentation` | a sorted list of `hafs:S:A`, each listed by one such rule at most | `separator` | At the listed ayat only, the `ayah_end` rule's separator is this one instead; the number glyph is checked as `ayah_end` checks it. A listed ayah that ends otherwise, including with the usual separator, is a problem. Needs the `ayah_end` rule and a separator other than its own |
| `presentation` | `quarter_start` | `sign`, `separator` | Removes the sign and the separator where both open an ayah. An ayah that opens with the sign is a KFGQPC quarter start; the sign without the separator after it is a problem and is left in place. The sign and separator anywhere else in an ayah are not removed, so they show as a difference |
| `presentation` | `surah_opening_quarter_start` | `sign` (the `quarter_start` rule's) | At the first ayah of a surah that the metadata lists as a quarter start, accepts that KFGQPC carries no sign and counts the ayah as a KFGQPC quarter start. A first ayah of a surah that opens with the sign is a problem. Applies nowhere else. Needs the `quarter_start` rule |
| `equivalence` | `every_ayah`, or a sorted list of `hafs:S:A` | `kfgqpc` (a non-empty sequence), `tanzil` (a sequence, possibly empty) | On the KFGQPC side, after presentation, rewrites each occurrence of the KFGQPC sequence as the Tanzil sequence, in one pass from left to right. At each position the first listed rule that matches wins, and rewritten code points are not matched again. A rule that applies in no ayah, or not in one of its listed ayat, is a problem |

Version 2 ships four presentation rules and no equivalence rule:

- P-1 (`ayah_end`) and P-2 (`quarter_start`), approved by `lead (presentation,
  D-175)`, from KFGQPC's read.me ("Adding non-breaking space before aya mark",
  "Adding Aya mark as Symbol", "Adding non-breaking space after jozz/hizb symbol")
  and from D-079, which keeps U+06DE out of the base text.
- P-3 (`surah_opening_quarter_start`) and P-4 (`["hafs:2:286"]`, separator U+0020),
  approved by `lead (presentation, D-177)`, from the lead's run on the real files:
  42 quarter starts that open a surah carry no U+06DE in KFGQPC, and 2:286 ends with
  U+0020 before its number glyph U+FD1D (the read.me lists "Fixing the Aya Mark in
  Sura number 2 (Al-Baqarah) Aya 286"). P-4 names that one address.

P-3 takes Tanzil's word for the 42 surah-opening quarter starts: KFGQPC marks none
of them, so the comparison cannot confirm or refute them, and a quarter that opens a
surah in KFGQPC's mushaf but not in Tanzil's metadata is not seen either. The
reciter's review of the divisions (D-176) has to check those 42 itself.

The tests use the shipped table without P-4, which names an ayah the synthetic text
does not have; a listed address outside the text stops the comparison.

**Adding an equivalence rule.** The orthographic differences between the two files
(for example KFGQPC's U+06E1 where Tanzil has another sukun form, or Tanzil's U+06DF)
are not for the pipeline or the lead to decide. The lead runs `compare`. The owner
and his proofreader read the `patterns` of the report, in the mushaf where needed,
and approve each one. Then, for each approved pattern:

1. Add a rule with a new `id`, `kind: "equivalence"`, the two sequences exactly as
   the report gives them, `applies_to` as narrow as the approval (the listed
   addresses, or `every_ayah` only if the approval covers every ayah), the
   `reason`, `approved_by` naming the people who approved it, and the `date`.
2. Raise `version` by one.
3. Run `compare` again: the pattern must be gone and the rule must be applied. Record
   the new version and SHA-256 with the approval (D-175).

The reader refuses an equivalence whose `approved_by` begins with "lead". That only
catches a slip; the safeguard is the review of the table's change and the approval
recorded with D-175.

### Comparing

Per ayah: P-1 (P-4 at its address), then P-2 and P-3, then the equivalences, then
`difflib.SequenceMatcher` (no junk heuristic) over the code points of the two sides.
Nothing is normalised or trimmed: white space before or after `aya_text`, U+00A0
included, is a difference. Canonically equivalent orders are a difference. The two
files must list the same ayat in the same order, and the metadata's juz, quarter and
page lists must be valid points from 1:1, or the command stops before comparing.

The divisions (P2): the page and juz of every ayah (the last metadata start at or
before it) must equal the KFGQPC `page` and `jozz`. KFGQPC's quarter starts are the
ayat that open with U+06DE, and the surah openings P-3 accepts; each ayah that starts
a quarter in one source only is a quarter difference, reported with both sources'
quarter starts around it. Without a `quarter_start` rule KFGQPC's quarters are not
known, and that is a table problem. Tanzil's basmala attribute has no counterpart in
the KFGQPC table and is not compared.

### The report

JSON, ASCII only: `encode_report` refuses any other byte, so no character of either
text can be written. Each list has one entry per line. Any one sequence is given as
at most 8 code points (`compare.SEQUENCE_CAP`), with its full length as a number.

The report still describes the text code point by code point. A `--report` file is
kept on the owner's machine only: it is never committed, attached to an issue or a
pull request, or uploaded anywhere. Summaries go elsewhere as counts and addresses.
The tools never print a Quran character: their output is counts, hashes, paths,
addresses and `U+XXXX`.

| Key | Holds |
| --- | --- |
| `format`, `tanzil`, `kfgqpc`, `table` | `holyquran-kfgqpc-comparison`; the SHA-256 of the Tanzil text and metadata files compared, so an approval made from the report can be tied to the files a pack is built from; the KFGQPC file's registry row, name, version and SHA-256; the table's version and SHA-256 |
| `ayat`, `rules` | Ayat compared; each rule with how many times it applied |
| `presentation_problems` | `address`, `rule`, `problem`, and the code points `found`: the two at the ayah's end when P-1 or P-4 fails, the two at its start when P-2 finds the sign without its separator |
| `table_problems` | Equivalences that did not apply; a table without a `quarter_start` rule |
| `differences` | Per difference: `address` (`hafs:S:A`), `word` (the D-083 word number in the Tanzil ayah where it begins; 0 before the first word), `in_mark` (it begins in a mark token, after that word), and for `kfgqpc` (after the table) and `tanzil` the `sequence` (capped), its `length`, and up to two code points `before` and `after` |
| `patterns` | Each distinct KFGQPC-to-Tanzil pair (`kfgqpc`, `tanzil`, capped, with `kfgqpc_length` and `tanzil_length`) with its `count` and its `first` three addresses, by count, then by code points |
| `page_differences`, `juz_differences` | `address`, the KFGQPC value, the metadata's value |
| `quarter_differences` | `address`, whether it starts a quarter in KFGQPC (`kfgqpc_quarter_start`) and in the metadata (`tanzil_quarter_start`), and `kfgqpc_quarters` and `tanzil_quarters`: in each source the two quarter starts before the ayah, the one at it if any, and the two after, each as `{"quarter": n, "start": "hafs:S:A"}` |
| `passed` | True only when every list above is empty |

### In the build, and what stops it

A non-test `hafs` build runs every other check, then the comparison. On any problem
it refuses with the summary counts and points to `compare` for the report. On a
pass it still refuses. Manifest format 1 (`docs/CONTENT_PACKS.md`) allows the source
roles `text` and `edition_map` only and has no field for the table, so neither the
KFGQPC file nor the table's version can be recorded in the pack. The format is not
changed here; the lead decides (D-175).

### The P5 counts

`kfgqpc-counts` reads the KFGQPC file alone, against the `hafs` profile (114 surahs,
6,236 ayat), and writes:

```json
{
  "kfgqpc_file": {"registry_row": 2, "name": "hafsData_v2-0.json", "version": "2.0 (update 13.0)", "sha256": "<hex>"},
  "date": "YYYY-MM-DD",
  "surahs": {"1": 0, "2": 0},
  "total": 0
}
```

with all 114 surahs. The lead runs it where the KFGQPC file is, and commits the
result as `testing/reference/kfgqpc-hafs-counts.json`.

## Signing (D-080) and what O-03 must decide

The format keeps `manifest.json.sig` absent until D-024 is decided, and the
manifest has no field for a signature state (unknown fields are refused). So an
unsigned pack is one without that file, and `build` and `verify` say so on every
run. No key exists in this repository; the tests generate throwaway Ed25519 keys
in a temporary directory.

The seam is `signing.Signer`, with one method `sign(data) -> 64 bytes`.
`OpenSslEd25519Signer(key_path)` runs `openssl pkeyutl -sign -rawin` (OpenSSL 3), so
whoever holds the key needs nothing but OpenSSL; a test double stands in for it
in the tests. `sign_pack` signs the exact bytes of `manifest.json` and refuses a
pack already signed; `pack.py sign` verifies the pack first, with its font and
mark table.

O-03 still decides: who holds the private key and on which machine signing runs
(the owner's computer, a CI secret, or a hardware token); how the key is backed
up; and which public keys the app accepts, since D-080 keeps a list so a key can
be replaced. Another kind of signer, such as a hardware token, would be another
`Signer`; nothing else changes.

## Not done here

- Recording the KFGQPC file and the table in the manifest. Format 1 has no place for
  them, so a `hafs` build stops after a passing comparison (D-175). Until the lead
  decides, no approved `hafs` pack is built; only the unapproved test copy (D-165,
  "Test-copy mode"), which never leaves the owner's machine.
- Equivalence rules. The orthographic differences the comparison reports are
  approved, or not, by the owner and his proofreader. The lead's run on the real files
  with table version 1 (the BOM check relaxed in memory) gave 44 presentation problems,
  56 page differences and 2 juz differences (`hafs:3:92`, `hafs:9:93`). Version 2
  turns 43 of the 44 into P-3 and P-4. The last, `hafs:15:49`, which opens with the
  sign where the metadata starts no quarter, is not a rule: it is a quarter difference.
  The page, juz and quarter differences still fail the comparison; D-176 settles
  which source the build will use once the manifest can say so. Version 2 has not yet
  been run on the real files.
- `testing/reference/kfgqpc-hafs-counts.json` itself (P5): the tool is here; the file
  is made from the real KFGQPC file.
- Reading the JSON straight from `UthmanicHafs_v2-0.zip`, where the published MD5 and
  SHA-1 could be checked by the tool.
- The basmala of surahs 2 to 114 (without 9) has no counterpart in the KFGQPC table
  and is not compared.
- The real mark table of code points (B0.4). The test copy uses the provisional
  table of `tools/test_copy/`, from the Unicode chart, until then.
- The structure of the real `quran-data.xml` (no notice comment, root `version="1.0"`) and
  the text file's notice are taken from their published form and from the owner's first
  test-copy build (D-172); the readers stop on anything else. Tanzil's `tatweel` and
  `stanween` options are refused unless `true` but their signs are not yet checked in
  the text.
