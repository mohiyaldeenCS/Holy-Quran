# Project status

Keep this file true. Update it with the work, in the same branch, every session
(`session-handoff` skill). If it disagrees with Git, Git is right and this file is
corrected first.

## Snapshot

| | |
| --- | --- |
| Updated | 2026-10-28 |
| Phase | 1 — opened before Gate 0's content items by the owner (D-099). Phase 0's engineering is merged |
| Stream A — app | Phase 1 runs as the 40 tasks of `docs/plans/PHASE1.md`. **22 merged**: P1-01 to P1-13, P1-15, P1-16, P1-18 to P1-21, P1-28, P1-38, P1-39 (P1-12, P1-15 and P1-28 partial). **Open**: #52 (P1-25), #53 (P1-27). **16 not started**. The lead merges after an independent review and CI (D-136) |
| Stream B — content | In progress, by the planning session and the owner |
| Working branch | One branch per task (`agent/p1-*`); worktrees under the session's scratchpad for parallel agents (D-132) |
| Last session | 2026-10-28, local session on the owner's Windows machine: state recovered from Git, the owner's pending decisions taken (D-128), resumption settled (D-129) |

## What is in the repository

- The Flutter app (package `holyquran`, Flutter 3.44.7 pinned, placeholder id
  `com.example.holyquran`, six platform folders of which only Android and iOS are
  built): an Arabic, right-to-left shell with five tabs and placeholder screens, on
  the design system. `lib/ui/core/theme/` (generated tokens and ramps, the four
  themes, follow-system dark), `lib/ui/core/widgets/` (the 13 widgets of M0.2, the 19 of M0.5,
  `SurahName`, `Pressable`, `PlayerButton`, `AppIconTile`, `RevealOnFocus`, and the
  generated icon paths), `lib/ui/core/tab_shell.dart` with the identity's
  `TabBar`, a debug-only gallery at `/gallery` (More tab, debug builds) in
  six parts (D-086), `lib/ui/core/l10n/` (Arabic-Indic digits, ayah and times counts), `lib/l10n/app_ar.arb`.
  Fonts and OFL texts in `assets/`.
- The domain core and pack reader (M0.3): `lib/domain/models/` (addresses, ranges,
  `PackText`, manifest, verified pack, surah info, word spans, edition map, pack
  failures, reading theme), `lib/utils/result.dart`, and `lib/data/` (manifest
  parser, signature seam, file service, the read-only `PackDatabase`, the pack and
  text repositories). Synthetic pack builder and independent reader in
  `testing/packs/`. The integrity suite in `test/integrity/`.
- About 1,690 tests: 1,631 that run anywhere (unit, widget, integrity, guards for
  fonts, imports, literals, design numbers, type rules, contrast, pack text, pack
  writes) and 57 golden tests with 168 images made on `ubuntu-24.04`. No content pack
  or feature yet.
- Tooling: strict `analysis_options.yaml` (D-046); CI in `.github/workflows/ci.yml`
  (D-043), with hand-started tasks `apk` (D-049) and `goldens` (D-056, D-059); the
  token and icon generator `tools/gen/` (D-054); the cloud-session setup hook
  `.claude/hooks/session-start.sh` (D-048). Milestone plans in `docs/plans/`. The
  pack format, version 1, in `docs/CONTENT_PACKS.md` (D-064), with the planning
  session's review and the two changes it asks for (D-077).
- `docs/` — PRD export, plan, architecture, design-system mapping, sources, rights
  register, decisions, workflow, Zaydi-library notes, the prompts for starting a
  session.
- `design/` — the approved identity: design system (tokens, 31 components, fonts in
  WOFF2 and pinned TTF), the ten identity boards, and a script that builds offline
  previews of both.
- `.claude/` — eight agents, five project skills, twenty vendored official Flutter
  and Dart skills, the SessionStart hook. `.mcp.json` — the Dart and Flutter MCP
  server.
- `tools/ziydia/` — the extraction tool for the Zaydi Library, and the ayah linker
  `ziydia_link.py` with its tests (135, run by hand: Python, no Flutter).

Not in the repository: any content pack; any Quran text as data (the PRD and the
design files show a few sample words and ayat as illustration, never to be copied);
raw extraction output; signing keys. The 13 logo SVG files are in
`design/design-system/assets/Logos/` (hashes in `design/README.md`).

## Done

- **PRD** complete: 49 raw requirements analysed into 21 modules with IDs, acceptance
  criteria, five phases with gates, source registry, deferred features. Exported at
  revision 151 to `docs/prd/PRD.ar.md`.
- **Sources**: the owner holds written permissions for every source that needed one
  (D-012). Registry: 9 ready, 9 awaiting our own verification, 1 deferred.
- **Identity** copied into `design/`. App fonts pinned and verified identical to the
  identity's (D-026). The rules for reproducing it are fixed (D-032).
- **Zaydi Library**: category index of 39 books; the eight first-release books
  extracted completely and checked (183, 471, 473, 514, 737, 165, 276, 440: about
  6,500 pages; results in `docs/content/ZIYDIA_LIBRARY.md`); structure of book 466
  inspected (fixed sub-headings, including النزول).
- **Project foundation**: this document set, agents, skills. Reviewed twice by an
  independent agent; its findings were applied before the merge.
