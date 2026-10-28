# P1-38 — Strings, second batch, from the owner's answers (Phase 1)

Wave: the first of waves 1 to 5 to start after the owner answers questions 1 and 2
of `docs/plans/PHASE1.md` §9 (never beside P1-01) · Agent `ui-builder` · Key 1 · Cap $8 · Base `main` ·
Needs: the owner's answers, pasted by the lead below the line at the end of this text.

## Why

Many Phase 1 screens leave elements out because their wording is in Appendix B
(phrases from the PRD awaiting approval) or Appendix C (no wording anywhere) of
`docs/plans/PHASE1.md` §8. No task invents Arabic wording (D-115). Once the owner has
approved B and given C, this task adds them, so the owning screens can be completed.

## Do

1. Add to `lib/l10n/app_ar.arb` exactly the wording the lead pasted below, each with a
   description naming "owner, <date>" or the PRD passage. Copy the characters; never
   retype or adjust them. Placeholders that carry numbers are `String`s.
2. Plurals the owner gave are ICU plurals with every form he wrote; a missing form is
   reported, never filled in.
3. Regenerate the localisation files and commit them.
4. List, per key, the task and screen that waits for it (from §8 and the reports).

## Tests

`test/l10n/phase1_strings_second_batch_test.dart`: every pasted key exists with its
description; no Western digit, exclamation mark or emoji.

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
- `lib/l10n/app_ar.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_ar.dart`
- `test/l10n/phase1_strings_second_batch_test.dart`

### Do not touch
Everything else.

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

`feat(l10n): add the owner-approved Phase 1 strings (Phase 1)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.

---

Owner-approved wording (pasted by the lead when starting the run):

Pasted by the lead on 2026-10-28.

**Appendix B, approved by the owner as worded (D-128 (4)).** Copy every phrase from
`docs/plans/PHASE1.md` §8, Appendix B, character for character (never retype); the
ornate brackets of the two copy forms are copied from `copyFormatFull`. Skip a phrase
that already has a key (`rangeSelectorTitle`, `playerSilenceBetweenAyat`). Proposed
keys, in Appendix B's order: `openAtLastPosition`, `keepScreenAwake`, `textSizeLabel`,
`distractionFreeMode`, `playerSpeed`, `playerEndOfAyah`, `playerEndOfSurah`,
`stopAfterAyah`, `stopAfterPage`, `stopAfterSurah`, `playerStop`, `nextSurah`,
`previousSurah`, `qualityLabel`, `wifiOnly`, `sortNewest`, `noteLabel`, `tagsLabel`,
`searchHistoryTitle`, `resourceUpdate`, `resourceInProgress` («جارٍ · {percent}»),
`repeatUnlimited`, `tafsirReaderTitle`, `recitationPickerTitle`, `defaultTafsirLabel`,
`resourcesDownloaded`, `resourcesAvailable`, `sourceAuthor`, `sourceEditionOrEditor`,
`sourceDigitisation`, `versionLabel`, `copyFormatAyahOnly`, `copyFormatWithSurah`,
`reportError`, `setupStepDisplayMode`, `setupStepLevel`, `setupStepRecitation`. Add
`copyReferenceSurah` = « [{surah}]» (leading space, as `copyReferenceFull`), the
reference part of `copyFormatWithSurah` for the copy preview (D-130).

**Appendix C, worded by the lead on the owner's delegation (D-128 (5)).** Description
of each: "Lead, 2026-10-28, D-128 (5)". Exactly these characters:

| Key | Wording |
| --- | --- |
| `setupDisplayModePrompt` | اختر طريقة عرض المصحف |
| `setupLevelPrompt` | اختر مستوى الواجهة، ويمكنك تغييره متى شئت من الإعدادات |
| `setupRecitationPrompt` | اختر التلاوة التي تستمع إليها |
| `setupContinue` | متابعة |
| `setupFinish` | ابدأ القراءة |
| `reportSend` | أرسل البلاغ |
| `reportNote` | يفتح البلاغ تطبيق البريد برسالة فيها الموضع والمصدر وإصداره، وتراها قبل أن ترسلها. |
| `integrityBaseTitle` | نص المصحف لم يجتز التحقق |
| `integrityBaseBody` | لن يُعرض نص لم يجتز التحقق. حدّث التطبيق أو أعد تثبيته. |
| `integrityPackTitle` | هذه الحزمة لم تجتز التحقق |
| `integrityPackBody` | لن يُعرض محتواها حتى تُنزَّل من جديد. |
| `integrityIconLabel` | تنبيه |
| `pageNotFound` | لا توجد صفحة {page} |
| `juzNotFound` | لا يوجد جزء {juz} |
| `hizbNotFound` | لا يوجد حزب {hizb} |
| `rubNotFound` | لا يوجد ربع {rub} |
| `surahNotFound` | لا توجد سورة بهذا الاسم |
| `addressUnreadable` | لم نتعرّف على الموضع المكتوب |
| `levelAlwaysShow` | أظهر هذه الأداة دائمًا |
| `lowSpace` | المساحة المتاحة في الجهاز لا تكفي |
| `storageSummary` | المستخدم {used} · المتاح {free} |
| `downloadSize` | الحجم {size} |
| `waitingForWifi` | بانتظار شبكة Wi-Fi |
| `updateAvailable` | يتوفر إصدار جديد |
| `deletePackTitle` | حذف الحزمة |
| `deletePackBody` | يمكنك تنزيلها من جديد متى شئت. |
| `downloadNotSaved` | تعذّر حفظ الملف |
| `noNotesYet` | لا توجد ملاحظات بعد |
| `noSearchResults` | لم نجد نتائج |
| `noTafsirsYet` | لا توجد تفاسير منزَّلة بعد |
| `noRecitationsYet` | لا توجد تلاوات منزَّلة بعد |
| `queueEmpty` | قائمة التشغيل فارغة |
| `noteHint` | اكتب ملاحظتك |
| `noteSave` | احفظ |
| `noteDelete` | احذف الملاحظة |
| `shareSheetTitle` | مشاركة الآية |
| `addToQueue` | أضف إلى قائمة التشغيل |
| `repeatCounter` | التكرار {current} من {total} |
| `rangeFrom` | من |
| `rangeTo` | إلى |
| `repeatUnitAyah` | الآية |
| `repeatUnitRange` | النطاق |
| `userDataNotSaved` | تعذّر فتح بيانات التطبيق، فلن تُحفظ تغييراتك في هذه الجلسة. |

Plurals, ICU, following the existing plural keys' style (e.g. the ayah and times
counts): `searchPlaces` — zero «لا مواضع», one «موضع واحد», two «موضعان», few «{count}
مواضع», many «{count} موضعًا», other «{count} موضع»; `minutesCount` — one «دقيقة
واحدة», two «دقيقتان», few «{count} دقائق», many «{count} دقيقة», other «{count} دقيقة».

Not given here, left to their tasks: source credits (D-128 (6): as each source
publishes them), copying several ayat, gallery titles, the sources screen's headings.
