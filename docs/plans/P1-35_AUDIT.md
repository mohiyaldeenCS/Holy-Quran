# P1-35 accessibility audit

Read-only audit of every screen, run 41877486086 (identity-auditor, sonnet), 2026-11-04, kept as it came.
The owner answered its questions 1 and 2 (D-168); the lead ruled on question 3 and proposals A to D (D-169).

# P1-35 step 1: accessibility audit, deviation report (read-only)

I changed nothing in the repository: `git status` is clean. All probe files are under `$RUNNER_TEMP/probe/` (`probe1_test.dart` to `probe9_test.dart`). I did not run `dart format`, `flutter analyze` or the full test suite, because there is no diff. I did run `test/guards/contrast_test.dart`: 355 tests passed.

**How I probed.** I pumped each screen through the existing harnesses (`pumpSearchApp`, `MushafRig`, `SheetLog`) on synthetic packs and default or empty data:
- **Layout:** four sizes (320×640 at 200% text, phone landscape 844×390, tablet portrait 768×1024, tablet landscape 1024×768), checked for overflow.
- **Guidelines:** `androidTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline`, in the paper and contrast themes.
- **Semantics:** a semantics-tree walk for tap-without-focus nodes, unnamed buttons and Latin digits.
- **Keyboard:** Tab-key traversal with a check for a `FocusRing` on each stop.
- **Motion:** reduce-motion on a pushed route.

Populated states of bookmarks, resources, the player, search results and tafsir were not re-probed. Existing per-screen tests cover them, and the gaps in those tests are listed below.

## 1. Deviations

