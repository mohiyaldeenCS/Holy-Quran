# P1-35 — Accessibility pass over every screen (M1.11)

Wave 5 · Agent `ui-builder` · Key 1 · Cap $35 · Base `main` · Needs: wave 4 merged.

## Why

`AX-01` «قارئ الشاشة يقرأ السورة والموضع ثم الآية ثم «الآية n». كل زر أيقونة له اسم
منطوق»; `AX-02` 48 hit areas; `AX-03` «تباين النص 4.5:1 على الأقل في السمات الأربع، و7:1 في
التباين العالي»; `AX-04` «الأحجام تتبع إعداد النظام حتى 200% دون اقتطاع»; `AX-05` «كل تمييز
لوني يصاحبه شكل أو خط أو كلمة»; `AX-06` reduce motion; `AX-09` focus ring; `NF-11`
phones and tablets in both orientations; `NF-17` WCAG 2.2 AA; `NF-18` Arabic only,
right to left, Arabic-Indic digits. Criteria: «عشر مهام أساسية تُنجَز كاملة بقارئ الشاشة على
النظامين. فحص آلي لتباين كل زوج لون في الرموز». The M0.5 review: focus semantics of a
search result's link after a resize. `docs/IMPLEMENTATION_PLAN.md`: M1.11 audits the
whole; each milestone already met the checklist.

## Plan first

Ask `identity-auditor` for a list of deviations over every screen before changing
anything; fix by priority.

## Do

1. `test/a11y/`: per screen, Flutter's guidelines (`androidTapTargetGuideline`,
   `labeledTapTargetGuideline`, `textContrastGuideline`), 200% text without overflow,
   portrait and landscape on a phone and a tablet size, reduce motion, keyboard focus
   order with a visible ring, right to left and Arabic-Indic digits.
2. Fix each failure in the screen or widget concerned, without changing the identity;
   O-12's listed exceptions stay exceptions.
3. Write the ten core screen-reader tasks as a device protocol in the report
   (TalkBack now; VoiceOver with iOS builds) — pending human checks.

## Tests

`test/a11y/` passes; earlier tests still pass.

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
- `lib/ui/` (fixes only where a test fails)
- `lib/routing/routes/`
- `test/ui/`
- `test/a11y/`
- `test/guards/allow/contrast/p1-35-*.txt`

### Do not touch
`lib/data/`, `lib/domain/`, `lib/l10n/` (a missing label is reported), `integration_test/`,
`android/`, `tools/`.

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

- `test(a11y): accessibility checks over every screen (AX-01)`
- `fix(a11y): fix the deviations the checks found (AX-04)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
