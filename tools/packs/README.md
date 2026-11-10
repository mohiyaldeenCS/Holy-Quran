# tools/packs — the content pack pipeline

Turns a text source file and its metadata file into a verified text pack of format
v1 (`docs/CONTENT_PACKS.md`, D-064, as amended by D-077, D-078, D-079 and D-083).
Python 3.9 or later, standard library only (D-035); SQLite 3.37 or later. Task B0.11.
It also writes and verifies the tafsir pack of format 2 (kind `tafsir`, with the
surah-level passage of D-184; B0.7, task B1); the command that builds one from the
Zaydi Library extraction is task B2's.

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
| `database.py` | `text.sqlite` with the exact DDL, `encoding`, `application_id`, `user_version`, `STRICT`, `journal_mode = DELETE`, ending with `VACUUM`; read-back of every stored text as bytes. The file rules every data file shares, each naming its file: create a new file, the header with the kind's `user_version`, a step whose SQLite error is named by type only, the text check (no leading U+FEFF, no lone surrogate), removal on failure | `require_sqlite(file)`, `write_text_database(path, surahs, divisions, sajdas)`, `read_stored_texts(path)`, `create_new(path, file)`, `set_header(db, user_version, file)`, `run(db, sql, step, parameters, file)`, `check_text(value, where, file)`, `remove_partial(path)` |
| `tafsir_database.py` | `tafsir.sqlite` of format 2 (B0.7, D-184): the exact DDL of "Tafsir pack", `user_version` 2, one book row, the passages as given (a surah-level passage is the reserved range `0..0`, admitted by the table's CHECK, one per surah by `UNIQUE (surah, first_ayah)`), ending with `VACUUM`; refuses no passage, a non-integer number, a leading U+FEFF or a lone surrogate, and leaves no file; read-back of the book's facts and every passage as bytes | `write_tafsir_database(path, BookFacts(title, author, publisher, edition, editor), [PassageRow(number, surah, first_ayah, last_ayah, text)])`, `read_tafsir_texts(path) -> StoredTafsirTexts(book: {column: bytes or None}, passages: {number: bytes})`, `SURAH_LEVEL` |
| `manifest.py` | The manifest's fields in the format's order, and its bytes (UTF-8, no BOM, two-space indent, final line break). A tafsir manifest is format 2 with no `edition`, `font` or `surah_sha256`, `tafsir` sources only, `files` `tafsir.sqlite` and `counts` `{"passages": n}`, `n` at least 1 | `build_manifest(...) -> dict`, `build_tafsir_manifest(pack_id, version, changelog, riwaya, sources, tafsir_sha256, tafsir_bytes, passages, reviews) -> dict`, `source_entry(...)`, `encode_manifest(dict) -> bytes` |
| `ayah_counts.py` | The P5 counts file read back strictly: ASCII, the bytes `kfgqpc_counts.encode_counts` writes (keys, order, indentation, final line break), the KFGQPC file it names (registry row 2, its name and version), a calendar date, surahs `"1"` to `"n"` in order with positive integer counts, and a total equal to their sum | `read_ayah_counts(data) -> {surah: count}` |
| `config.py` | The build description: pack identity, both sources' registry fields, expected source SHA-256, the mark table, reviews. Strict JSON | `read_build_config(path) -> BuildConfig` |
| `profiles.py` | What a riwaya must hold: surah and ayah totals, division counts, which surahs have no basmala, whether the KFGQPC comparison is required | `PROFILES`, `profile_for(riwaya, pack_id, unapproved=False)` |
| `build.py` | The pipeline: hash and read the sources, run every build check, write into a temporary directory, read back, write the manifest, run the verifier, then move into `<out>/<id>/<version>/` | `build_pack(config_path, font_path, out_root, unapproved=False) -> BuildResult` |
| `verify.py` | An independent verifier of a pack directory, sharing no code with the writer beyond `errors.py`: everything the app and its integrity suite check, recomputed from the stored bytes. Its directory, file-hash, location and header checks serve every kind; `pack_kind` reads the manifest's `kind` so that `verify` and `sign` pick the verifier | `verify_pack(directory, mark_code_points=None, font=None) -> Report(problems, counts, signed)`, `pack_kind(directory) -> str or None` |
| `verify_tafsir.py` | The independent verifier of a tafsir pack (B0.7, D-184), with its own copy of the DDL: the kind's manifest keys and rules; the header (application id, `user_version` 2, DELETE journal, UTF-8, no free pages, so the build ended with `VACUUM`); exactly the tables `book` and `passage`, STRICT, their columns, and their CREATE statements as the format gives them (so a missing CHECK or UNIQUE is found); no other schema object; `integrity_check`; one book row; numbering 1 to n; mushaf order with a surah's surah-level passage first; no overlap; every range within the P5 counts (`0..0`, or from ayah 1 to the surah's last); strict UTF-8, not empty, no U+FEFF anywhere; no extra file; `counts.passages`; with a font, every code point but U+000A, U+2009 and U+2063 | `verify_tafsir_pack(directory, ayah_counts, font=None) -> Report(problems, counts, signed)` |
| `signing.py` | The signing seam (D-080, O-03): `Signer` with `sign(data) -> 64 bytes`; `OpenSslEd25519Signer(key_path)` runs `openssl pkeyutl -sign -rawin`; `sign_pack` writes `manifest.json.sig` for a pack that verifies; `verify_signature` checks it with a public key | `sign_pack(directory, signer)`, `verify_signature(directory, public_key_path)` |
| `cli.py` | `build` (with `--unapproved-test-copy`, `--kfgqpc`, `--table`), `verify` and `sign` (both by the pack's kind), `verify-signature`, `compare`, `review-page`, `kfgqpc-counts`, `drift`; prints counts, hashes, paths and `U+XXXX` only | `main(argv) -> exit code` |
| `kfgqpc.py` | KFGQPC's `hafsData_v2-0.json` (registry row 2, B0.2, D-175, D-177): UTF-8 without a BOM, as published (a BOM is refused, and so is a file whose first bytes are not `5B 0A 09`), an array of objects with exactly the read.me's eleven columns, integers and strings typed strictly, ids 1..n in order, ayat in mushaf order; the published file name | `read_kfgqpc(data, ayat) -> [KfgqpcAya(id, surah, number, juz, page, text)]`, `read_kfgqpc_file(path, ayat) -> (ayat, sha256)` |
| `known_differences.py` | The table of known encoding differences, `tools/packs/known_differences.json` | `read_table(data) -> Table(version, ayah_end, ayah_end_separators, quarter_start, surah_opening_quarter_start, equivalences)`, `Table.ayah_end_rule_at(address) -> Rule or None` |
| `compare.py` | The comparison of PRD 9.4 and the page, juz and quarter comparison of P2; the report; with a `Trace`, every difference as a `Place` (the two whole ayat and the difference's range in each, in memory only) for the review page | `run_comparison(text, metadata, kfgqpc_path, table_path, profile, tanzil_sha256, trace=None) -> report` (`tanzil_sha256` is `{"text": hex, "metadata": hex}`), `compare(text, metadata, witness, table, trace=None) -> report`, `summary(report)`, `encode_report(report) -> bytes` |
| `review_page.py` | The reciter's review page (D-176, D-178): runs the comparison, sorts the differences into sections A to C, checks the fonts and the output folder, writes the page and the two fonts | `write_review_page(text, metadata, kfgqpc, table, tanzil_font, kfgqpc_font, out, profile) -> ReviewResult`, `classify(places) -> Sections(a, b, c)` |
| `review_html.py` | The page's HTML from `review_page.html` (frame, style, script) and `review_page.ar.json` (the Arabic labels); the only path from a source text to the page is `parts`, checked by `check_parts` | `render(Page) -> str`, `marked_span(text, start, end)`, `parts(text, start, end)` |
| `git_tree.py` | Whether a path is inside a Git working tree, without a `git` program | `git_tree(path) -> directory or None` |
| `kfgqpc_counts.py` | The P5 reference counts from the KFGQPC file alone (B0.3) | `kfgqpc_counts(path, date, profile)`, `encode_counts(counts) -> bytes` |
| `mp3.py` | A strict MPEG audio Layer III reader that decodes no sample (B0.5, D-179): skips one ID3v2 tag at the start (its footer only for ID3v2.4) and an ID3v1 and an APEv2 tag at the end (128 bytes from `TAG` are audio when the frame walk ends exactly at the end of the file), walks every frame header (MPEG 1, 2, 2.5; free bitrate and Layers I and II refused), reads a Xing, Info or VBRI info frame, whose frame count must equal the audio frames or exceed them by one (`xing_count`: `equal` or `includes_info_frame`, else refused), and a LAME tag, whose delay and padding are used only when its CRC-16 holds (`lame_tag`: `none`, `valid` or `crc_mismatch`); refuses a lost sync, a truncated frame, or a change of MPEG version, sample rate or channel count, naming the byte offset | `read_mp3(data) -> Mp3Audio(version, sample_rate, channel_mode, channels, frames, samples_per_frame, frame_ms, granule_ms, duration_ms, delay_known, encoder_delay, padding, lame_tag, xing_count, granules: [Granule(start_ms, channels: ((part2_3_length, global_gain), ...))])` |
| `quran_align.py` | quran-align word timing (registry row 6), strictly: every ayah of the profile once, integer fields, word indices increasing; a segment whose times cannot be right is kept and marked defective, and an entry without segments is an ayah without timing (D-179) | `read_timing(data, profile, metadata=None) -> {(surah, ayah): Timing(surah, ayah, segments: [Segment(word_start, word_end, start_ms, end_ms, defects)], segments_field)}`, `Timing.sound()` |
| `drift.py` | The drift measurement between a timing file and a folder of per-ayah MP3 files, and its verdict (see "Recitation drift") | `run_drift(timing, audio_dir, edition, profile, text_path=None, metadata_path=None) -> report`, `encode_report(report) -> bytes`, `lines(report)`, `verdict(summary)` |

`pack.py` (next to this file) runs the CLI; `synthetic_source.py` writes the synthetic
source files, mark table and build description into a directory.

### Tests

`tests/test_<module>.py` for each module (`test_drift.py` covers `drift.py` and `quran_align.py`), plus `tests/test_build.py` (end to end on
the synthetic source, and one refusal per build check) and `tests/test_cli.py`.


As built, `build.py` delegates the checks that compare the two source files and
the profile to `source_checks.py`, and the verifier is split into `verify.py`,
`verify_manifest.py`, `verify_database.py` and `verify_spans.py`; the interfaces
are as planned. The tafsir verifier's synthetic packs and faults come from
`tests/tafsir_pack_factory.py`, as the text verifier's come from
`tests/pack_factory.py`.

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
python3 tools/packs/pack.py verify <out>/<tafsir id>/<version> --ayah-counts testing/reference/kfgqpc-hafs-counts.json [--font assets/fonts/IBMPlexSansArabic-Regular.ttf]
python3 tools/packs/pack.py sign <out>/<id>/<version> --key <ed25519 private key> --font <ttf> --mark-table <marks.json> [--openssl openssl]
python3 tools/packs/pack.py sign <out>/<tafsir id>/<version> --key <ed25519 private key> --font assets/fonts/IBMPlexSansArabic-Regular.ttf --ayah-counts testing/reference/kfgqpc-hafs-counts.json [--openssl openssl]
python3 tools/packs/pack.py verify-signature <out>/<id>/<version> --public-key <ed25519 public key> [--openssl openssl]
python3 tools/packs/pack.py build --config <build.json> --font assets/fonts/AmiriQuran-Regular.ttf --out data/build --kfgqpc <hafsData_v2-0.json> --table tools/packs/known_differences.json
python3 tools/packs/pack.py compare --text <tanzil xml> --metadata <quran-data.xml> --kfgqpc <hafsData_v2-0.json> --table tools/packs/known_differences.json --report <out.json>
python3 tools/packs/pack.py review-page --text <tanzil xml> --metadata <quran-data.xml> --kfgqpc <hafsData_v2-0.json> --table tools/packs/known_differences.json --tanzil-font assets/fonts/AmiriQuran-Regular.ttf --kfgqpc-font <uthmanic_hafs_v20.ttf> --out <new folder outside every Git tree>
python3 tools/packs/pack.py kfgqpc-counts --kfgqpc <hafsData_v2-0.json> --date <YYYY-MM-DD> --out testing/reference/kfgqpc-hafs-counts.json
python3 tools/packs/pack.py drift --timing <quran-align json> --audio <folder of SSSAAA.mp3> --edition <folder name> [--text <tanzil xml> --metadata <quran-data.xml>] [--report <out.json outside every Git tree>]
```

| Command | Does |
| --- | --- |
| `build` | Reads the build description, runs every build check below, and writes `<out>/<id>/<version>/` with `manifest.json` and `text.sqlite`, unsigned. An existing version directory is refused: a released pack is never rebuilt in place. A `hafs` build needs `--kfgqpc` and `--table` and runs the KFGQPC comparison after every other check; any other build refuses both. Today a `hafs` build stops there even when the comparison passes (see "The KFGQPC comparison"). `--unapproved-test-copy` builds the owner's local test copy (see "Test-copy mode") |
| `verify` | Runs the independent verifier of the pack's kind (`pack_kind`). A text pack: with `--font` and `--mark-table` it also checks the font pair and every mark; `--ayah-counts` is a usage error. A tafsir pack: `--ayah-counts` (the P5 file) is required and checks every range; with `--font` it checks coverage; `--mark-table` is a usage error |
| `sign` | Verifies the pack as `verify` does, then writes `manifest.json.sig` with OpenSSL (D-080). A text pack needs `--font` and `--mark-table`, a tafsir pack `--font` and `--ayah-counts`. Refuses a pack that already has one |
| `verify-signature` | Checks `manifest.json.sig` against a public key |
| `compare` | Runs the KFGQPC comparison against the `hafs` profile (6,236 ayat) and writes the report; exits 65 when the report has any problem, 0 when it has none |
| `review-page` | Runs the KFGQPC comparison and writes the reciter's review page into a new or empty folder outside every Git working tree (see "The reciter's review page"); exits 0 when the page is written, whatever the comparison found |
| `kfgqpc-counts` | Writes the P5 reference counts of the KFGQPC file; `--date` is the day they are taken, so the same file and date give the same bytes |
| `drift` | Measures drift between a recitation's quran-align timing and a sample of its everyayah files, prints one line per file, the summary and the verdict, and writes the report if `--report` is given (see "Recitation drift"); exits 0 on PASS and 65 on FAIL, whatever the word index problems |

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
| An output folder inside a Git working tree: itself or any parent holds `.git` (a folder, or a file in a worktree or a submodule), links followed, so no `git` program is needed | `git_tree.git_tree` | `test_build.py` (folder, file, symbolic link), `test_cli.py` |
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
  zip; whoever extracts the JSON checks them first. A file whose first bytes are not
  `[`, a line feed and a tab is not the published form and is refused.
- `known_differences.json`, the table.

### The table

ASCII only, strict JSON: `{"format": "holyquran-known-differences", "version": n,
"rules": [...]}`. Every rule has `id`, `kind`, `code_points` (each written `U+XXXX`),
`applies_to`, `reason`, `approved_by` and `date`; nothing else.

| Kind | `applies_to` | `code_points` | What the comparison does |
| --- | --- | --- | --- |
| `presentation` | `ayah_end` | `separator`, `first_number_glyph` | Checks that the KFGQPC ayah n ends with the separator and the code point `first_number_glyph + n - 1`, then removes both. Any other ending is a problem, and the ending is then left in place, so it also shows as a difference |
| `presentation` | a sorted list of `hafs:S:A`, each listed by one such rule at most | `separator`, a space character (Unicode category Zs; anything else is refused when the table is read) | At the listed ayat only, the `ayah_end` rule's separator is this one instead; the number glyph is checked as `ayah_end` checks it. A listed ayah that ends otherwise, including with the usual separator, is a problem. Needs the `ayah_end` rule and a separator other than its own |
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

## The reciter's review page (B0.2, D-176, D-178)

The owner decided (D-176) that his licensed reciter checks, against the printed Madinah
mushaf, every place where the two texts differ in pause marks or letters, approves or
rejects each encoding pattern before it becomes a rule of the table, and checks the
division differences. The report holds code points, which a reciter cannot read;
`review-page` shows him the places themselves.

```
python3 tools/packs/pack.py review-page --text <tanzil xml> --metadata <quran-data.xml> \
  --kfgqpc <hafsData_v2-0.json> --table tools/packs/known_differences.json \
  --tanzil-font assets/fonts/AmiriQuran-Regular.ttf --kfgqpc-font <uthmanic_hafs_v20.ttf> \
  --out <new folder outside every Git tree>
```

It runs the comparison with the same code as `compare` (`compare.compare` with a
`Trace`; the report is byte for byte the one `compare` writes), then writes into
`--out` `review.html`, `font-tanzil.ttf` and `font-kfgqpc.ttf`. The page is one
self-contained file: no network, no external script, style or font; the two fonts
are loaded by `@font-face` from the files beside it. It prints the inputs' SHA-256,
the comparison summary and the count of each section, and exits 0 once the page is
written, whatever the comparison found.

### What it refuses, before writing anything

| Refusal | Test (`tests/test_review_page.py`, `tests/test_cli.py`) |
| --- | --- |
| An output folder inside a Git working tree (itself or a parent holds `.git`, links followed), this repository included, as `test_copy.sh` refuses its work folder | `test_an_output_folder_inside_a_git_tree`, `..._inside_a_worktree_or_submodule`, `test_this_repository`, `test_review_page_refuses_a_folder_in_a_git_tree` |
| An output that exists and is not an empty folder | `test_a_non_empty_output_folder`, `test_an_output_that_is_a_file` |
| An output that is a link to nothing, or a folder that cannot be created (each a `PackError`, exit 65, not 70) | `test_an_output_that_is_a_dangling_link`, `test_an_output_folder_that_cannot_be_created` |
| An output folder that is no longer new or empty when the page is about to be written: the folder is checked again just before writing | `test_the_output_folder_is_checked_again_before_writing` |
| A KFGQPC font not named `uthmanic_hafs_v20.ttf` (its name in KFGQPC's zip); a Tanzil font other than Amiri Quran | `test_the_kfgqpc_font_under_another_name`, `test_a_tanzil_font_other_than_amiri_quran` |
| A shown code point the font of its source lacks, since a browser would draw it in another font | `test_a_font_that_lacks_a_shown_code_point` |
| A shown text holding U+0000 or U+000D, which HTML parsing would change | `test_a_text_html_would_change` |
| Whatever `compare` refuses (file names, BOM, counts, addresses) | `test_a_kfgqpc_file_the_comparison_refuses` |
| A marked text whose three slices do not join to its source text | `ReconstitutionMutationTest` |

### What the page shows

Arabic, right to left. A header says what the page is, that both texts are shown
exactly as in their sources, each in its own font (Tanzil in Amiri Quran, the app's
font; KFGQPC in its own font), and how to save and send the decisions file. It lists
the inputs' SHA-256 and the counts of the comparison, and warns until both fonts are
loaded.

Every difference of the report is in exactly one of sections A to C
(`review_page.classify`, `test_every_difference_appears_in_the_page_once`):

| Section | Holds | Shown |
| --- | --- | --- |
| A, pause marks and rare letters | Every difference whose KFGQPC or Tanzil sequence holds a pause mark (U+06D6 to U+06DB), and every difference of a pattern seen at most `RARE_COUNT` (3) times outside section C | Every place |
| B, encoding patterns | Every other pattern (KFGQPC sequence, Tanzil sequence), by count, then by code points | One card per pattern: the two sequences with Unicode names, the count, three examples (the first place at each of the first three addresses) |
| C, spaces before pause marks | A lone U+0020 in one source where the other has nothing, followed in that source by a pause mark | One card per direction, with five examples |
| D, divisions | The page, juz and quarter differences of the report (address, both values), and the surah openings P-3 accepts as quarter starts without a witness | One row each |

A place is the address as «سورة <name> (N)، آية M», with the name of `quran-data.xml`
as it stands, the word (D-083 numbering, as in the report), then the whole Tanzil
ayah and the whole KFGQPC ayah, one above the other, each labelled, and below them the
two differing sequences, each code point with its Unicode name. The KFGQPC ayah is
`aya_text` as published, so the quarter sign, the no-break spaces and the number glyph
the table removes are shown as they stand.

The differing word is marked with `<mark>`. The span (`review_html.marked_span`) runs
from the word token that holds the difference's start, or the last word token before
it, to the end of the last token the difference overlaps or touches. Tokens are those
of `tokens.token_spans`, the pipeline's own: maximal runs of characters other than
U+0020, a word if one holds a letter. So a pause mark is marked with the word before
it, a span never cuts a word, and the KFGQPC range is the comparison's own, carried
back through the equivalences and the removed opening (`compare.Place`). The text
reaches the page only as three slices at those offsets; `check_parts` refuses the page
unless they join to the source text, and the only other change is HTML escaping of
`&`, `<` and `>`, which the browser undoes. `test_every_marked_word_reconstitutes_its_source`
parses every text back out of the page and compares it with its source. `EscapingTest`
does the same with synthetic `<`, `&` and `</p>` in one ayah of each source, `<` in a
surah name and `</script>` in an input value, and checks that the header's inputs and
the script's data parse back exactly; `_script_json` writes `<` as `\u003c`, so nothing in
the data can close the script element (`ScriptJsonTest`).

### The decisions

Every place in A, card in B and C and row in D has the choice «موافق للمصحف المطبوع»
(`agrees`), «غير موافق» (`disagrees`) or «لم أتحقق» (`unchecked`, the default) and a
note. Each section states its question: in A, whether the Tanzil text, which the app
shows, agrees with the printed mushaf at the marked place; in B and C, whether the two
sequences stand for the same thing in the printed mushaf in every example, so that the
difference is one of encoding only; in D, whether KFGQPC's value agrees with the
printed mushaf, and for the surah openings, whether a quarter starts at that ayah.

The choices are kept in the browser's `localStorage` (under a key derived from the
inputs' hashes; a browser that refuses storage shows a warning, and so does saved
state of any other shape than the page writes, an `items` that is not a plain object
included, which is then not used: `loadState`, `test_saved_state_of_another_shape_is_refused`).
The progress counter counts the choices the decisions file would save as other than
`unchecked` (`checkedCount`), so the two always agree. «حفظ ملف القرارات»
needs the reviewer's name, typed at the top, and saves through a `Blob` download,
with no network, `kfgqpc-review-decisions-<date>.json`:

```json
{
  "format": "holyquran-kfgqpc-review-decisions",
  "version": 1,
  "reviewer": "<the name typed at the top>",
  "saved_at": "<ISO 8601 UTC, from the browser>",
  "inputs": {
    "tanzil_text_sha256": "<hex>", "tanzil_metadata_sha256": "<hex>",
    "kfgqpc_file": "hafsData_v2-0.json", "kfgqpc_version": "2.0 (update 13.0)", "kfgqpc_sha256": "<hex>",
    "table_version": 2, "table_sha256": "<hex>",
    "tanzil_font_sha256": "<hex>", "kfgqpc_font_sha256": "<hex>"
  },
  "decisions": [
    {"id": "A:hafs:S:A:3:U+064A>U+0649", "section": "A", "address": "hafs:S:A", "word": 3, "in_mark": false,
     "kfgqpc": ["U+064A"], "tanzil": ["U+0649"], "choice": "agrees", "note": ""},
    {"id": "B:U+06E1>U+0652", "section": "B", "kfgqpc": ["U+06E1"], "tanzil": ["U+0652"],
     "count": 4, "examples": ["hafs:S:A", "..."], "choice": "unchecked", "note": ""},
    {"id": "C:>U+0020", "section": "C", "kfgqpc": [], "tanzil": ["U+0020"], "count": 6,
     "examples": ["..."], "choice": "disagrees", "note": "..."},
    {"id": "D:page:hafs:S:A", "section": "D", "kind": "page", "address": "hafs:S:A",
     "kfgqpc": 3, "tanzil_metadata": 2, "choice": "unchecked", "note": ""}
  ]
}
```

One entry per item, in page order, each with its keys in this order and `choice` and
`note` last. Ids are built from what an item is, never from its position: an A id is
the address, the word and the two sequences (with `:2`, `:3` added for a repeat in the
same ayah), a B or C id the section and the two sequences, a D id the kind and the
address; so a choice kept in the browser cannot move to another item when the page is
rebuilt, and the storage key also changes with the decisions format. Sequences are
complete, not capped, and are those of the report: the KFGQPC side after the table.
A card counts the places of its section only: one report pattern, such as a lone
space, can be split between C (before a pause mark) and B or A (elsewhere). D's `kind` is `page`, `juz`, `quarter` (the values say whether
the ayah starts a quarter in each source) or `surah_opening_quarter` (`kfgqpc` false,
`tanzil_metadata` true). The shape is tested (`DecisionsShapeTest`; the script itself
is run under `node` where it is installed) and changes only with `version`.

### Pending human check

What only a browser can show is not tested here: the `node` test runs `decisionsFile`
alone, and is skipped where `node` is missing. Before the page goes to the reciter, the
owner opens `review.html` from its folder in the browser the reciter will use, on his
device, and checks that the font warning disappears (both fonts loaded from the
folder), that both texts are drawn in their fonts with the marked word shaped as in
the rest of the line, that a choice and a note survive a reload, and that «حفظ ملف
القرارات» saves a file of the shape above.

### Where the page and the decisions stay

The output folder holds the Quran text of both sources, and the decisions file may
hold the reviewer's notes. Both stay on the owner's machine, outside every Git working
tree: they are never committed, attached to an issue or pull request, or uploaded. The
owner gives the folder to his reciter himself, and the reciter sends the decisions
file back to him alone. Summaries go elsewhere as counts and addresses.

### From approved patterns to rules

The lead reads the decisions file the owner passes on, after checking that its `inputs`
are the hashes of the files the table is meant for (a file made from other inputs is
not used). Then:

1. For each B card marked `agrees`, add an `equivalence` rule (D-176's kind (b))
   as in "Adding an equivalence rule" above: the two sequences exactly as the card's
   `kfgqpc` and `tanzil` give them, `applies_to` `every_ayah` only if the card's
   approval covers every place of the pattern (otherwise the listed addresses), the
   `reason` citing the review and D-176, `approved_by` the reviewer's name as in the
   file's `reviewer` (never "lead"), and `date` the day of `saved_at`.
2. A C card gets no rule from the lead, even when marked `agrees`: the table cannot
   express it. An equivalence's KFGQPC sequence may not be empty, so "a space in
   Tanzil before a pause mark" cannot be written as one, and the reverse rule (U+0020
   to nothing) would delete every space it applies to. How to accept the space
   difference (a new rule kind tied to the following pause mark, or listed addresses)
   is the owner's decision, put to him with the reviewer's choice.
3. A card marked `disagrees` or `unchecked` gets no rule; its places stay differences
   and keep the comparison failing. Every place in A, whatever its choice, and every
   row in D goes to the owner as the reviewer marked it: they are not encoding
   patterns, and a rule for one is the owner's decision, not the lead's.
4. Raise `version`, run `compare` and `review-page` again: the approved patterns must
   be gone and their rules applied. Record the table's new version and SHA-256 and the
   decisions file's `inputs` with the decision that records the approval.

## Recitation drift (B0.5, D-167 (2), D-179)

A recitation is labelled «توقيت كلمات» only after the drift between its quran-align
timing file and the files everyayah.com serves today has been measured on a sample
(D-167 (2), registry row 6). The timing was made in 2016 and the folders were
uploaded again in 2023 and 2025, so a file may have been re-encoded or trimmed since.
`pack.py drift` measures that drift for one folder. It reads no network and decodes
no audio sample: it reads the MP3 frame headers and the Layer III side information.

### Inputs

- `--timing`: the quran-align JSON of the folder (release 2016-11-24, CC BY 4.0),
  read by `quran_align.py`: a JSON array, UTF-8 without a BOM, every ayah of the
  `hafs` profile exactly once (114 surahs, 6,236 ayat, each surah's ayat from 1 with
  no gap), the four fields and nothing else, integers only (a fraction, `NaN`, a
  boolean or a repeated field name is refused), `stats` with its three fields, and
  segments `[word_start, word_end, start_ms, end_ms]` with `word_end` above
  `word_start` (exclusive), each segment starting at or after the previous one's
  end word. A `segments` value that is not a list, a segment that is not four
  integers, and word indices out of order are refused.
- Defective segments and ayat without timing (D-179). The real files of release
  2016-11-24 hold a few segments whose times cannot be right (in the four files of
  D-167, from 3 to 26 by kind per file of about 76,000 segments, and one entry with
  no `segments` field), so they are kept, not refused. A segment is defective, with
  every kind that applies, when it ends before it starts (`end_before_start`), ends
  where it starts (`zero_length`), or starts before the end of the segment just
  before it, defective or not (`overlap`). An entry without the `segments` field, or
  with an empty list, is an ayah without timing. Only `segments` may be missing: the
  other three fields are still required.
- `--audio`: the folder of `SSSAAA.mp3` files, which must be named as `--edition`
  (D-167 (2): a timing file goes with its exact folder). Other files are ignored; a
  file whose address the timing file lacks is refused. Each file goes through
  `mp3.py`; a refused file stops the run with its name and byte offset. A Xing,
  Info or VBRI info frame is not audio. Its frame count, when it has one, must
  equal the audio frames counted (`xing_count: equal`) or exceed them by one, for
  encoders that count the info frame itself (`includes_info_frame`); a count that
  differs by more is refused with the header's byte offset. On the owner's first
  run, `042020.mp3` of `Minshawy_Mujawwad_192kbps` counted 1,643 frames for 1,642
  audio frames, the second case. ID3v2's flag 0x10 means a footer only in
  ID3v2.4. The last 128 bytes are an ID3v1 tag when they begin with `TAG`, unless
  the frame walk from the start ends exactly at the end of the file, which puts
  `TAG` inside the last frame: then they are audio.
- `--edition`: the everyayah folder name (`A-Z`, `a-z`, `0-9`, `_`).
- `--text` and `--metadata` (together or not at all): the Tanzil quran-uthmani text
  and `quran-data.xml`, read by the pipeline's readers and checked against each
  other and the `hafs` profile as `build` checks them. The timing file's ayat per
  surah must then equal the metadata's.

### What is measured, per file

| Measure | How |
| --- | --- |
| Playable duration | Frames times samples per frame, less the LAME tag's encoder delay and padding when the file has one whose CRC-16 (CRC-16/ARC from the frame's first byte to the CRC field, LAME's rule) holds (`delay_known`); a granule's time is then counted from the encoder delay plus the decoder delay of 529 samples, as a gapless decoder plays it. Without a valid tag nothing is removed. A tag whose CRC fails is reported per file (`lame_tag: crc_mismatch`) and not used: ffmpeg is said to compute it over a fixed 190 bytes, which differs from LAME's rule outside MPEG 1 stereo, and that is unverified here. Either way the difference is one decoder and encoder delay, about 25 ms |
| End check | The `end_ms` of the last segment that is not defective against the duration. Timing that ends more than one frame after the audio fails the file. With no such segment the check is `not made` |
| Speech | A granule's level is the highest `global_gain` among its channels that carry main data (`part2_3_length` above 0), else 0. The loud level is the 90th percentile of the file's granule levels (nearest rank, `LOUD_PERCENTILE`); a granule is speech when its level is above 0 and above the loud level less 20 steps (`SILENCE_DROP_STEPS`, 30 dB at 1.5 dB a step). A speech run lasts at least 50 ms (`SPEECH_RUN_MS`); a shorter burst counts as silence |
| Onset | The `start_ms` of the first segment that is not defective minus the start of the first speech run |
| Pauses | Every silence of at least 120 ms (`MIN_PAUSE_MS`) between two speech runs |
| Pause samples | Each pause is matched to a segment start, where speech resumes, at most 500 ms (`MATCH_WINDOW_MS`, inclusive) from the pause's end. The candidates are the starts of the segments that are not defective, less the first of them: the ayah's start, which the onset measures (after a defective first segment, the first segment that is not defective is the one left out). The matching is one to one: every pair of a pause and a candidate within the window is taken in order of \|distance\| (ties by the earlier pause, then the lower segment number) unless its pause or its start is already taken, so no start and no pause is used twice. The offset is the segment start minus the pause end: positive when the timing is later than the audio. An unmatched pause is no sample; it is counted and listed with its end time. Segment ends are not used: quran-align's ends run into the following silence, so a boundary midpoint sits late in the pause by design (D-179) |
| Chance baseline | The same matching with every pause moved 1,000 ms later (`CHANCE_SHIFT_MS`); a pause whose moved end falls after the playable duration is dropped. It shows what a random match looks like and is not a criterion |
| Trend | The least-squares slope of the offsets against their pause end, in ms per minute, with one intercept per file, so that a constant offset that differs between files does not read as a rate |

A file whose ayah has no timing is not measured or read as MP3; it is listed with
its ayah and its SHA-256. The words of a defective segment count as not covered.

With the text, every entry's highest `word_end` is compared with the ayah's count of
U+0020-separated tokens (`tokens.token_spans`); an entry past it is a word index
problem, listed by address and marked "not a criterion; enforced where word indices
are used": the drift verdict and the exit code do not depend on it. The tokens made
only of pause marks (U+06D6 to U+06DB) are counted per code point sequence, with how
many of them a segment covers.

### Summary and verdict

Per file: its pauses, matched and unmatched, each sample (pause end, segment number
from 1, offset), each unmatched pause's end, and the chance baseline's pauses and
matches.

Per edition: files measured, files without timing, timing entries without a file,
end-check failures, end checks not made, onset median and largest |onset| (reported,
not a criterion), pauses, matched and unmatched, the match rate (matched pauses over
detected pauses, in %), the median offset, p90 and p95 (nearest rank) and largest
|offset|, the slope, the chance baseline's pauses, matches, match rate and p95
|offset|, and words no segment that is not defective covers (counted against the
Tanzil tokens with the text, else up to each entry's highest `word_end`).

The timing's defects, counted twice: over the whole timing file (every ayah of the
profile) and over the sample (the ayat whose file is in the folder, measured or
not). Each count gives the ayat, the ayat without timing (no `segments` field;
empty), the segments, the defective segments and the segments of each kind (a
segment of two kinds counts under both), the segments that are not defective but
start before an earlier one that is not defective ends, and the defective segments
per 10,000 segments. The last but one exists because an overlap is judged against
the segment just before: after a segment that ends before it starts, a later segment
can go back in time without being marked. It is counted, not excluded, so the first
real run shows whether such segments exist. Every defective segment is listed by
address, segment number (from 1), kinds, `start_ms`, `end_ms`, the end of the
segment just before it and whether it is in the sample; every ayah without timing by
address, which way it lacks timing and its file and the file's SHA-256, if any.
Times only: no word and no text. The defects do not change the verdict, and the rate
is reported, not judged.

The verdict uses the lead's thresholds (D-179), constants in `drift.py` that no
flag changes. PASS when all hold:

| Criterion | Limit |
| --- | --- |
| End-check failures | none |
| \|median offset\| | at most 100 ms (`MAX_MEDIAN_OFFSET_MS`) |
| p95 \|offset\| | at most 250 ms (`MAX_P95_OFFSET_MS`) |
| \|slope\| | at most 50 ms per minute (`MAX_SLOPE_MS_PER_MINUTE`) |
| Match rate | at least 50 % (`MIN_MATCH_RATE_PERCENT`) |

Otherwise FAIL, naming each criterion missed. A criterion that could not be measured
(no matched pause; no file with two matched pauses at distinct times; no pause
detected) is missed, never passed. The exit code follows the verdict only: 0 on
PASS, 65 on FAIL, 64 on a usage error and 70 on any other failure. Word index
problems are printed and kept in the report, and change neither.

### The report and where things stay

stdout and the report hold only the edition, file names, addresses (`hafs:S:A`),
the SHA-256 of every input (timing, text, metadata, each audio file) and numbers,
rounded to 0.1 ms; the pause-mark counts are keyed by `U+XXXX`. No Quran text is
written, and the report holds no path (stdout ends with the report's own path). The
JSON report (`holyquran-recitation-drift`, version 1) has `edition`, `inputs`,
`thresholds`, `files` (per file: its numbers, `lame_tag`, `xing_count` (`equal`,
`includes_info_frame` or `null` without a count), its count of defective segments,
`pauses`, `matched`, `unmatched`, each sample's `pause_end_ms`, `segment` and
`offset_ms`, `unmatched_pause_ends_ms`, and `chance` with its `pauses`, `matched` and
`samples`), `words` (with `word_index_problems` and its `word_index_problems_status`),
`timing` (`whole` and `sample` counts, `defective_segments`, `ayat_without_timing`)
and `summary` (with `verdict` and `missed`).

The timing files, the audio sample and the report stay on the owner's machine: none
is committed, attached or uploaded. `--report` inside a Git working tree (the path
or a parent holds `.git`, links followed), a `--report` that is a folder and one
whose folder does not exist are refused before anything is read, as `test_copy.sh`
and `review-page` refuse theirs. Summaries go elsewhere as the
verdict lines.

### The four folders of D-167

On the owner's machine, with `<timing>` the folder of the quran-align files,
`<sample>` the folder holding the four sample folders, `<tanzil>` the Tanzil files
and `<reports>` a folder outside every Git working tree:

```
python3 tools/packs/pack.py drift --timing <timing>/<quran-align file of Minshawy_Murattal_128kbps> --audio <sample>/Minshawy_Murattal_128kbps --edition Minshawy_Murattal_128kbps --text <tanzil>/quran-uthmani.xml --metadata <tanzil>/quran-data.xml --report <reports>/drift-Minshawy_Murattal_128kbps.json
python3 tools/packs/pack.py drift --timing <timing>/<quran-align file of Minshawy_Mujawwad_192kbps> --audio <sample>/Minshawy_Mujawwad_192kbps --edition Minshawy_Mujawwad_192kbps --text <tanzil>/quran-uthmani.xml --metadata <tanzil>/quran-data.xml --report <reports>/drift-Minshawy_Mujawwad_192kbps.json
python3 tools/packs/pack.py drift --timing <timing>/<quran-align file of Abdul_Basit_Murattal_64kbps> --audio <sample>/Abdul_Basit_Murattal_64kbps --edition Abdul_Basit_Murattal_64kbps --text <tanzil>/quran-uthmani.xml --metadata <tanzil>/quran-data.xml --report <reports>/drift-Abdul_Basit_Murattal_64kbps.json
python3 tools/packs/pack.py drift --timing <timing>/<quran-align file of Abdul_Basit_Mujawwad_128kbps> --audio <sample>/Abdul_Basit_Mujawwad_128kbps --edition Abdul_Basit_Mujawwad_128kbps --text <tanzil>/quran-uthmani.xml --metadata <tanzil>/quran-data.xml --report <reports>/drift-Abdul_Basit_Mujawwad_128kbps.json
```

What goes back into the repository is the verdict line, the summary numbers and the
input SHA-256 of each run, recorded with D-179.

### Tests and limits

`tests/test_mp3.py` and `tests/test_drift.py` run on synthetic bytes only:
`tests/mp3_factory.py` writes valid frame headers, side information whose
`part2_3_length` and `global_gain` draw a chosen loud and silent pattern (every
other field set, so a misread field shows), zero main data, Xing and LAME frames
with a known delay and padding, VBRI frames, a frame holding `TAG` where an ID3v1
tag would begin, ID3 and APE tags and broken files; the timing is
synthetic JSON and the text is `synthetic_source.py`'s.

The tests prove the arithmetic and the refusals, not that the speech threshold suits
these four recordings. The level proxy has not been run on real files in this
repository; the first run on the owner's machine is its check. A run that finds few
pause samples, or onsets far from zero in every file, points at the proxy before it
points at the timing. On the first real run (D-179), the mujawwad files held many
detected pauses with no segment start near their end, read as dips inside long held
notes; such pauses are counted as unmatched, and the chance baseline shows how often
a window of 500 ms matches a pause by chance.

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