| # | Rank | Screen | File:line | Requirement | Evidence | Fix |
|---|---|---|---|---|---|---|
| 1 | **must-fix** | Reader (surah mode) | `lib/ui/core/reader/reader_block.dart:57-95`, `reader_paragraph.dart:205-218` (`ayahSemantics`) | AX-09, NF-17 (WCAG 2.1.1 Keyboard) | In the reader probe with the real router, 10 of the nodes with a tap action had no focus action. They were the ayah texts and the «الآية n» markers. Tab alternated between two stops only: the position-bar button (180,52) and the first surah header (180,155). No ayah, marker, page mark or margin mark could be focused. Without the router there was a single stop, so keyboard users cannot select an ayah or open its tools. | Give each ayah's semantics node a focus action and Enter/Space activation that calls `onAyahActivated`. Draw the existing `FocusRing` (`focus` token) around the ayah's rectangle, and scroll it into view with `RevealOnFocus`. |
| 2 | **must-fix** | Full player | `lib/ui/core/widgets/seek_track.dart:52-85` (used in `player_panel.dart:94`) | AX-09, NF-17 (2.1.1) | The track is a bare `GestureDetector` with `excludeFromSemantics`. It has no `Focus`, no `FocusRing` and no arrow-key handling. Only `onIncrease` and `onDecrease` exist, and only for a screen reader. A keyboard user cannot seek. | Wrap it in `FocusableActionDetector` with `FocusRing`, and map Left and Right to `onSeekBy(±PlayerMetrics.seekStep)`. Keep the right-to-left direction. |
| 3 | should-fix | Every screen on tablets (NF-11) | No `maxWidth` anywhere in `lib/ui/features/**/views` or `lib/ui/core/widgets` | NF-11 | At 1024×768 the first `/more` button is 984 wide (rect 20→1004). On the index the surah name sits at x=946 and its badge at the far left. Layouts stretch edge to edge. No overflow, but no tablet layout. The identity draws phones only. | Ask the owner (question 1). Do not invent a column width. |
| 4 | should-fix | Any screen showing a pack alert | `lib/ui/core/widgets/integrity_alert.dart:29` | NF-17 (WCAG 4.1.3 Status Messages), AX-01 | `Semantics(container: true)` with no `liveRegion`. An alert that appears while the screen is open is not spoken. `PlaceRefusal`, `UndoBar`, `AyahToolbar` and `Stepper` already announce. | Add `liveRegion: true` to the container, as `PlaceRefusal` does at `place_refusal.dart:48`. |
| 5 | should-fix | Copy sheet | `lib/ui/core/share/copy_sheet_view.dart:22-28` | NF-17 (4.1.3), AX-01 | On success the sheet pops with no visible or spoken confirmation. A screen-reader user is not told the copy worked. `app_ar.arb` has no copy-confirmed key. Only `itemDeleted` «تم الحذف» exists. | Missing string, so build nothing; ask the owner (question 2). |
| 6 | should-fix | Test coverage (the P1-35 deliverable) | `test/ui/features/*` | AX-02, AX-03, AX-04, AX-09, NF-11 | No test in `test/ui/features` uses `textContrastGuideline`. No feature screen test sends Tab or checks focus order. Screens with no `androidTapTargetGuideline`, `labeledTapTargetGuideline` or 200% test: bookmarks, more, onboarding, report, search, settings (200% only), study, mushaf (guidelines), sources (guidelines). No landscape test for bookmarks, more, onboarding, report, search, settings, study, sheets. `test/a11y/` does not exist yet. | Write `test/a11y/` per screen. |
| 7 | should-fix | Test method | probe1 | AX-03 | `textContrastGuideline` gives false positives. The tab bar fails in every theme: paper 1.23 on the selected pill, contrast theme 3.89 on «الدراسة». The home greeting «السلام عليكم» fails at 1.56. The token pairs pass: `inkMuted` is E0E0E0 on 1A1A1A in contrast, and 51605D on F8F2E4 in paper, about 5.9:1. The guideline samples icon and anti-aliased pixels inside the node rectangle. `test/guards/contrast_test.dart` stays the authority. | In `test/a11y/`, use the guideline only where it is reliable. Otherwise assert the token pair (`ink`, `inkMuted` on the real surface) and cite `contrast_test.dart`. Do not add the guideline as a blanket check. |
| 8 | nit | Settings | `lib/ui/features/settings/views/settings_screen.dart` | AX-01 | The semantics dump reads «مستوى الواجهة» twice (header, then group) and «السمة» twice. This is the P1-15 pending note. | Fold the group label into the heading, or hide the second. Keep the group announced once. |
| 9 | nit | Reader | `reader_block.dart:78-94` (marker), `block_margin.dart:52-71` | AX-02 | `androidTapTargetGuideline` fails on the marker node «الآية ١»: 26×26. This is exempt by D-097 (marks inside text; WCAG 2.5.8 inline exception). The tap rule gives a 48 px zone. | Keep. In `test/a11y/`, exclude marker and mark nodes by name, citing D-097. Optionally widen the node rect to 48. |
| 10 | nit | Onboarding, home | `onboarding_screen.dart`, `home_header.dart` | AX-01 | Onboarding has no node flagged as a header, and «القرآن الكريم» is plain. Home reads «شعار القرآن الكريم» and then «القرآن الكريم». | Exclude the logo's label, or make the name a header. |
| 11 | nit | Tab bar | `lib/ui/core/widgets/tab_bar.dart:103-125` | AX-04 | Tab labels stop growing where the widest no longer fits (D-058, settled in M0.2). This is a declared exception, but AX-04 says up to 200%. | Keep as is. Mention it in the report as a declared exception. |

**Checks that found nothing wrong:**
- **Reduce motion.** The pushed route is a go_router `_CustomTransitionPageRoute` with duration 0, so `reduce=true` and `reduce=false` both complete at once. Sheets (`sheet_route.dart:31`), `Switch` (`switch.dart:58`), `RevealOnFocus` and the reader's follow-scroll honour `disableAnimations`. The queue reorder relies on the framework's 5% motion, noted at `queue_sheet.dart:36`. I could not check it on a device.
- **No clipping at 200%.** The only `maxLines` and ellipsis uses are the tab labels, the badge numbers and the note card (`note_editor.dart:183`). The `TextScaler.noScaling` numbers sit in boxes that scale by the system scale.
- **Arabic-Indic digits.** The only Latin digits found came from the fixture's synthetic surah names («Synthetic surah 1»). `megabytes`, the margin marks and the page marks all go through `arabicDigits`.
- **Colour pairs.** The guard test passes. `accent`, `success` and `warning` are not used as text on `surface-sunk`; the `surface-sunk` text is `ink` or `ink-muted`, both in the pairs table.
- **AX-05 and the missing-data rules.** Highlights, tags, the ribbon and the playing marker carry a shape or a line as well as colour.

## 2. Screens that already conform

