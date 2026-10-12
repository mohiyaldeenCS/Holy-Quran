# P1-22 — Reader targets, tap resolver and highlights, from spike S7 (M1.2, M1.6)

Wave 2 · Agent `ui-builder` · Key 2 · Cap $25 · Base `main` · Needs: P1-09; D-097
(the tap rule chosen by S7's usability test) recorded in `docs/DECISIONS.md`.

## Why

PRD §7.4 maps every tap in the reader to a target (marker, ayah, waqf mark, word,
margin, pinch). `AX-02` «كل هدف لمس 48 على الأقل، ولو كان المرئي أصغر» (S7 measured 74%
of words and every mark under 48 px wide at 1.0x). Highlights — selected ayah, recited
ayah and word, search match (`Match`, D-088) — are painted from text geometry and
never change the text (`docs/ARCHITECTURE.md`, "Rendering the Quran"; the Mushaf
board, «التمييز داخل النص»). Read `docs/spikes/S7-gestures.md`, D-095, D-097, D-113.

## Do

1. Port from the commit the S7 page cites (`spike/s7/`): `GestureTarget` (word, waqf
   mark, marker, margin), `TargetGeometry` over P1-09's laid-out lines and boxes, and
   `resolveTap` with the one rule D-097 records (no rule options).
2. Hit zones of at least 48 px for markers and marks; overlaps resolved by the rule.
3. One gesture layer per block for taps and long presses; one pinch handler per
   reader that steps through P1-09's ladder and keeps the focal ayah in place.
4. Highlight painters from the identity's tokens: selected ayah (`selection`,
   `selection-line`), recited ayah (background and filled marker), spoken word
   (background and underline), search match (`search-match` and underline). Each has
   a shape or line as well as colour (`AX-05`).
5. Gallery: the highlight states in `lib/ui/core/gallery/sections/mushaf_gallery.dart`.

## Tests

On synthetic packs with marks: every word, mark and marker centre resolves to itself;
taps 6, 12 and 18 px off resolve as D-097's measurements say; marks at a line start
still resolve; zones are 48 px; painters leave the text spans untouched (bytes
compared); pinch steps. Golden tests of the highlight states.

## Acceptance

- `dart format .` changes nothing, `flutter analyze` reports no issues, and
  `flutter test --exclude-tags golden test tools/gen/test` passes (add `spike` if that
  folder exists). Run all three before the last commit, fix what fails, and run them
  again. Never weaken, skip or delete a test to make it pass.
- Golden images are made only by the CI `goldens` task (D-056). Write new golden tests
  tagged `golden`; never create or commit a `.png` file. A new golden test without its
  image is expected.
- The acceptance checklist of `docs/DESIGN_SYSTEM.md` holds for every widget and
  screen you touched: four themes, right to left, 200% text, 48 hit areas, labels,
  focus ring, reduce motion, Arabic-Indic digits, strings from the ARB file.
- Each acceptance criterion quoted above is reported as met (with its test), partial
  (with the reason) or a pending human check (device, reviewer or owner).

## Self-review

Through the Task tool, run `code-reviewer` on your whole diff and `identity-auditor` on every UI change. Fix every blocking
and should-fix finding, re-run the checks, and ask again until none remains. Say in
the report which nits you left and why.

## Files

### You own
- `lib/ui/core/reader/` (P1-09 merged): add new files only and keep P1-09's public
  API unchanged, because P1-14 builds on it in this wave
- `lib/ui/core/gallery/sections/mushaf_gallery.dart`, `test/ui/core/gallery/mushaf_gallery_test.dart`
- `test/ui/core/reader/`

### Do not touch
`lib/ui/features/`, `lib/ui/core/widgets/`, `lib/l10n/`.

## Rules

- `CLAUDE.md` and `docs/WORKFLOW.md` apply in full. Quran text comes only from packs,
  by address, through `QuranText`, `SurahName` or a sink listed under
  `test/guards/allow/`; it is never typed, pasted, trimmed, normalised or split by the
  app. Tests use the synthetic packs of `testing/packs/` and obviously synthetic text.
- No generated content. The identity is closed. No Arabic wording of your own: use
  only keys in `lib/l10n/app_ar.arb`; if one you need is missing, leave that element
  out and list it in the report.
- Edit only the files under "You own"; every file listed there is handed over to you
  for this task, whatever your agent file says. If another file must change, stop that
  part and report it. A gallery title or sample label reuses an existing key. Never edit `docs/PROJECT_STATUS.md`, `docs/DECISIONS.md`, `.github/`, or
  `pubspec.*`.
- Few comments, saying why; small files; no dead code or speculative options; no
  literal colours, font names or inline design numbers in feature code.
- Never print, write or commit secrets or environment variables; do not run `env`,
  `printenv` or `set`.
- Commit on the current branch only. Do not push, open pull requests, change remotes or
  call the GitHub API.

## Commits

- `feat(reader): targets and tap resolution in surah mode (AX-02)`
- `feat(reader): selection, recitation and search highlights (M1.2)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
