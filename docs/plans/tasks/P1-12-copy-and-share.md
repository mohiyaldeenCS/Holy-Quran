# P1-12 — Copy and share-card machinery (M1.6)

Wave 1 · Agent `ui-builder` · Key 2 · Cap $25 · Base `main` · Needs: P1-01, P1-02,
P1-03.

## Why

- `SH-01`: «النسخ بثلاث صيغ: نص الآية، الآية مع اسم السورة، الآية مع اسم السورة ورقمها.
  الصيغة: ﴿نص الآية﴾ [السورة: الرقم]».
- `SH-02`: «بطاقة مشاركة بثلاثة تصاميم (زمرد، ورق، ليل) وثلاثة مقاسات (1:1، 4:5، 9:16)،
  فيها الآية كاملة ومرجعها والشعار».
- `SH-03`: «الآية لا تُقتطع ولا تُدمج بغيرها. يصغر الخط حتى 22 ثم تنتقل البطاقة للمقاس
  الطويل. إن لم تتسع تُعرض «الآية أطول من أن تتسع في بطاقة» مع اقتراح النسخ».
- `SH-05`: «كل نص قرآني يخرج من التطبيق يُسحب من الحزمة بعنوانه، لا من عناصر الواجهة».
- Criterion: «النص المنسوخ والنص في البطاقة يطابقان نص الحزمة. اختبار آلي على الآيات
  كلها للنسخ، وعلى أقصر 50 آية وأطول 50 للبطاقة».

The Share board (`design/identity-boards/Share.dc.html`) draws the copy sheet and the
cards; `ShareCard` exists (`lib/ui/core/widgets/share_card.dart`).

## Do

1. `CopyForm` in the domain. The composer `lib/ui/core/share/ayah_copy_text.dart`
   fetches the ayah and surah name by address and builds the clipboard text from the
   ARB formats: a pack-text sink, entry citing D-114. Only the full form's format is
   given today (`copyFormatFull`); build the other two forms only if their formats
   are in the ARB (Appendix B), and report otherwise.
2. `lib/data/services/clipboard_service.dart` and `share_service.dart` (`share_plus`)
   behind interfaces; delegate them to `data-builder` through the Task tool.
3. `lib/ui/core/widgets/copy_sheet.dart`, as the Share board draws it; the share
   sheet `lib/ui/core/share/share_card_sheet.dart`: design and size choice, preview,
   share. "Save the image" has no wording (D-052, Appendix C): leave it out.
4. `share_card_fit.dart`: the largest size from the card's own down to 22 at the
   chosen ratio; if it still does not fit, the 9:16 card; if not even that, the
   too-long state with the fixed sentence and a copy action.
5. Render the chosen card to image bytes in memory and hand them to the share service.
6. `lib/routing/routes/share_routes.dart`: `/sheet/copy/:address`,
   `/sheet/share/:address`. Entry points from the ayah toolbar come later (P1-23,
   P1-31), once the copy and share icons exist.
7. Gallery: the copy sheet and the share sheet's states in
   `lib/ui/core/gallery/sections/home_share_gallery.dart`. If a new colour pair
   appears, add its entry under `test/guards/allow/contrast/`.

## Tests

The copied text equals the pack's bytes plus the format for every ayah of the
synthetic pack (and of a real pack given with `HOLYQURAN_PACK_DIR`, as the integrity
suite does); fit on the 50 shortest and 50 longest synthetic ayat; the too-long path;
golden tests of the copy sheet and the share sheet in four themes.

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
- `lib/domain/models/copy_form.dart`
- `lib/ui/core/share/`
- `lib/ui/core/widgets/copy_sheet.dart`
- `lib/data/services/clipboard_service.dart`
- `lib/data/services/share_service.dart`
- `lib/config/providers/share_providers.dart`
- `lib/routing/routes/share_routes.dart`
- `lib/ui/core/gallery/sections/home_share_gallery.dart`
- `test/ui/core/gallery/home_share_gallery_test.dart`
- `test/guards/allow/contrast/p1-12-*.txt`
- `test/ui/core/share/`, `test/ui/core/widgets/copy_sheet_test.dart`, and the tests that mirror the two services
- `test/guards/allow/pack_text/sinks/p1-12-*.txt`

### Do not touch
`lib/ui/core/widgets/share_card.dart` (report a needed change), `lib/l10n/`,
`lib/ui/features/`.

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

- `feat(share): copy an ayah from the pack in the given forms (SH-01)`
- `feat(share): fit and share ayah cards (SH-03)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
