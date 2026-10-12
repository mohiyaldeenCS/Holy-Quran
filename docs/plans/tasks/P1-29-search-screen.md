# P1-29 — Search screen and history (M1.8)

Wave 3 · Agent `ui-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-18, P1-21.

## Why

`SR-01` «حقل واحد وحبّات لنوع البحث. تظهر الحبّة حين تتوفر بياناتها»; `SR-04` «سطر يذكر ما
بُحث عنه وعدد المواضع والآيات، ثم بطاقات تعرض الآية كاملة مع إبراز المطابق بخلفية وخط
سفلي. الآية الطويلة تُقطع عند ثلاثة أسطر مع «اعرضها كاملة»»; `SR-05` order; `SR-06` scope;
`SR-07` direct jump; `SR-10` «سجل بحث محلي يمكن مسحه»; `TF-07` in the interface.
Criteria: «النتائج تظهر خلال 300 مللي ثانية دون اتصال»; «نص الآية في النتيجة مطابق لنص
الحزمة، والإبراز لا يغيّر حرفًا». P1-17 made `SearchResult`'s expanded state the caller's (M0.5 review); a
focus-semantics point from that review is checked with TalkBack later.

Drawn: the Search board.

## Do

1. Study hub (`/study`): entries to search and to the tafsir reader (`/study/tafsir/…`;
   its label is Appendix B: if absent, report).
2. Search screen (`/study/search`): `SearchField`; `ModeChips` with only the chips
   that have data in Phase 1 (word, without diacritics, in tafsirs when a tafsir is
   installed); `SearchSummary`; `SearchResult` cards with highlights from P1-21's
   offsets; order (mushaf, nearest, most frequent) and scope (whole, surah, juz).
   The summary's plural of «موضع» is Appendix C: show what the ARB allows and report.
3. Direct jump through P1-10 opens the reader.
4. History (P1-18): recent queries and clearing (label Appendix B).
5. Hold each card's expanded state in the view model.
6. Route files `search`, `study`; metrics in `search_metrics.dart`.

## Tests

Chips by data; results equal pack bytes with highlights by offsets; long ayah clamps
and expands, and stays expanded after scrolling away and back; order and scope;
direct jump; history clear. Golden tests of the search screen.

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
- `lib/ui/features/search/`
- `lib/ui/features/study/`
- `lib/routing/routes/search_routes.dart`, `study_routes.dart`
- `lib/ui/core/metrics/search_metrics.dart`
- `test/ui/features/search/`, `test/ui/features/study/`

### Do not touch
`lib/data/`, `lib/l10n/`, the gallery sections (P1-30 owns `study_search_gallery.dart`
in this wave).

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

- `feat(search): search screen with modes, order and scope (SR-04)`
- `feat(search): direct jump and history (SR-10)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
