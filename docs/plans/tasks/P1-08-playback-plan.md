# P1-08 — Playback plan and its rules, in pure Dart (M1.9)

Wave 1 · Agent `audio-builder` · Key 2 · Cap $20 · Base `main` · Needs: the lead's
step 0 merged.

## Why

PRD §8.3: «كل طلب تشغيل يتحول إلى «خطة تشغيل»: قائمة مرتبة من مقاطع موقّتة مع تكرارها
وصمتها». Requirements: `AU-02` (ranges: ayah, ayah range, current page, several pages,
surah, juz, hizb, a set of surahs, from here to the end of the mushaf), `AU-03` (from
the ayah tools: the ayah only, to the end of the page, of the surah, of the juz, until
stopped), `AU-04` (continue into the next surah), `AU-07` (sleep timer 5–120 minutes
or end of ayah or surah, with a fade), `AU-08` (stop after ayah, page or surah),
`AU-09` (repeat ayah, range, page, surah, 1–99 or unlimited), `AU-11` (silence 0–30 s),
`AU-23` «أولوية القواعد: مؤقت النوم، ثم التوقف بعد، ثم التكرار، ثم الاستمرار», `AU-24`
«البسملة والاستعاذة تُسمعان كما في تسجيل القارئ، ولا تُركَّبان من تسجيل قارئ آخر».
Criteria: «كل نطاق في AU-02 يبدأ وينتهي عند حدود الآيات الصحيحة»; «التكرار بعدد n يُسمِع
n مرات بالضبط». `NF-20` names the playback plan a critical path. Read D-111 and D-112
in `docs/plans/PHASE1.md` §6.

## Do

All in `lib/domain`, no Flutter import.

1. `Recitation` (id, reciter and riwaya and style as given by the catalogue, unit
   `ayah` or `surah`, word timing available, rights complete).
2. Plans read the edition through P1-02's `QuranStructure` (implemented by P1-05's
   index repository).
3. `PlaybackRange` and the ayah-tool options, resolved to ordered ayah addresses.
4. `PlaybackPlan` of `PlaybackSegment`s: address, source (a whole file, or a clip of a
   surah file with start and end), repeat index and silence after. Unlimited repeat
   and continuation are generated lazily. Basmala and isti'adha segments come only
   from the same recitation's own files, when it has them; none for surah 9; in surah
   1 the basmala is ayah 1.
5. A recitation served by surah files has no ayah boundaries until timing data
   (registry row 6) is available: for it, only whole-surah ranges can be planned, and
   the plan says so instead of guessing (D-112).
6. `PlaybackRules`: a pure state machine over plan events (segment ended, timer
   fired, user stop) applying sleep timer, stop-after, repeat and continue in the
   order of `AU-23`; it emits `ayahStarted(address)` for the reader to follow later.
   Time comes from an injected clock.

## Tests

Every range kind on a synthetic structure, boundaries exact; repeat n plays exactly n
times for every n in 1–99 and stays lazy when unlimited; silence placement; each pair
of rules in conflict resolved in the `AU-23` order; basmala rules for surahs 1, 9 and
another; surah-file recitations refuse ayah ranges; continue across the last surah
stops.

## Acceptance

- `dart format .` changes nothing, `flutter analyze` reports no issues, and
  `flutter test --exclude-tags golden test tools/gen/test` passes (add `spike` if that
  folder exists). Run all three before the last commit, fix what fails, and run them
  again. Never weaken, skip or delete a test to make it pass.
- Golden images are made only by the CI `goldens` task (D-056). Write new golden tests
  tagged `golden`; never create or commit a `.png` file. A new golden test without its
  image is expected.
- Each acceptance criterion quoted above is reported as met (with its test), partial
  (with the reason) or a pending human check (device, reviewer or owner).

## Self-review

Through the Task tool, run `code-reviewer` on your whole diff. Fix every blocking
and should-fix finding, re-run the checks, and ask again until none remains. Say in
the report which nits you left and why.

## Files

### You own
- `lib/domain/models/recitation.dart`
- `lib/domain/models/playback_range.dart`
- `lib/domain/models/playback_segment.dart`
- `lib/domain/models/playback_plan.dart`
- `lib/domain/models/sleep_timer.dart`
- `lib/domain/models/stop_after.dart`
- `lib/domain/models/repeat_mode.dart`
- `lib/domain/models/playback_plan_builder.dart`
- `lib/domain/models/playback_rules.dart`
- The tests that mirror these files (same path under test/, ending in _test.dart)

### Do not touch
`lib/data/`, `lib/ui/`, `android/`, `pubspec.*`.

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

- `feat(audio): add the playback plan and ranges (AU-02)`
- `feat(audio): apply sleep timer, stop-after, repeat and continue in order (AU-23)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