The probe showed no overflow at 320 wide at 200% text, in landscape, or on tablets, and the Android tap-target and label guidelines passed, for:
- **Tabs and roots:** home, mushaf index, listen, recitations, study, search, more, settings, sources, bookmarks (empty), resources (empty), onboarding.
- **Sheets:** go-to, context, surah-info, ayah, tafsir, report, first-use-tafsir.
- **Reader:** at 320×2.0, landscape (also at 2.0), tablet portrait, tablet landscape and 320×1.0: no overflow.

Every control built on `Pressable` and the tab, mode-chip, level-switch, radio and switch widgets has a `FocusRing`. The search and number fields use the identity's own `:focus-within` `primary` ring (`search_field.dart:25`). The Tab order follows reading order, right to left, with the tab bar last and right to left. Icon buttons are all named: `labeledTapTargetGuideline` and the unnamed-button scan found none.

**Reader reading order (AX-01), real router:**
1. «اذهب إلى / name / الجزء ١ · الحزب ١» (the position-bar button)
2. «سورة name / مكية · آية واحدة · ترتيبها ١» (the header)
3. the margin mark
4. the ayah text
5. «الآية ١»

This is the order AX-01 asks for.

## 3. Not covered by the probe

Word, copy, share, note, play-options, range, repeat, silence, stop-after, sleep and queue sheets, and the player, resources and bookmarks screens with data. The routes redirected away without their providers. Existing tests cover them (`word_sheet_test`, `copy_sheet_test`, `controls_harness`, `player_screen_test`, `resources_screen_test`).

## 4. TalkBack protocol (owner's phone)

Setup: TalkBack on, language Arabic, an APK built from `main`.

Run the ten tasks in these themes: paper at 100% text, then night at 200%, then contrast. Swipe right or left to move. Record on each step whether TalkBack said the expected words, and where focus landed.

1. **Start and resume.**
   1. Open the app.
   2. TalkBack must read «شعار القرآن الكريم», «القرآن الكريم», then «بحث, زر».
   3. Swipe on: «السلام عليكم», «أكمل من حيث توقفت, عنوان».
   4. Activate the continue card, which must open the reader at the saved ayah. (Check: the logo and name are read twice, nit 10.)
2. **Read a surah in order.**
   1. In the reader, swipe from the top.
   2. Expected: «اذهب إلى, <surah name>, الجزء n · الحزب n, زر»; «سورة <name>, مكية · n آيات…, زر»; the ayah text; «الآية 1»; next ayah; «الآية 2».
   3. The surah must be spoken before the position, and the ayah before its number.
3. **Go to a place.**
   1. Activate «اذهب إلى» at the top of the reader and open the sheet.
   2. Choose a surah, enter an ayah number, and confirm.
   3. Expected: the sheet closes and focus returns to the reader at that ayah.
   4. Enter a surah number that does not exist: «لا توجد سورة n» must be announced.
4. **Open the ayah tools and bookmark.**
   1. Swipe to an ayah, double-tap, and open its sheet.
   2. Expected: the ayah, then «تشغيل من هنا», «علامة مرجعية», «مركز الدراسة», and the other rows.
   3. Bookmark it and return to the reader.
   4. The marker must change shape (ribbon), not just colour.
5. **Listen.**
   1. Play from an ayah («تشغيل من هذه الآية» or «تشغيل من هنا»).
   2. In the mini player: the previous ayah button «الآية السابقة», pause, and «الآية التالية», each with a name.
   3. In the full player, find the seek track: it must say its label, a value, and «قابل للتعديل».
   4. Swipe up or down: it moves 5 seconds.
6. **Search.**
   1. Study, then search.
   2. Expected: «ابحث في القرآن», «نوع البحث» («كلمة», «بلا تشكيل»), «نطاق البحث».
   3. Type a word, then swipe to the result count (announced as a live region).
   4. Open a result and check the highlight has a line as well as colour.
7. **Tafsir.**
   1. Open the tafsir from an ayah sheet, or Study then tafsir.
   2. Expected: the source badge with its name and version, then the passage.
   3. Step to the next ayah («الآية التالية»), and open the source details.
8. **Note and the list.**
   1. Add a note to an ayah, then open More then «العلامات والملاحظات».
   2. Expected: the note card's edit and delete named with the ayah, and «تم الحذف» announced after a delete, with an undo.
9. **Copy and share.**
   1. Open the copy sheet from an ayah.
   2. Expected: «نسخ الآية», the radio group of forms with the selected one stated, the preview, and the copy button.
   3. After copying, note whether anything is said (deviation 5).
