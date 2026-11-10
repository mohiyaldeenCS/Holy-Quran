# B0.7 — Zaydi-library tafsir packs (`pack.py tafsir`)

Planned on 2026-11-10 by `flutter-architect` (opus) from the real extraction on the owner's machine (counts and code
points only), with the owner's answers of the same day. Decisions D-184 to D-190. Nothing real enters the repository:
the extraction, the linker output, the honorific table and every built pack stay on the owner's machine.

## What the extraction holds (eight complete books: 165, 183, 276, 440, 471, 473, 514, 737)

- **Tags:** only `p`, `span`, `div`, `sup` and `hr`, with a closed set of about eleven style or class values. There is no
  U+FFFD or U+FEFF, and no raw `<`, `>`, tab or line break inside a paragraph.
- **Entities:** `&nbsp` (without `;`) only, and only at a paragraph's edges. A bare `&` occurs only as honorific code
  U+0026.
- **Dark-red spans** (`color: #800000`) hold one of the sixteen honorific codes, U+FDFA, U+FDFB, U+FDFD, U+00B7
  (book 737) or runs of U+002E. No letter touches a code span, and no code character occurs outside one.
- **Font:** the tafsir font (`IBMPlexSansArabic-Regular.ttf`) has every code point used except U+2063 (all books) and
  U+2009 (book 514, twice).
- **Footnotes:** a mark is `<sup style="color: #800000;">(U+2063 N)</sup>`. Its note is on the same page, after an
  empty `<hr>` paragraph, as a paragraph opening with `(N)`. Marks and notes pair one to one per page. Shipped
  passages carry marks only in 473 (101 passages) and 440 (244). Some note paragraphs carry no number: 22 in 473 and
  52 in 440, four of which open a page. A number repeats inside one passage three times.
- **`meta.json`:** title and author; the card gives الكتاب, المؤلف, الناشر, الطبعة and a page count. No book names an
  editor. Book 737 has no publisher or edition, and book 471's publisher reads «المحقق». No fetch date is recorded.
- **Linker simulation** (passages that would ship of those linked):

  | Book | Would ship | Linked |
  | --- | --- | --- |
  | 183 | 2,484 | 2,721 |
  | 514 | 5,301 | 5,488 |
  | 473 | 2,334 | 2,443 |
  | 440 | 199 | 244 |
  | 471 | 280 | 302 |
  | 276 | 113 | 123 |

  Text linked to a surah but no ayah: 2,154 passages in 473, 1,042 paragraphs in 471, and 35 surahs in 514.

## Tasks, in order

