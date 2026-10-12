# P1-30 — Tafsir reader and tafsir sheet (M1.7)

Wave 3 · Agent `ui-builder` · Key 2 · Cap $30 · Base `main` · Needs: P1-12, P1-13,
P1-20.

## Why

`TF-01` «اختيار التفسير الافتراضي من قائمة تفصل المنزَّل عن المتاح»; `TF-02` «تفسير الآية في
ورقة من أدوات الآية، وفي قارئ كامل من تبويب الدراسة»; `TF-03`; `TF-04`; `TF-05` «شارة
المصدر: اسم التفسير، المؤلف، الطبعة أو المحقق، مصدر الرقمنة، الإصدار»; `TF-08` «الآيات
المقتبسة داخل متن التفسير جزء من نص مصدره، تُعرض بخط الواجهة ولا تُعامل نصًّا قرآنيًا
مرجعيًا»; `TF-10` «نسخ مقطع من التفسير ومشاركته مع نسبته». Criterion: «لكل آية ... مقطع ...
أو بيان «لا يوجد تفسير لهذه الآية في هذا الكتاب»». PRD §7.7: the tafsir reader
«`QuranText` و`tafsir`»; the source badge «اسم المصدر وإصداره تحت كل مادة غير قرآنية،
وتفتح ورقة تفاصيله» from `caption`, `info` and `Icon`. The first release's tafsirs
are the Zaydi-library books only; the general tafsirs are deferred (O-06, D-119). The
books wait for B0.6, B0.7, the reviewer's checks (D-082) and O-07: synthetic packs
only, and no screen names a book.

## Do

1. `lib/ui/core/widgets/tafsir_text.dart`: passage text in the `tafsir` style
   (a pack-text sink, entry citing D-114); nothing inside it is treated as Quran text.
2. Tafsir reader (`/study/tafsir/:address`): the ayah above (`QuranText`), the passage,
   its range when it spans ayat (the range line's wording is Appendix C), next and
   previous ayah, «لا يوجد تفسير لهذه الآية في هذا الكتاب» when none.
3. Tafsir sheet (`/sheet/tafsir/:address`) for the ayah tools.
4. Default tafsir choice: downloaded apart from available (labels Appendix B).
5. `lib/ui/core/widgets/source_badge.dart`: the caption opens the source details sheet
   (field labels Appendix B). The information icon is one of D-051's: add it only if
   `IconName` has it (P1-39).
6. Copy and share a passage with its attribution through P1-12's services (the
   composer is a pack-text sink, `lib/ui/features/tafsir/tafsir_copy_text.dart`); the
   attribution format is Appendix C and the icons are D-051's: build what exists,
   report the rest.
7. Gallery: the badge and tafsir text in `study_search_gallery.dart`.
8. `lib/routing/routes/tafsir_routes.dart`; metrics in `tafsir_metrics.dart`.

## Tests

Passages and ranges on a synthetic pack; navigation; the fixed sentence; passage bytes
unchanged; the badge opens its sheet; four themes and 200%. Golden tests.

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
- `lib/ui/features/tafsir/`
- `lib/ui/core/widgets/tafsir_text.dart`
- `lib/ui/core/widgets/source_badge.dart`
- `lib/routing/routes/tafsir_routes.dart`
- `lib/ui/core/metrics/tafsir_metrics.dart`
- `lib/ui/core/gallery/sections/study_search_gallery.dart`, `test/ui/core/gallery/study_search_gallery_test.dart`
- `test/ui/features/tafsir/`, `test/ui/core/widgets/tafsir_text_test.dart`, `test/ui/core/widgets/source_badge_test.dart`
- `test/guards/allow/pack_text/sinks/p1-30-tafsir-text.txt`, `p1-30-tafsir-copy.txt`

### Do not touch
`lib/data/`, `lib/l10n/`, other features.

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

- `feat(tafsir): tafsir reader and sheet with ranges (TF-02)`
- `feat(tafsir): source badge and default tafsir (TF-05)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
