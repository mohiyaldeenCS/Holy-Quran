# P1-25 — Resource manager: tafsir and page packs, updates, storage (M1.4, M1.7)

Wave 3 · Agent `ui-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-13, P1-20.

## Why

- `OF-01` «مدير موارد واحد بفئات: التلاوات، التفاسير، مصحف الصفحات، الروايات، التجويد،
  الموارد اللغوية»; `OF-02` «لكل مورد: الاسم، الحجم، الحالة (متاح، جارٍ مع النسبة، تم
  التنزيل)، المصدر والإصدار، وإجراء التنزيل أو الإيقاف أو الحذف أو إعادة التنزيل»;
  `OF-03` «ملخص المساحة المستخدمة لكل فئة والمتاحة في الجهاز»; `OF-06` «إشعار بوصف
  التغيير»; `TF-06` «تنزيل التفاسير وحذفها من مدير الموارد. تفسير مختصر واحد يُنزَّل عند
  أول استخدام».
- PRD §9.5: a downloaded pack that fails its check shows the integrity alert (PRD
  §7.7: «حزمة فشل التحقق منها | `error` مع أيقونة وكلمة»).

The resource manager is described, not drawn (`docs/DESIGN_SYSTEM.md`, "Screens"):
build it from `ResourceRow`, `ProgressBar` (the storage bar of §7.7) and tokens.

## Do

1. Resources screen (`/more/resources`) with a section per category that holds
   packs; recitations are added by P1-33 as their own section file, so keep sections
   in separate files under `views/sections/`.
2. Rows from the catalogue joined with installs (P1-13): name, size, state with
   percent, source and version, actions (download, stop, delete, download again),
   update with the manifest's change summary. Labels missing from the ARB (Appendix
   B and C: update, percent, Wi-Fi only, notices) are left out and reported.
3. The storage bar per category and the free space (`lib/ui/core/widgets/storage_bar.dart`).
4. The integrity alert (`lib/ui/core/widgets/integrity_alert.dart`) with `alert`,
   the error colour and a word, shown on a downloaded pack that failed its run-time
   check (P1-13, P1-20) with the download-again action; its wording is Appendix C, so
   wire the state, show the component in the gallery with sample strings, and report.
5. First use of tafsir: the route `/sheet/first-use-tafsir` offers the catalogue's
   `first-use-tafsir` pack; the tafsir feature pushes it when no tafsir is installed.
6. Gallery: a new section `resources_gallery.dart`, registered in `gallery_screen.dart`;
   new colour pairs as entries under `test/guards/allow/contrast/`.
7. `lib/routing/routes/resources_routes.dart`; metrics in `resources_metrics.dart`.

## Tests

Rows for each state; actions call the installer; an update shows its summary; the
storage bar adds up; a failed pack shows the alert; first-use download requested
once. Golden tests of the screen, storage bar and alert.

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
- `lib/ui/features/resources/`
- `lib/ui/core/widgets/storage_bar.dart`
- `lib/ui/core/widgets/integrity_alert.dart`
- `lib/routing/routes/resources_routes.dart`
- `lib/ui/core/metrics/resources_metrics.dart`
- `lib/ui/core/gallery/gallery_screen.dart`
- `lib/ui/core/gallery/sections/resources_gallery.dart`
- `test/guards/allow/contrast/p1-25-*.txt`
- `test/ui/core/gallery/gallery_screen_test.dart`, `test/ui/core/gallery/resources_gallery_test.dart`
- `test/ui/features/resources/`, `test/ui/core/widgets/storage_bar_test.dart`, `test/ui/core/widgets/integrity_alert_test.dart`

### Do not touch
`lib/data/`, `lib/l10n/`, the other gallery sections.

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

- `feat(resources): resource manager with storage per category (OF-03)`
- `feat(resources): pack updates and the integrity alert (OF-06)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