- **M0.1 Repository and tooling** (pull request #2): environment recorded, Flutter
  pinned, kickoff answers applied (D-040 to D-045), strict lints, the Arabic
  five-tab shell, single ARB file, CI (Android build by hand, D-049), README, cloud
  setup hook. Logo files fetched from the identity artifact; the repository's copy of
  the identity verified byte-identical to the live artifacts. Pending: launch on an
  Android device (below).
- **M0.2 Design-system foundation** (pull request #3): generated tokens and icons,
  four themes and follow-system dark, fonts with hash guards, the three type answers,
  13 widgets, the debug gallery, golden images in four themes made on the golden
  platform, contrast and code guards; owner decisions D-050 to D-053 and D-058;
  engineering decisions D-054 to D-057, D-059, D-060. Reviewed by `code-reviewer`
  and `identity-auditor`, findings applied. Partial: the page size of `QuranText`
  does not centre its last line (S1, M1.2). The owner saw the gallery images in the
  four themes and approved them as matching the identity on 2026-10-07. Pending: the
  device checks below.
- **M0.3 Domain core and pack reader** (pull request #4): `QuranAddress` and
  `QuranRange` (D-063); pack format v1 in `docs/CONTENT_PACKS.md` (D-064); manifest
  parsing and verification with SHA-256, the signature as a seam that reports "not
  checked" (D-065); one read-only, immutable SQLite file per pack through `sqlite3`
  (D-061); `PackText` with its guards, replacing D-036 (D-062); `Result` and the
  sealed pack failures (D-066); the integrity suite on three targets (D-067).
  `QuranText` takes `PackText`; a display test proves that every ayah of a synthetic
  pack reaches it byte for byte. Golden images unchanged. Reviewed by
  `code-reviewer`; its findings were applied (schema check on open, word-span
  checks, pack location, source rules) or carried to M1.2, M1.4 and M1.5
  (`docs/plans/M0.3.md`). Pending: the checks below.
- **M0.4 Spikes, part 1** (pull request #6; plan `docs/plans/M0.4.md`; D-068 to
  D-072, owner answers on where spike code lives, one profile APK, Android 8.0 and
  iOS 15, the page mark inside the line). Spike code was built in `spike/`, run on
  Linux and in CI, and removed before the merge; it is kept at `be4fbc2` (the APK was built from `be7aed9`) (D-068).
  - S1 (`docs/spikes/S1-surah-rendering.md`): the Tanzil file read strictly on the
    CI runner gives a pack that passes the whole integrity suite, reproducibly; the
    font covers every code point; a surah-mode text block with markers, word
    hit-testing, highlights, last-line centring and page blocks. Findings for M1.2:
    SkParagraph reorders inline placeholders on right-to-left lines (worked around);
    ink leaves its line band, so nothing is clipped; Amiri Quran shapes a word by the
    word before it, so no line is laid out alone; a pause mark can start a line cut
    off from its word, which M1.2 must prevent without changing the text; 4,578
    letterless tokens (input to D-038).
  - S5 (`docs/spikes/S5-downloads.md`): resumable downloads, verify then activate,
    rollback, against a local server with faults.
  - S3 (`docs/spikes/S3-background-audio.md`): background playback of a generated
    tone with lock-screen, notification and headset controls.
  - The profile APK for every pending device check (D-069) is the artefact
    `holyquran-spike-apk` of CI run 68 (`actions/runs/37602557411`), kept until 2027-01-05.
  - Partial: everything on the device (below); S2, S4, S6, S7 and the S3 highlight
    part are not started.

- **Pack format reviewed by the planning session** (pull request #7): format
  version 1 accepted with two changes for stream A to apply, a `mark` table and
  `sources[].options` (D-077); P1 to P7 answered in `docs/CONTENT_PACKS.md`; the word
  and mark rule (D-078), the Tanzil file of the base pack (D-079) and a signature
  scheme (D-080) proposed. The answers that rest on the published structure of the
  Tanzil and KFGQPC files, not on the files themselves, are marked so; the pipeline
  checks them in B0.2.

- **Ayah linker for the Zaydi Library** (pull request #8): `tools/ziydia/ziydia_link.py`
  links books 183, 514, 276 and 471 from what each book prints, and checks the
  quotation each link rests on against the text of the Quran as book 514 prints it
  (D-081, D-082). 183: 2,721 linked passages, 2,647 confirmed by the check. 514:
  5,488 and 5,306. 276: 123 of 146 items, 116 confirmed. 471: 302 of 361 items, 291
  confirmed; much of that book can be linked to a surah only. Partial: no link has
  been seen by a reviewer or compared with a printed copy; the step that applies a
  reviewer's corrections is not written.
  The honorific codes were recounted from their markup: sixteen, not eleven. PRD §5.5
  updated and re-exported at revision 147. An independent agent reviewed the tool in
  two rounds and its findings were applied; what it verified, and what it did not, is
  stated in `docs/content/ZIYDIA_LIBRARY.md`, "Results".
- **Pack format review applied** (pull request #9, D-083): the `mark` table with
  `counts.marks` and `sources[].options` of D-077 are in `docs/CONTENT_PACKS.md`, the
  manifest parser, `PackDatabase`, the text repository (`MarkSpan`; word and mark
  spans checked together on a surah's first read), the synthetic pack builder and
  the integrity suite (marks, gaps made only of U+0020, words with a letter and marks
  without one, options).

- **Books 473 and 440 linked** (pull request #11, D-090). 473: 2,443 linked
  passages, 2,357 confirmed by the check; the surah comes from the book's own order
  (1, then 114 down to 2), and nearly half of its explanations print no ayah number
  and stay linked to the surah only. 440: 244 of 250 questions linked by the footnote
  that names the surah and ayah, 200 confirmed (37 quotations are too short to
  compare). Books 737 and 165 get no profile: from what they print they cannot be
  linked to ayat. An independent agent checked both profiles; what it verified is in
  `docs/content/ZIYDIA_LIBRARY.md`, "Results". PRD §5.5 re-exported at revision 151.

- **M0.5 Remaining design-system widgets** (pull request #10; plan
  `docs/plans/M0.5.md`; D-084 to D-089 and D-091). Foundations: `QuranText` colour
  roles and card form, `SurahName` (surah names travel as `PackText`), `SurahHeader`
  on `PackText`, `Pressable`, `timesCount`, the gallery's sample producer. Nineteen
  widgets: `AyahRow`, `SurahListItem`, `Tag`, `Stepper`, `ProgressBar`, `MiniPlayer`,
  `ContinueCard`, `ResourceRow`, `ReaderPlayerBar`, `WordSheet`, `SearchField`,
  `ModeChips`, `SearchSummary`, `SearchResult`, `HomeHeader`, `HomeDoor`,
  `ContinueListeningRow`, `ShareCard` (emerald, paper and night, 4:5) and `Splash`.
  The gallery shows them in five sections, one golden image per section per theme. Contrast pairs for every new colour pair; a test that the widgets draw
  a synthetic pack's bytes unchanged; the ramp allow-list kept current. `Match`,
  `ContextSheet` and the copy sheet moved to M1.2, M1.3, M1.8 and M1.6 (D-088). Built
  from two accounts: the first wrote the plan, 0a, 0b and batches A, B and D; the
  second finished batch C and steps E to G. `code-reviewer` and `identity-auditor`
  read every batch until both passed it; their findings were applied (`b815f96`,
  `ecb71f6`, `b8e671d`, `6871ead`) and the readings recorded in D-091. Golden images
  by CI runs 103 and 110. The owner confirmed D-089 and D-091 on 2026-10-11.
  Pending: the checks below.

## In progress

**M0.4 is complete** (part 2 on `claude/great-hamilton-9n23mt`, pull request #14). The
owner ran the device session on 2026-10-12 with the APK of CI run 38190527706 and
reported every check done and ready (no measurements sent); D-096 and D-097 close S4
and S7. The spike code is deleted in the cleanup commit; the last commit holding it is
`25d684c`. The M0.4 part 1 and M0.5 device checks were covered by the same session.

**Phase 1 is open (D-099)** and planned in `docs/plans/PHASE1.md` with one task text
per task in `docs/plans/tasks/`. Requirements whose registry rows are not `Ready` stay
unbuilt.

**Resumed 2026-10-28 from a local session (D-128).** Merged since: #54 (status and
D-128, D-129), #55 (the suite runs on Windows: `.gitattributes` LF, the generator's
`dart format` through a shell, separators, closed packs), #44 (P1-12, below), #51 (P1-15, below), #50 (P1-28, below).

- **P1-12 merged (#44), partial.** Copy sheet with the board's preview (Share.dc.html
  l.54) drawn from the pack, `QuranText.quoted` and `SurahName.span` (D-130); share
  sheet and 4:5 share card with PNG export at 1080 px; clipboard and share services
  provided in `share_providers.dart`. Partial: one copy form (the other two wait for
  P1-38 to add their Appendix B formats); 4:5 only, no size choice (D-089 (2): the
  owner sees 1:1 and 9:16 first); the share sheet's states are not in the gallery;
  SH-01's clause on copying several consecutive ayat, each with its number, has no
  task yet. Reviewed by `code-reviewer` (twice) and `identity-auditor` (twice).
- **P1-15 merged (#51), partial.** Settings screen (level, theme, follow-system),
  first-run setup frame with its level step, report sheet (address, pack id, version
  and source on one line), More hub. The user database and the settings repository are
  provided from `user.sqlite`; if it cannot be read the app starts on in-memory
  defaults and leaves the file untouched (D-133); Android keeps it out of backup
  (D-133; before user data is wired, a failed settings read must also put the user database in memory); More shows only entries whose screen has a route (D-134). RD-08 and LV-02
  are met in the app (visual checks pending); LV-01 partial (the first-run redirect is
  off until the continue button has wording); LV-04 not met. Follow-ups: LV-04's route
  flag in `routes.dart`; the setup's strings, continue button and redirect switched on
  (no task owns `startup_redirect.dart` before P1-26); the display-mode step with one
  choice (D-127, D-134), the recitation step hidden until a recitation is `Ready` (D-136); the mail send action of «أبلغ عن خطأ» (D-127); a shared
  sheet-frame widget (word, copy, report and player sheets each copy `.qk-sheet`);
  `LevelSwitch` and the theme switch at 320 wide and 200% (P1-35); user-data screens
  saying when the database is in memory (D-133); `userDataProviders` wiring
  (bookmarks, notes, keep-awake). Reviewed by `code-reviewer` (once, then fixes) and
  `identity-auditor`.
- **P1-25 merged (#52), partial.** Resource manager at `/more/resources` with tafsir
  and riwaya sections, download, delete, re-download and update states, storage bars,
  the integrity alert, and the first-use tafsir sheet (D-137). OF-01 partial
  (recitations go to P1-33; page-mushaf, tajweed and linguistic packs have no kind
  yet); OF-02 partial (no stop or pause; the size, source and version line is met);
  OF-03 partial (bars met; the free and used figures need the new strings); OF-06
  partial (the change summary shows; no update word or action; no rollback); TF-06 as
  far as the installer allows. Not reachable in the app until the installer is wired
  into `lib/config`. Follow-ups in D-137. Reviewed by `code-reviewer` and
  `identity-auditor` (twice).
- **P1-38 merged, the second batch of strings.** 83 keys in `lib/l10n/app_ar.arb`: 38 from
  Appendix B as the owner approved them (D-128 (4)), 45 worded by the lead (D-128 (5);
  the table is in `docs/plans/tasks/P1-38-strings-owner-batch.md`). Checked by script
  against the plan and the task, character for character. They unblock the setup's
  prompts and continue button, the report sheet's send and note, the integrity alerts,
  the go-to errors, the player's stop-after, sleep timer, unlimited repeat and
  add-to-queue, the resource manager's update, Wi-Fi, space and size lines, and the
  empty states. Not worded: source credits (D-128 (6)), copying several ayat, gallery
  titles, the sources screen's headings. For the owner's optional look: the lead's
  wording (owner's linguist, when he wishes).
- Open pull requests: #53 (P1-27). Merged since: #56 (the gallery test sized to the gallery; D-136), #57 (P1-39, the eight project icons in the generator), #58 (P1-38), #52 (P1-25). Their old CI runs wait
- **P1-28 merged (#50), partial.**
  Range, play-options, repeat, silence and queue sheets (D-135). AU-11 met; AU-02
  partial (ayah to ayah, several pages, a set of surahs and to the end of the mushaf
  need «من»/«إلى»); AU-03 partial (empty until something has played; the recitation
  chosen in the first-run setup will fill it); AU-09 partial (1 to 99 met; unlimited and
  the spoken counter not built); AU-17 partial (reorder and remove met; add not built);
  AU-07 and AU-08 not built. Follow-ups in D-135: the `PlaybackPlanBuilder` provider and
  a route test before any screen opens the sheets; timings in the plan; the sleep timer,
  stop-after, unlimited repeat and add-to-queue task. Reviewed by `code-reviewer` and
  `identity-auditor`.
  (`action_required`); a push by the lead starts a normal run.
- Not started: P1-14, P1-17, P1-22 (wave 2; P1-22's condition, D-097, is met),
  P1-23, P1-24, P1-26, P1-29, P1-30, P1-40 (wave 3), P1-31 to P1-34 (wave 4), P1-35 to
  P1-37 (wave 5), P1-38 and P1-39 (unblocked by D-128).
- The local branches of 2026-10-13 (`fix/bookmark-restore-nullable`,
  `chore/analysis-exclude-platform-dirs`) are not needed on the pinned SDK (analyze is
  clean without them) and are not pushed (D-129). On the owner's machine
  `analysis_options.yaml` keeps being rewritten with that branch's platform-folder
  excludes, most likely by an editor tab with unsaved edits; it is never committed.
- Local checks use `C:/SDK/flutter-3.44.7` (D-129). With it, on Windows, the full
  non-golden suite passes (3,228 on the P1-12 branch).

Agent runs so far (estimates from the SDK): about $160 across both keys for M0.4
part 2 and B0.11, plus the Phase 1 runs until the credit ran out.

Stream B: the owner is extracting book 466. B0.11 (the pack pipeline) is on `main`
(D-098).

## Next actions — stream A (the implementing account)

Work runs from a local session on the owner's machine (D-128): the lead delegates each
task to the agent its task text names, reviews, commits, pushes, opens the task's pull
request and merges it when review and CI pass. Decision numbers: take the number after
the highest on `main` and every open pull request (D-076).

1. Finish the open pull requests in PHASE1.md §2's order: #50 (P1-28, before P1-23),
   #51, #52, #53. For each: update from `main`, check with the pinned SDK, push, run
   the `goldens` task on the branch, pull the image commit, `code-reviewer` (and
   `identity-auditor` for UI), apply findings, update this file in the branch, merge.
2. The rest of wave 2: P1-14, P1-17, P1-22; then P1-29, P1-38 (Appendix B approved,
   Appendix C worded by the lead, D-128; add the two remaining copy formats) and P1-39
   (icons approved, D-128).
3. Give SH-01's several-ayat copy a task (with the ayah selection of P1-23 or the
   toolbar of P1-31), and the share sheet's gallery states.
4. Waves 3 to 5 in table order, each task when its "Needs" are merged.
5. Golden images: after a push that adds or changes a golden test, start CI by hand
   on the branch with the task `goldens`, pull the commit it pushes, and push again
   (D-056, D-059). Off `ubuntu-24.04` run `flutter test --exclude-tags golden test
   tools/gen/test`.

## Next actions — stream B (planning session and the owner)

1. Owner: finish extracting book 466 and upload the result.
2. Owner: obtain the honorific glyph table from the site owner (O-07). It has
   sixteen codes; the table with their counts is in
   `docs/content/ZIYDIA_LIBRARY.md`, "Known issues".
3. Owner: choose the Phase 1 recitations (O-04), decide on the general tafsirs
   (O-06), name the proofreader of the Hafs text (O-16) and decide who keeps the
   pack-signing key (O-03). All four are needed inside Phase 0.
4. Owner with the planning session: fill the rights register from the permission
   papers (B0.1, `docs/content/RIGHTS_REGISTER.md`).
5. Owner: give the religious reviewer the linking pages of books 183, 514, 276,
   471, 473 and 440 (`sample.html`, `review.html` and `compare.html` of each, sent to
   the owner on 2026-10-07 and rebuilt by the commands in `tools/ziydia/README.md`).
   He marks the sample, and checks every passage of the other two pages against the
   printed copy. He also says whether he accepts the rule of D-082, and whether an
   index of the ayat that book 165 cites is wanted (D-090).
   Planning session: write the step that applies the reviewer's corrections; rerun
   `compare` against the base pack when B0.2 builds it.
6. Planning session with the owner: the base pack (B0.2), KFGQPC assets (B0.3), the
   word index (B0.4), waqf-mark meanings (B0.8), acceptance data (B0.10), the pipeline
   (B0.11).
7. Planning session: run the app's integrity suite on the base pack when B0.2
   builds it: `flutter test test/integrity
   --dart-define=HOLYQURAN_PACK_DIR=<pack-id>/<version>` (D-067).

## Waiting on the owner

Kickoff questions K1–K4 were answered on 2026-10-07 (D-041 to D-044): keep the
placeholder application id for now (O-01 stays open, below); keep all six platform
folders; defer iOS builds to near the end of Phase 1; enable CI.

Answered on 2026-10-28 (D-128): resuming locally, Git authority, the status file,
PHASE1.md questions 1, 2, 13, 14 and 19, the eight icons, O-12, O-14 and O-18.

Open decisions that come later (full list in `docs/DECISIONS.md`):

| ID | Question, as it should be put to him | Needed by |
| --- | --- | --- |
| M0.4-1 | «هل ثبّتَّ نسخة التجارب السابقة (CI run 68) أو بدأت تجارب الجهاز للجزء الأول؟ قد تتطلب النسخة الجديدة حذف القديمة أولًا، وهذا يمسح بيانات تجربتي S1 وS5 على الهاتف.» | The part-2 APK |
| M0.4-2 | «ما طراز هاتفك، وإصدار أندرويد، والذاكرة، وواجهة الشاشة الرئيسية (سامسونج أو شاومي أو غيرها)، وحجم الشاشة؟» | The device run |
| M0.4-3 | «اختبار الإيماءات: كم مشاركًا (نقترح خمسة، بينهم شخص فوق الستين وآخر يستخدم الخط الكبير)، وعلى أي هواتف، وهل تدير الاختبار بالنص العربي الذي نجهزه؟» | The S7 usability test |
| M0.4-4 | «في الوثيقة تفتح لمسة فاصلة الآية «أدوات الآية»، وتفتح اللمسة المطوّلة «شريط أدواتها». هل هما الشريط نفسه بأفعاله الخمسة (موصى به، وبه تعمل التجربة الآن)، أم تفتح الفاصلة شيئًا آخر مثل ورقة الآية المصغّرة؟» | M1.6 (settled for the spike by the recommended option) |
| M0.4-5 | «يشترط AX-02 ألا يقل هدف اللمس عن 48، والكلمة في النص المتدفق لا يتجاوز هدفها عرضها ونصف الفراغين حولها. هل تُستثنى الكلمات وعلامات الوقف داخل النص كما يستثنيها معيار WCAG 2.2 للأهداف داخل النص (موصى به، والتجربة تقيس الأثر)، أم يتغير تصميم الإيماءات؟» | M1.2 (settled for the spike by the recommended option) |
| M0.4-6 | «ودجة الآية الداكنة غير مرسومة في الهوية. هل نبنيها من ألوان سمة «ليل» بالأدوار نفسها التي في ودجة الورق المرسومة (الأرضية، والإطاران، ولون النص، ولون المرجع) كما بُنيت بطاقة المشاركة الليلية (موصى به)، أم تُرسم لها نسخة في الهوية؟» | Phase 2 (settled for the spike by the recommended option, D-093) |
| M0.4-7 | «الودجة صورة بمقاسات ثابتة كبطاقة المشاركة، فلا تكبر مع حجم الخط في النظام، والآية التي لا تتسع تُتخطى. هل تبقى كذلك (موصى به)، أم تكبر مع إعداد النظام فتقل الآيات التي تتسع لها؟» | Phase 2 (settled for the spike by the recommended option) |
| M0.4-8 | «لا يخرج نص الآية من Dart إلى كود الودجة الأصلي (D-094)، فلا يقرأ قارئ الشاشة الآية من الودجة نفسها. هل يكفي أن يقرأ «ودجة الآية، سورة كذا، الآية n» ثم تفتح اللمسة الآية في التطبيق (موصى به)، أم يجب أن يقرأ نص الآية؟» | Task D of M0.4 part 2 (settled for the spike by the recommended option) |
| M0.4-9 | «في ودجة الآية: ارتفاع سطر الآية ٢٫٢ كما في بطاقات المشاركة وتُوسَّط أسطرها (موصى به، وبه تعمل التجربة)، أم ٢٫٠ كما في اللوحة مع محاذاة الأسطر إلى اليمين، وهذا يحتاج صيغة خاصة بالودجة من نص المصحف في المرحلة الثانية؟» | Phase 2 (settled for the spike by the recommended option) |
| M0.4-10 | «ودجة الآية بمقاسين، صغير ٢×٢ ومتوسط ٤×٢. هل تكون ودجة واحدة في قائمة الودجات يغيّر المستخدم حجمها فتتبدل هيئتها (موصى به، وبها تعمل التجربة)، أم ودجتين منفصلتين في القائمة، لكل مقاس واحدة؟» | Phase 2 (settled for the spike by the recommended option) |
| M0.4-11 | «الآية التي لا تتسع تُتخطى، والمقاس الصغير يتسع لآيات أقل من المتوسط. هل يختار كل مقاس آيته مما يتسع له وحده، فقد تختلف آية الودجتين في اليوم نفسه (موصى به، وبه تعمل التجربة)، أم تُختار الآية مما يتسع للمقاسين معًا فتتطابقان دائمًا وتقل الآيات المتاحة؟» | Phase 2 (settled for the spike by the recommended option) |
| M0.4-12 | «نزّلنا نص تنزيل بخيار «بلا علامات الأحزاب» (rub=false) فجاء الملف مطابقًا بايتًا ببايت للملف الذي فيه العلامات، وفيه ١٩٩ علامة ۞. لا نحذفها نحن لأن النص لا يُعدَّل. هل يبحث فريق المحتوى (المسار ب) في B0.2 عن طريقة رسمية للحصول على الملف دون العلامة، كاستعمال نموذج التنزيل في الموقع نفسه أو مراسلة القائمين على موقع تنزيل (موصى به)، أم تبقى العلامة في الحزمة علامةً مستقلة ويقرر العرض كيف يتعامل معها؟» | Answered 2026-10-12: stream B looks for an official Tanzil file without U+06DE (recommended); if none exists, the question returns to the owner (D-119). |
| M0.4-13 | «حجم النص في وضع السورة: ثماني درجات (٨٠٪، ٩٠٪، ١٠٠٪، ١١٥٪، ١٣٠٪، ١٥٠٪، ١٧٥٪، ٢٠٠٪) يقفز القرص إلى أقربها (موصى به، وبها تعمل التجربة)، أم درجات متساوية كل ١٠٪ من ٨٠٪ إلى ٢٠٠٪؟» | D-097, after the S7 usability test |
| M0.4-14 | «مع تفعيل «تقليل الحركة» في النظام: تبقى الصفحة ثابتة أثناء السحب ثم تتلاشى إلى التالية عند رفع الإصبع (موصى به، وبه تعمل التجربة)، أم تتبع الصفحة الإصبع أثناء السحب ويقتصر التلاشي على إكمال القلب؟» | D-097, after the S7 usability test |
| M0.4-15 | «إذا قُلبت الصفحة وهي مكبّرة: تُفتح الصفحة التالية بحجمها الكامل (موصى به، وبه تعمل التجربة)، أم بالتكبير نفسه؟» | D-097, after the S7 usability test |
| M0.4-16 | «اسم الودجة «ودجة الآية» ووصفها في قائمة الودجات لا يوجدان في ملف النصوص، ولا طريق الآن لنقل نص عربي منه إلى موارد أندرويد. هل نؤجل الاسم والوصف إلى المرحلة الثانية (WG-01) فنضيفهما إلى ملف النصوص ونولّد منهما موارد أندرويد، وتبقى الودجة في التجربة باسم التطبيق (موصى به)، أم نضيفهما الآن يدويًا للتجربة وحدها؟» | WG-01, Phase 2 (settled for the spike by the recommended option) |
| M0.4-17 | «في اللوحات تُرسم علامة الآية المختارة بحلقة ورقم باللون الأساسي (#0E5A52)، وفي المكوّن المرجعي ليس للعلامة حالة «مختارة». بالألوان الحالية يقل تباين رقم العلامة على لون التحديد في سمة الورق عن الحد (4.30 من 4.5). هل نضيف للعلامة حالة «مختارة» باللون الأساسي كما في اللوحات (موصى به)، أم تبقى كما هي؟» | M1.2 (the spike keeps the reference marker) |
| O-01 | «معرّف التطبيق في المتجرين (مثل com.اسمك.quran) واسم الناشر الذي سيظهر للمستخدمين. المعرّف لا يمكن تغييره بعد النشر.» | Answered 2026-10-12: deferred to M1.11; com.example.holyquran stays until then (recommended) (D-119). |
| O-04 | «ما التلاوات التي تريدها في الإصدار الأول (خمس على الأقل، اثنتان منها بتوقيت كلمات)، ومن أين نأخذ ملفاتها، وهل يجيز إذن كل منها التنزيل دون اتصال والاستضافة على خادمك؟» | Answered 2026-10-12: the planning session proposes the recitations with their rights records and the owner approves the list (recommended) (D-119). |
| O-06 | «هل تبقى التفاسير السبعة العامة (الميسر، المختصر، السعدي، الجلالين، البغوي، ابن كثير، الطبري) بجانب كتب المكتبة الزيدية؟» | Answered 2026-10-12: the first release ships the Zaydi-library books only; the seven general tafsirs are deferred (D-119). |
| O-03 | «حزم المحتوى تُوقَّع بمفتاح خاص. من يحتفظ بالمفتاح، وأين يجري التوقيع؟» | Answered 2026-10-12: the private key is a GitHub Actions secret and a CI task signs the pack (the owner's choice over the recommended offline key). The owner generates the key pair and adds the secret; the app embeds the public key and a spare (D-119). |
| O-16 | «من يدقّق نص حفص قبل اعتماده؟ الوثيقة تطلب حافظًا متقنًا. هل يتولاه القارئ المُجاز الذي ذكرتَه أم شخص آخر؟» | Answered 2026-10-12: the licensed reciter the owner named proofreads the Hafs text against the Madinah mushaf and signs it off (recommended) (D-119). |
| O-07 | «نحتاج من صاحب المكتبة الزيدية جدول رموز خط الموقع: ما العبارة التي يرسمها كل رمز من الرموز الستة عشر؟ وهي ÷ # ø @ ~ $ ª À ¥ ® & ¤ ¦ ^ ¿ والخط العمودي، وجدولها بأعدادها في ملف المكتبة الزيدية في المستودع.» | Before any Zaydi-library book is shown |
| O-17 | «في الوثيقة توصيتان لم تعتمدهما بعد ونراهما لازمتين للإصدار الأول: «أبلغ عن خطأ» من أي آية أو مادة، وإعداد أولي من ثلاث خطوات (وضع العرض، المستوى، التلاوة). هل تعتمدهما؟» | Answered 2026-10-12: both adopted (recommended): a three-step first-run setup (display mode, level, recitation; the recitation step activates when recitations are Ready) and «أبلغ عن خطأ» from any ayah or entry (D-119). |
| O-08 | «أين تُستضاف حزم المحتوى للتجربة ثم للإطلاق؟ يكفي أي استضافة ملفات ثابتة عبر HTTPS.» | Answered 2026-10-12: GitHub Releases of this repository host the packs for testing (recommended); the launch host is chosen before the end of Phase 1 (D-119). |
| O-11 | «هل لديك حساب مطوّر في Google Play وفي App Store؟ ومن يحتفظ بمفتاح توقيع التطبيق؟» | M1.11 |
| O-09 | «أي خدمة خادم نعتمد للحسابات والمزامنة في المرحلة 2؟» | Phase 2 |

Permission conditions to confirm with him when each is first needed are listed in
`docs/SOURCES.md` and recorded in `docs/content/RIGHTS_REGISTER.md`.

## Pending human checks

| Milestone | Check | Who | How |
| --- | --- | --- | --- |
| M0.1 | The shell launches on Android: the app opens in Arabic, right to left, on الرئيسية, and the five tabs switch | Owner, on his Android phone | Install the spike APK (D-069, artefact `holyquran-spike-apk` of CI run 68) once; its launcher's "App" entry opens the shell. No session so far has had an Android SDK |
| M0.2 | Screen reader (TalkBack), keyboard focus ring, the system bold-text setting and 200% text on a real device, for the M0.2 widgets | Owner, on his phone | The spike APK's "Component gallery" entry |
| M0.3 | The integrity suite passes on the real base pack | Planning session, when B0.2 delivers it | The command in stream B's next actions |
| M0.3 | The bundled SQLite of `sqlite3` runs on Android | Owner | The spike APK's S1 "Prepare text" opens the pack through it (the build itself passed in CI runs 51 and 66) |
| M0.4 | S1, S3, S5 device protocols: shaping by eye, hit test, 200%, NF-01 cold start, NF-02 scroll, 60-minute locked playback and controls, downloads with Wi-Fi gating, resume, corrupt file, low space, rollback | Owner, on his phone (model, Android version and memory still to be told) | The three spike pages, "Device protocol"; run S1 before S5 |
| M0.5 | The gallery images of the five new sections, in the four themes, match the identity. Shadows show as hard bands in these images because the test renderer turns blur off; in the app they are soft | Owner | `test/ui/core/gallery/goldens/gallery_<section>_<theme>.png` on `main`, or the gallery of the next APK |
| M0.5 | TalkBack reading order and labels (the ayah first in `AyahRow` and `SearchResult`), keyboard focus with the chip and tab strips scrolling to the focused item, the bold-text setting and 200% text, for the M0.5 widgets | Owner, on his phone | The gallery of an APK built from `main` with the CI `apk` task; the spike APK of CI run 68 predates M0.5 |
| P1-12 | TalkBack and VoiceOver read the copy sheet's radio group and preview; the focus ring shows on its rows with a hardware keyboard; the bottom safe-area inset; the exported share PNG (transparent corners) looks right in other apps; the fit's speed on a slow phone | Owner, on his phone | An APK built from `main` with the CI `apk` task |
| P1-12 | The owner's look at three choices the lead made where the identity disagrees with itself or gives no token: the unselected radio ring on `line-strong` (the board draws `#8C9794`), the copy sheet docked with `.qk-sheet`'s top border (the board floats it), «مشاركة» on the share button. Where the identity is silent: a long ayah in the copy preview is shown whole and pushes «انسخ» below the fold (the sheet scrolls); the reference may wrap inside its brackets | Owner | The `copy_sheet_*` and `gallery_home_share_*` images on `main` |
| P1-15 | The four themes on screen for More, onboarding and the report sheet (only settings has goldens); TalkBack and VoiceOver (settings headings are read twice); the focus ring with a keyboard; 320 wide at 200% | Owner, on his phone | An APK built from `main` with the CI `apk` task |
| P1-15 | The owner sees the report sheet before «أبلغ عن خطأ» ships (D-127), including the Latin pack id on the « · » line; the More hub's outlined buttons until a navigation row is drawn | Owner | The report sheet in an APK, once something opens it |
| P1-15 | An APK builds with the backup attributes: locally `flutter build apk --debug` failed in Kotlin incremental caches of other plugins (project on D:, pub cache on C:); the merged manifest and resources compiled | CI `apk` task | Run the `apk` task on `main` after the merge |
| P1-28 | The owner's look where the identity draws nothing: queue rows straight on `surface` with a hairline (the word sheet sets its rows in a sunk card); the sheet title at `sectionTitle` 20/600 (the context sheet's title is 700); an empty queue showing only its title (no sentence yet) | Owner | The `test/ui/features/listen/controls/goldens/*` images on `main` |
| P1-28 | TalkBack and VoiceOver on the five sheets (the range title and its chip group both read «محدد النطاق»); keyboard focus order; the queue reorder with the system's reduce-motion setting on | Owner, on his phone | An APK built from `main`, once a screen opens the sheets |

## Environment

| Where | State |
| --- | --- |
| Planning session (cloud) | No Flutter SDK. Network policy blocks `pub.dev`, `storage.googleapis.com`, `dl.google.com` and Maven, so Flutter cannot be installed or run there. Public GitHub repositories are readable with `git`. `gh` works through the REST API only. The artifact asset store is unreachable. Nothing in this repository was compiled or run by that session. |
| Implementing session, 2026-10-07 (cloud) | Ubuntu 24.04.5 LTS, x86_64, 4 cores, 15 GB. No Flutter preinstalled: Flutter **3.44.7** stable (framework `84fc5cbb22`, engine `69c8c61792`, Dart 3.12.2) installed from `storage.googleapis.com` into `~/sdk/flutter` and linked into `/usr/local/bin`; this is the pinned version (D-040). `pub.dev`, `storage.googleapis.com`, Maven Central and Google Maven are reachable; `dl.google.com` is blocked, so there is **no Android SDK**, no emulator and no device: the app cannot be built or launched for Android here, only analysed and tested (CI builds the APK). `flutter doctor`: Flutter OK; Android toolchain missing; Chrome missing; Linux toolchain lacks GTK. No macOS. Java 21 present. `git` 2.43 works; `gh` 2.89 is installed: `gh auth status` reports the token as invalid, but `gh api` calls work through the session proxy; the session's GitHub tools also work. The Dart MCP server failed to connect at session start (`dart` was not on the PATH); it is not waiting for approval. The SessionStart hook (D-048) puts `dart` on the PATH for later sessions. iOS could not be tried: no macOS, and iOS builds are deferred (D-042). |
| Local session, 2026-10-28 (owner's machine) | Windows 11 Pro, Git Bash and PowerShell. Flutter 3.47.6 (Dart 3.13.5) in `C:/SDK/flutter`; the pinned 3.44.7 installed beside it in `C:/SDK/flutter-3.44.7` for checks (D-129). Android SDK in `C:/SDK/Android_SDK`. `gh` authenticated. `core.autocrlf=true`. The Dart MCP server timed out at session start. |

## Risks being watched

- Permission conditions have not been read clause by clause; every permission-based
  record in the rights register is open until the owner reads it from the paper.
- Word boundaries differ between sources; the unified word index and mapping tables
  (B0.4) must exist before search, sync, tajweed and linguistic features.
- Zaydi-library text needs an approved honorific table (sixteen codes) and reviewed
  ayah linking. The first run found 9 printed ayah numbers that appear to point at
  the wrong ayah; a reviewer must clear every flagged or unconfirmed link (D-082).
- In 24 passages of book 514 the quotation the commentary opens with is not found, as
  worded, in the text the book prints above it (`docs/content/ZIYDIA_LIBRARY.md`,
  results for book 514). The religious reviewer says why, and what the app shows when
  a commentary quotes an ayah otherwise than the Hafs text displayed above it.
- Rendering fidelity of the Quran fonts in Flutter is unproven until spikes S1 and S2.
- Eight icons are still to be drawn and approved before M1.6 (D-051).
- No pack can ship until a real signature verifier and key exist (D-065, O-03).
- iOS builds are deferred to near the end of Phase 1 (D-042), while Gate 0 asks for
  measurements on both systems. Closing Gate 0 on Android measurements alone needs
  the owner's explicit decision (`docs/IMPLEMENTATION_PLAN.md`, "Gate 0 and iOS").
- Left from the M0.1 review, for the milestone named:
  - The router has no `errorBuilder`, so an unknown location shows go_router's
    default English page. Nothing reaches it yet; handle it with in-app addresses
    (`NV-06`, M1.3).
  - Branch-stack tests are weak until a branch has a child route. Strengthen them
    when the first child route arrives.
  - Flutter 3.44.7 is written in two places, the CI workflow and the setup hook; an
    upgrade changes both (D-040).
- Left from the M0.2 reviews, for the milestone named:
  - The context sheet justifies compact Quran text at 23 px (`.qk-ctx
    .qk-quran-compact`); `QuranText` renders compact start-aligned everywhere
    (D-060), so `ContextSheet` needs its own variant (M1.3).
  - `AyahMarker` is the touch target for the ayah tools; at 26 px it needs a 48 hit
    area when it becomes tappable (M1.6).
  - `motionFast` and `motionSlow` have no caller yet; they are the identity's scale
    and are used by the first widgets that animate with them.
- Left from the M0.5 reviews, for the milestone named:
  - A Quran word wider than its line is broken by the text engine wherever
    `QuranText` wraps, which a long word at a large text size can be. `WordSheet`
    prevents it for its one word (D-091, 12); M1.2 must prevent it in flowing text,
    together with the S1 finding of a pause mark cut off at a line start.
  - `SearchResult` keeps its expanded state inside the widget, so in a lazily built
    list a card scrolled away and back collapses again; M1.8 makes it the caller's.
  - After a search result's link has had keyboard focus and the view widens and
    narrows again, the link's semantics may lose its focusable flag while Tab still
    reaches it; Flutter's own `ExcludeFocus` behaves the same. Check with TalkBack
    (M1.8).
  - `timesCount` has no caller since the repeat label became its own plural
    (D-091, 11); the memorisation widgets of Phase 2 use it.
  - The greeting of the home board has no strings yet; M1.1 adds them with the home
    screen, and the header padding and reader-bar margin go to the metrics files of
    M1.1 and M1.2 (D-091, 4).
- The identity's own values miss the 4.5:1 contrast of `AX-03` in a few places
  (O-12).
- Three registry rows that Phase 1 needs are not `Ready` yet: 6, 8 and 19.

## Ideas, not requirements

Nothing yet. Ideas raised during the build are listed here and go to the owner; they
are not built until he approves and the PRD is updated.

## Session log

Newest first. One line per session.

| Date | Session | What was done | Where |
| --- | --- | --- | --- |
| 2026-10-28 | Local session (owner's Windows machine) | Recovered the state from Git after the Actions runs stopped on 2026-10-12 for lack of API credit; corrected this file; ran analyze and the non-golden tests locally (48 Windows-only failures); took the owner's decisions (D-128) and settled resumption (D-129). | `docs/resume-2026-10-28` |
| 2026-10-11 | Implementing session (second account), continued | On the owner's instruction, set up implementation by agents in GitHub Actions on his two API accounts: `agent.yml` and `agent.mjs` (Claude Agent SDK 0.3.296, option names read from its type definitions), the `check` task in CI, D-092, the workflow section. Linted with actionlint and shellcheck; the script was smoke-tested locally with an invalid key. After the merge: M0.4 part 2 planned as agent waves (D-093 to D-095) and step 0 done; the trial runs and every other Actions run since 17:13 UTC end in `startup_failure`, a setting the owner must check (M0.4-6). | Pull request #13; `claude/great-hamilton-9n23mt` |
| 2026-10-11 | Implementing session (second account) | Found the first account's session still at work on the M0.5 branch; the owner chose this session to continue and the other handed over cleanly. Adopted its work (0a, A, B, D) and dropped a duplicate 0a; finished batch C; showed the five sections in the gallery (E); tested that the widgets draw a pack's bytes unchanged and kept the ramp allow-list current (F); code review and identity audit of every batch until both passed, findings applied; D-091; golden images by CI runs 103 and 110; merged; the owner confirmed D-089 and D-091. | Pull requests #10 and #12 |
| 2026-10-11 | Implementing session (continued) | M0.5: step 0a with code review applied; batches A, B and D (14 widgets, five gallery sections); batch C partial; stopped at the owner's request to continue from the other account. | Draft pull request #10 |
| 2026-10-07 | Planning session | Linked books 473 (surahs in the book's own order, ayah numbers inside quotations) and 440 (footnotes that name the surah and ayah); found that 737 and 165 cannot be linked to ayat from what they print; D-090; independent review applied; PRD at revision 151. Recorded from Git where the implementing session stopped (draft pull request #10). | Pull request #11 |
| 2026-10-07 | Planning session | Built and tested the ayah linker for books 183, 514, 276 and 471, with a check of every link against the text printed in book 514; recounted the honorific codes (sixteen); D-081, D-082; PRD re-exported at revision 147; two rounds of independent review applied. | Pull request #8 |
| 2026-10-07 | Planning session | Reviewed pack format v1 and answered P1–P7 and stream A's question about the Tanzil file; D-076 to D-080; a rule for two sessions working at once in `docs/WORKFLOW.md`. | Pull request #7 |
| 2026-10-07 | Planning session | Checked the owner's extraction of seven Zaydi-library books (471, 473, 514, 737, 165, 276, 440): all complete; multi-part navigation confirmed; three more honorific codes found; linking prospects noted per book. PRD §5.5 updated and re-exported at revision 145. | Pull request #5 |
| 2026-10-07 | First implementing session (continued) | Applied the planning session's pack format review: mark table, counts.marks, source options, integrity checks for marks (D-083). | Pull request #9 |
| 2026-10-07 | First implementing session (continued) | M0.4 part 1: plan; owner answers D-068 to D-071; S1 text path on the real Tanzil text in CI, surah-mode rendering and measurements; S5 downloads; S3 playback; spike APK; two code reviews applied; spike code removed before merge. | Pull request #6 |
| 2026-10-07 | First implementing session (continued) | M0.3: plan in `docs/plans/M0.3.md`; pack format v1; addresses, `PackText`, manifest verification, read-only SQLite reader, text repository, integrity suite and guards; D-061 to D-067; code review applied. | Pull request #4 |
| 2026-10-07 | First implementing session (continued) | M0.2: plan in `docs/plans/M0.2.md`; owner decided follow-system dark (D-050, D-053), the APK only by hand (D-049), the missing icons (D-051, D-052), tab label scaling (D-058); generator, themes, fonts, 13 widgets, gallery, 60 goldens via the CI `goldens` task, guards; code and identity reviews applied. | Pull request #3 |
| 2026-10-07 | First implementing session | Read the documents; installed Flutter 3.44.7; recorded the environment; owner answered K1–K4, O-15 (D-050) and the APK question (D-049); fetched the 13 logo files and verified the identity copy against the live artifacts; M0.1: strict lints, Arabic five-tab shell, single ARB, CI with Android build, setup hook, README; `code-reviewer` findings applied. | Pull request #2 |
| 2026-10-07 | Planning session | Updated the PRD to revision 129 (sources ready, decisions, Zaydi-library section, section order fixed, registry row 19, new open points). Added the project foundation: PRD export, architecture, plan, design-system mapping, sources, rights register, decisions, workflow, identity files with verified fonts and a preview script, agents, skills, MCP configuration, extraction tool. No application code. | Pull request #1 |
| 2026-10-06 | Owner's other account | `flutter create` skeleton committed. | `664e167` |
