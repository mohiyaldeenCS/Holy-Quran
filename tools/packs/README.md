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

## Running

To be completed with the code.
