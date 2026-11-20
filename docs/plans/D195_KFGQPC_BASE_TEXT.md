# Plan: the KFGQPC text as the base text (D-195, D-198)

The owner made the KFGQPC Hafs text (version 2.0, update 13.0) the base text on
2026-11-20 (D-195). D-198 settles what that changes, except Q3 (the permission's
terms, the owner's papers) and Q1's deferral of RD-19 (scope, the owner's). This
plan was written by `flutter-architect` (read only) and is kept here so the task
numbers that the status file cites are defined. No pack is built until the rights
row of KFGQPC is complete.

## What changes

- **Font.** The text pairs with KFGQPC's own `uthmanic_hafs_v20.ttf` (unmodified:
  its EULA forbids changes), replacing Amiri Quran for Quran text (D-198 Q2). It
  touches the font assets, `pubspec.yaml`, the token generator, `reader_style.dart`
  (Amiri's x-height), `quran_text.dart`, the font guards, the integrity suite, the
  synthetic pack and every golden image that shows `QuranText`. Line heights were
  tuned for Amiri and are re-measured on the phone.
- **Pipeline.** The ayah is stored as published; the ayah-end U+00A0 with the
  KFGQPC number glyph (U+FC00+n−1) and the U+06DE + U+00A0 quarter openings become
  stored presentation spans, never shown or copied (D-198 Q4). KFGQPC joins pause
  marks to letters inside one token (4,272 tokens, #122), so word and mark spans are
  cut inside a token at the mark. Tanzil stays the comparison witness and the source
  of surah facts and sajdas (the 15 U+06E9 ayat match Tanzil's sajdas). The 9.4
  comparison still stops the build (D-198 Q6).
- **Search forms (SR-03).** From KFGQPC's own `aya_text_emlaey`; 61 ayat have one
  more emlaey token than Uthmani tokens, so a recorded word-for-word rule is needed.
- **Recitation timing.** quran-align counts Tanzil tokens; Tanzil has more tokens
  than KFGQPC in 2,655 ayat. A map from Tanzil tokens to KFGQPC words, with no
  word left unmapped (PRD §10.4). The drift verdicts (D-179, D-182) stand.
- **Basmala.** KFGQPC has none for surahs 2–114 (D-198 Q5).
- **Proofreading (O-16).** Still required (D-198 Q7).

## Tasks, in order

| Task | Owner | What | State (2026-11-20) |
| --- | --- | --- | --- |
| T0 | lead | Records: DECISIONS, SOURCES, rights register, CONTENT_PACKS, ARCHITECTURE, IMPLEMENTATION_PLAN, DESIGN_SYSTEM, the quran-text-integrity skill | D-195, D-198, SOURCES rows 1–2 done; the rest follows each task |
| T1 | content-engineer | `pack.py kfgqpc-measure`, counts only | #122 |
| T2 | content-engineer | KFGQPC text path and presentation spans in `kfgqpc.py`, `build.py`, `tokens.py`, `verify_spans.py`, `database.py`, `verify_database.py`, `synthetic_source.py` | draft #126 |
| T3 | content-engineer | Divisions, sajdas and facts; manifest roles and witness; the comparison as the witness gate; Tanzil counts; the README (after T2) | not started |
| T4 | content-engineer | Search forms from `aya_text_emlaey` | not started |
| T5 | content-engineer | The Tanzil-to-KFGQPC timing map | draft #127 |
| T6 | content-engineer | The test-copy files for a KFGQPC copy | not started |
| T7 | lead | The font, unmodified, in `assets/fonts/` and `pubspec.yaml` | waits for Q3 |
| T8 | content-engineer | `tools/gen` per Q2, then `tokens.g.dart` | waits for Q3 |
| T9 | data-builder | Domain models, manifest JSON, repositories serving the ayah's own span | after T2 |
| T10 | test-engineer | Font guards, integrity suite, synthetic pack, perf launch | after T2 |
| T11 | ui-builder | `reader_style.dart`, `quran_text.dart`, the basmala line, credits, strings | after Q2/Q3 |
| T12 | lead | CI goldens with every image reviewed, reviews, identity audit, a device check | last |