10. **Settings and the resource manager.**
    1. More then Settings.
    2. Change «مستوى الواجهة» and «السمة», and turn on «اتباع وضع النظام الداكن».
    3. Open the resource manager and download a recitation: «تنزيل», the progress as a percentage value, then «تم التنزيل».
    4. Delete it and confirm; the size must be spoken.

VoiceOver: the same ten tasks once an iOS build exists.

## 5. What I could not check without a device

- **TalkBack itself:** the actual spoken order and wording of each step, the double-announcement of settings headings, whether swiping past a surah header lands on its ayahs, and the position-bar button's merged label.
- **Reader and gestures:**
  - The reader's pinch gesture with TalkBack on.
  - Whether the queue reorder's 5% motion is under one frame with the system setting on.
  - Reader touch behaviour with a hardware keyboard.
- **Display and text:**
  - 200% text on the real APK's real fonts and the real pack's longest names.
  - Bold-text mode.
  - Real contrast pixels, since the guideline is unreliable here.
- **Screens and layout:**
  - The player, resources, bookmarks and tafsir in populated states, in the four themes.
  - Tablet layout and orientation changes with state kept.
  - The safe-area insets.
- **Screens beyond the shell:** none; every route was either probed or listed above.

## 6. Questions for the owner (Arabic)

1. الأجهزة اللوحية (NF-11): الهوية ترسم الهاتف فقط، والشاشات الآن تتمدد بعرض الجهاز كاملًا (زر بعرض ٩٨٤ على ١٠٢٤). كيف نتصرف؟
   - (موصى به) نثبّت عرضًا أقصى لعمود المحتوى على اللوحي بقيمة تقترحها المصممة ويعتمدها هو، ولا نُدخل رقمًا جديدًا قبل ذلك.
   - نُبقي التمدد كما هو ونعدّه مقبولًا في المرحلة ١.
   - نبني تخطيطًا من عمودين للوحي (تصميم جديد، خارج الهوية الحالية).
2. تأكيد النسخ: عند نسخ آية يُغلَق الحوار دون أي إعلان لقارئ الشاشة، ولا يوجد نص معتمد لذلك في ملف الترجمة. هل يعتمد نصًّا قصيرًا يُنطَق عند النجاح؟
   - (موصى به) يقترح هو النص بنفسه (مثلًا بالصيغة التي اعتمدها لـ «تم الحذف») فنضيفه مفتاحًا ونُعلنه للقارئ دون شكل بصري جديد.
   - نكتفي بإشعار النظام على أندرويد ونؤجل iOS.
3. لوحة المفاتيح في القارئ: حلقة التركيز حول الآية لم ترسمها الهوية، وهي مطلوبة لتحريك الآيات بلوحة مفاتيح. هل نستعمل حلقة `focus` الموجودة حول مستطيل الآية؟
   - (موصى به) نعم، نستعمل `FocusRing` الحالية بلا أي شكل جديد.
   - لا، ويبقى القارئ دون تنقل بلوحة المفاتيح حتى ترسم المصممة الحلقة.

## 7. What `docs/PROJECT_STATUS.md` and `docs/DECISIONS.md` should record

**Status file:**
- P1-35 step 1 is done: the audit found 2 must-fix items (reader keyboard access, `SeekTrack` keyboard), 5 should-fix and 4 nits.
- Pending human checks: the ten-task TalkBack protocol above, then VoiceOver.
- The builder's next steps are `test/a11y/`, the two keyboard fixes, `IntegrityAlert`'s live region, and the settings heading fix.

**Decisions file:**
- **Proposed decision A:** the tablet layout follows the owner's answer to question 1.
- **Proposed decision B:** `textContrastGuideline` is not a per-screen check (false positives on the tab bar and 14 px text). `test/guards/contrast_test.dart` stays the authority for AX-03, and `test/a11y/` asserts the token pairs.
- **Proposed decision C:** reader markers and marks at 26×26 stay exempt under D-097, and the a11y test excludes them by name.
- **Proposed decision D:** a keyboard route into the reader's ayahs. D-141 (7) said the reader has no screen-reader route to a marker or to the selected state. That is now partly met (markers are buttons with «الآية n»), but not for the keyboard.

**Verdict: does not conform.** Two must-fix gaps (reader and seek track keyboard access), five should-fix, four nits; two items wait for the owner.