| Task | Agent | What | After |
| --- | --- | --- | --- |
| A | `content-engineer` | `ziydia_link.py compare` also writes `outcomes: {"<n>": outcome}` for every linked passage (amends D-081); its tests and README | — |
| B1 | `content-engineer` | Writing and checking the format, including the surah-level passage (D-184): `hqpack/database.py` takes `user_version`; new `tafsir_database.py`, `ayah_counts.py`, `verify_tafsir.py`; `manifest.py` `build_tafsir_manifest`; `verify.py` `pack_kind`; synthetic factory and tests | — |
| B1-app | `data-builder` | The app reads the surah-level passage (D-184): `tafsir_pack_database.dart`, `tafsir_repository.dart`, their tests, and the integrity suite; `ui-builder` shows it where the surah's tafsir begins | B1's format text |
| B1-ui | `ui-builder` + `data-builder` | Show `TafsirPosition.surahPassage` (#109) above the passage where a surah's tafsir begins; tafsir search (`TF-07`, `tafsir_search_repository.dart`) also searches surah-level passages, which `passagesOfSurah` now leaves out (review of #109). No real pack ships before this task | B1-app |
| B2 | `content-engineer` | `honorifics.py`, `tafsir_html.py` (D-185), `ziydia_inputs.py`, `tafsir_passages.py` (D-186), `tafsir_config.py`, `tafsir_build.py`, the `tafsir` command, guard test forbidding the `html` module, tests, README "Tafsir packs" | A, B1 |
| C | `content-engineer` | Footnotes appended to their passage (D-189) | B2 |

A and B1 can run as two lanes. A real pack also needs:
- D-082 decided, and the reviewer's records;
- the P5 counts file (`pack.py kfgqpc-counts`, B0.3);
- the approved honorific table (D-188);
- the book's `RIGHTS_REGISTER.md` row marked `Complete`.

## CLI

```
py -3 tools/packs/pack.py tafsir --config <tafsir.json> --honorifics <table.json> --reviews <book_N.json> \
  --ayah-counts <kfgqpc-hafs-counts.json> --font assets/fonts/IBMPlexSansArabic-Regular.ttf \
  --out <folder outside every Git tree> [--report <held.json>]
py -3 tools/packs/pack.py verify <out>/<id>/<v> --ayah-counts <counts.json>
py -3 tools/packs/pack.py sign <out>/<id>/<v> --key <key> --ayah-counts <counts.json>
```

- **The description** holds `id`, `version`, `changelog`, `riwaya`, `book`, the extraction and links folders,
  `pages_sha256`, `passages_sha256`, `source{…}` and `reviews`.
- **Exit codes:**
  - 0: built.
  - 64: usage.
  - 65: any refusal: a hash mismatch; a missing or unapproved table or review record; unknown markup or code;
    U+FFFD or U+FEFF; a code point outside the font; a range outside its surah; no passage left; an output inside a
    Git tree or an existing version; any verifier problem.
  - 70: anything else.
- **Output:** the command prints counts, hashes, paths, U+XXXX, passage numbers and site pages, never text.

## Inputs are tied by their hashes

- The description's `pages_sha256` equals the hash of `pages.jsonl` and the linker report's
  `input.pages_sha256`.
- `passages_sha256` equals the report's, `compare.json`'s and the review record's.
- The review record's `compare_sha256` equals the hash of `compare.json`.
- `state.done` is true.
- The report's profile is one of the linker's six.
- The builder reads the linker's files and does not import its code.

## Review record (per book, ASCII JSON, no text)

```
{book, passages_sha256, compare_sha256, sample:{reviewer,date,sample_sha256},
 cleared:[{n,reviewer,date}], excluded:[{n,reviewer,date}]}
```

The lead copies it from the reviewer's marks on `sample.html`, `review.html` and `compare.html`. Without a record and
its sample, the build is refused.

## Tests

All tests are synthetic. Python files are ASCII, Arabic comes from `\u` escapes, and the phrases are plainly
synthetic.

- **Conversion (D-185):**
  - every allowed tag, and every refusal;
  - an honorific code becomes its phrase, and an unknown code is named;
  - kept characters stay as they are;
  - white-space collapsing;
  - a converter changed to drop or alter one character fails both proofs.
- **Table (D-188):** each refusal.
- **Passages (D-186):**
  - each gate outcome;
  - a gapped range is held out;
  - overlapping and equal ranges merge in book order; touching ranges do not;
  - reverse book order is sorted into mushaf order;
  - numbering;
  - ranges outside their surah;
  - non-passage kinds never ship (a sentinel string is absent from the database);
  - zero passages is refused.
- **Inputs:** each hash link; `done` false; a wrong URL; an unknown or repeated card label; NULL facts.
- **Pack:**
  - manifest keys and order;
  - the header (application id, `user_version` 2, DELETE journal, STRICT, VACUUM);
  - the stored text reads back equal;
  - each verifier problem is caught;
  - exit codes;
  - output carries no Arabic.

**Pending human checks:**
- the reviewer's sample per book, and clearing the flagged links;
- approval of the honorific table with its drawn images;
- the integrity suite on each real pack (lead, on the owner's machine);
- the owner sees a book on his phone;
- printed-copy checks.

## Questions still open

- **For the religious reviewer:**
  - agreement with D-082 as gated in D-186, and with the merge rule;
  - whether each book numbers its ayat by the Kufan count (book 514's printed numbers sum to 6,236).
- **For the lead, while deriving the table:** whether the site's body font also draws `{` and `}` as ornate brackets.
