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
| `tanzil_metadata.py` | Tanzil's `quran-data.xml`: `suras`, `juzs`, `hizbs` (of `quarter`), `manzils`, `rukus`, `pages`, `sajdas`, and exactly one comment outside the root | `read_tanzil_metadata(data) -> TanzilMetadata(suras: [MetaSura], juzs, quarters, manzils, rukus, pages: [Point], sajdas: [MetaSajda], notice)`; `MetaSura(index, ayas, start, name: SourceValue, tname, ename, type, order, rukus)`; `Point(index, sura, aya)`; `MetaSajda(index, sura, aya, type)` |
| `tokens.py` | D-083: tokens are the maximal runs between U+0020; a token holding a code point of general category L is a word, any other a mark; UTF-16 offsets; refuses a separator of category Z other than U+0020 and a mark code point outside the mark table | `utf16_length(s)`, `spans(text, mark_code_points, where) -> Spans(words: [(start, end)], marks: [(after_word, start, end)])` |
| `mark_table.py` | The mark table of code points (B0.4 delivers the real one): `{"code_points": ["U+06D6", ...]}`, sorted, unique, none a letter or a separator | `read_mark_table(data) -> frozenset[int]` |
| `font.py` | The font file: SHA-256, family (name ID 16, else 1), version (`Version d.ddd` of name ID 5) and the code points of its `cmap` (formats 4 and 12) | `read_font(data) -> FontInfo(family, version, sha256, code_points)` |
| `options.py` | `sources[].options` from the download URL (every query parameter but `agree`, D-077), and the checks the options imply: `rub`, `sajdah`, `marks` set to `false` mean none of their code points occurs, `true` that at least one does | `options_from_url(url)`, `option_problems(options, texts)` |
| `digest.py` | The surah digest of `docs/CONTENT_PACKS.md` and file hashes | `surah_digest(fields: [(number, bytes)])`, `sha256_file(path)` |
| `database.py` | `text.sqlite` with the exact DDL, `encoding`, `application_id`, `user_version`, `STRICT`, `journal_mode = DELETE`, ending with `VACUUM`; read-back of every stored text as bytes | `require_sqlite()`, `write_text_database(path, surahs, divisions, sajdas)`, `read_stored_texts(path)` |
| `manifest.py` | The manifest's fields in the format's order, and its bytes (UTF-8, no BOM, two-space indent, final line break) | `build_manifest(...) -> dict`, `encode_manifest(dict) -> bytes` |
| `config.py` | The build description: pack identity, both sources' registry fields, expected source SHA-256, the mark table, reviews. Strict JSON | `read_build_config(path) -> BuildConfig` |
| `profiles.py` | What a riwaya must hold: surah and ayah totals, division counts, which surahs have no basmala, whether the KFGQPC comparison is required | `PROFILES`, `profile_for(riwaya, pack_id)` |
| `build.py` | The pipeline: hash and read the sources, run every build check, write into a temporary directory, read back, write the manifest, run the verifier, then move into `<out>/<id>/<version>/` | `build_pack(config_path, font_path, out_root) -> BuildResult` |
| `verify.py` | An independent verifier of a pack directory, sharing no code with the writer beyond `errors.py`: everything the app and its integrity suite check, recomputed from the stored bytes | `verify_pack(directory, mark_code_points=None, font=None) -> Report(problems, counts, signed)` |
| `signing.py` | The signing seam (D-080, O-03): `Signer` with `sign(data) -> 64 bytes`; `OpenSslEd25519Signer(key_path)` runs `openssl pkeyutl -sign -rawin`; `sign_pack` writes `manifest.json.sig` for a pack that verifies; `verify_signature` checks it with a public key | `sign_pack(directory, signer)`, `verify_signature(directory, public_key_path)` |
| `cli.py` | `build`, `verify`, `sign`, `verify-signature`; prints counts, hashes, paths and `U+XXXX` only | `main(argv) -> exit code` |

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
python3 tools/packs/pack.py verify <out>/<id>/<version> [--font <ttf>] [--mark-table <marks.json>]
python3 tools/packs/pack.py sign <out>/<id>/<version> --key <ed25519 private key> [--font <ttf>] [--mark-table <marks.json>] [--openssl openssl]
python3 tools/packs/pack.py verify-signature <out>/<id>/<version> --public-key <ed25519 public key> [--openssl openssl]
```

| Command | Does |
| --- | --- |
| `build` | Reads the build description, runs every build check below, and writes `<out>/<id>/<version>/` with `manifest.json` and `text.sqlite`, unsigned. An existing version directory is refused: a released pack is never rebuilt in place |
| `verify` | Runs the independent verifier on a pack directory; with `--font` and `--mark-table` it also checks the font pair and every mark |
| `sign` | Verifies the pack, then writes `manifest.json.sig` with OpenSSL (D-080). Refuses a pack that already has one |
| `verify-signature` | Checks `manifest.json.sig` against a public key |

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
| `sources.text`, `sources.edition_map` | Each: `file` (relative path), `file_sha256` (the SHA-256 the file must have), `registry_row`, `name`, `publisher`, `url`, `version`, `fetched_on`, `trust_grade`, and `licence` with `text`, `permission_ref` and `allows_export`. There is no `notice`: it is taken verbatim from the comment of the source file. `options` come from the query of `url` (every parameter but `agree`), `null` when there is none |
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
| Tanzil compared with KFGQPC character by character under a table of known differences | **Not built** (B0.2, with B0.3's KFGQPC file and B0.4's table). `build.py` therefore refuses every `hafs` build with a message saying so. The synthetic profile does not need it |
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
| Words and marks (D-078, D-083): only U+0020 separates; a token with a letter (category L) is a word, any other a mark; UTF-16 offsets; `after_word` | `tokens.py`; the verifier recomputes every span and compares row by row |
| P3: a letterless token outside the mark table stops the build | `tokens.spans` with `mark_table.py` |
| P2: juz, quarters and pages from the metadata; a hizb is every fourth quarter by position | `source_checks.divisions`; refuses a quarter count that is not a multiple of 4. Comparing the pages with the KFGQPC file is the step not built yet (see above) |
| P4: basmala from the separate field; none for surahs 1 and 9, present elsewhere | `tanzil_text.py` (only on ayah 1); `source_checks.check_structure` with the profile's `without_basmala` |
| P6: revelation place through a fixed table, others refused; order from the metadata | `source_checks.revelation`: `Meccan` to `makki`, `Medinan` to `madani`; the orders must be 1 to n, each once |
| D-077: `options` from the source | `options.options_from_url` |
| D-079: no U+06DE; pause marks and sajda signs present when the options say so | `options.option_problems` (`rub`, `sajdah`, `marks`); `source_checks.check_sajda_signs`: with sajda signs, the ayat holding U+06E9 are exactly the metadata's sajdas |
| Notice kept verbatim | The single comment of each file goes into `licence.notice`; the text's notice must name `Version <version>` of the description |
| A code point the font lacks stops the build | `source_checks.check_font_coverage` over every ayah and basmala; the font must be Amiri Quran (PRD §9.1, text and font are one pair) |
| `id` and `version` equal the directory names; strict manifest | Verifier, mirroring `lib/data/models/pack_manifest_json.dart` |
| A failed build leaves nothing | Built in `<out>/.build-*`, moved into place only after the verifier passes; removed on any failure |

What the verifier adds to the app's checks: it refuses any file in the pack
directory besides `manifest.json`, `text.sqlite` and `manifest.json.sig`; a
signature that is not 64 bytes; views, triggers and indexes other than automatic
ones; and, with `--font`, code points the font lacks.

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
pack already signed; `pack.py sign` verifies the pack first.

O-03 still decides: who holds the private key and on which machine signing runs
(the owner's computer, a CI secret, or a hardware token); how the key is backed
up; and which public keys the app accepts, since D-080 keeps a list so a key can
be replaced. Another kind of signer, such as a hardware token, would be another
`Signer`; nothing else changes.

## Not done here

- The KFGQPC comparison of PRD §9.4 and the page-list comparison of P2 (B0.2).
  Until then, no `hafs` pack is built.
- The real mark table of code points (B0.4).
- The structure of the real `quran-data.xml` and the text file's notice are taken
  from their published form; B0.2 runs the readers on the downloaded files, and
  they stop on anything else.
