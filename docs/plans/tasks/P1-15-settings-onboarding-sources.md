# P1-15 — Settings, first-run level choice, More hub (M1.1)

Wave 2 · Agent `ui-builder` · Key 1 · Cap $25 · Base `main` · Needs: P1-01, P1-04.

## Why

- `LV-01` «إعداد واحد بثلاثة مستويات، والافتراضي «بسيط»»; `LV-02` «تغيير المستوى فوري دون
  إعادة تشغيل، ولا يحذف بيانات»; `LV-04` «أداة من مستوى أعلى تُفتح برابط أو من نتيجة بحث
  تعمل، مع سطر يعرض إظهارها دائمًا».
- `RD-08` «السمات الأربع: ورق، ليل، سيبيا، تباين عالٍ. وخيار اتباع وضع النظام الداكن»
  (D-050, D-053). `AC-01` «كل الوظائف متاحة دون حساب عدا المزامنة»; `NF-13`.
- PRD §7.3: the level «يُسأل عنه مرة في الإعداد الأولي» (more onboarding waits for O-17).

These screens are extensions (PRD §7.6): build them from existing components and
tokens by `docs/DESIGN_SYSTEM.md`, "Building a screen the identity does not draw".

## Do

1. `lib/ui/core/app.dart`: `QuranApp` takes the theme, follow-system choice and level
   from `AppSettingsRepository` (provided) and rebuilds when they change, with no
   animation, as today.
2. Settings screen (`/more/settings`): level (`LevelSwitch`, «مستوى الواجهة»), theme
   (the four names, and «اتباع وضع النظام الداكن» with `Switch`), and the rows whose
   labels exist in the ARB. Text size, open at the last position and keep awake have
   their labels in Appendix B: add those rows only if the keys exist; otherwise leave
   them out and report.
3. First run: `startup_redirect.dart` sends a user whose level is not chosen to
   `/onboarding`, which shows the `Lockup` and `LevelSwitch`. Its prompt and continue
   button have no wording (Appendix C): build the screen and the logic, keep the
   redirect off until the keys exist, and report.
5. The More hub (`lib/ui/features/more/`): entries «العلامات والملاحظات»، «مدير
   الموارد»، «الإعدادات»، «المصادر والتراخيص» to their routes (a route not built yet
   lands on the home tab), and the debug gallery entry as today.
6. `LV-04`: a route opened by a link or a search result carries a flag that opens a
   tool above the user's level; the "always show" line has no wording: leave it out.
7. Route files `settings`, `onboarding`, `more`. The sources screen is P1-40's.

## Tests

The theme and level apply at once and survive a restart (fake repository); changing
the level touches no data; follow-system in `paper`, `sepia` and `contrast` (D-053);
no sign-in gate anywhere and no network call from these screens; the first-run redirect when
enabled. Golden tests of the settings screen in four themes.

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
- `lib/ui/core/app.dart`
- `lib/ui/features/settings/`, `lib/ui/features/onboarding/`, `lib/ui/features/more/`
- `lib/ui/core/metrics/settings_metrics.dart`, `onboarding_metrics.dart`
- `lib/routing/routes/settings_routes.dart`, `onboarding_routes.dart`, `more_routes.dart`
- `lib/routing/startup_redirect.dart`
- `test/ui/core/app_test.dart`
- `test/ui/features/settings/`, `test/ui/features/onboarding/`, `test/ui/features/more/`

### Do not touch
`lib/l10n/`, `lib/data/`, `lib/main.dart`, other features.

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

- `feat(settings): settings screen with level and theme (LV-01)`
- `feat(onboarding): first-run level choice (LV-01)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
