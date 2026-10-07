# Project status

Keep this file true. Update it with the work, in the same branch, every session
(`session-handoff` skill). If it disagrees with Git, Git is right and this file is
corrected first.

## Snapshot

| | |
| --- | --- |
| Updated | 2026-10-07 |
| Phase | 0 — Foundation. Gate 0 not met |
| Stream A — app | M0.1, M0.2 and M0.3 merged, with human checks pending (pull requests #2, #3 and #4). Next milestone: **M0.4 Spikes** |
| Stream B — content | In progress, by the planning session and the owner |
| Working branch | None open. Start M0.4 from `main` (on the branch the session is bound to, D-045) |
| Last session | First implementing session: environment, kickoff answers, M0.1, M0.2 and M0.3 (pull requests #2, #3 and #4) |

## What is in the repository

- The Flutter app (package `holyquran`, Flutter 3.44.7 pinned, placeholder id
  `com.example.holyquran`, six platform folders of which only Android and iOS are
  built): an Arabic, right-to-left shell with five tabs and placeholder screens, on
  the design system. `lib/ui/core/theme/` (generated tokens and ramps, the four
  themes, follow-system dark), `lib/ui/core/widgets/` (13 design-system widgets and
  the generated icon paths), `lib/ui/core/tab_shell.dart` with the identity's
  `TabBar`, a debug-only gallery at `/gallery` (More tab, debug builds),
  `lib/ui/core/l10n/` (Arabic-Indic digits, ayah count), `lib/l10n/app_ar.arb`.
  Fonts and OFL texts in `assets/`.
- The domain core and pack reader (M0.3): `lib/domain/models/` (addresses, ranges,
  `PackText`, manifest, verified pack, surah info, word spans, edition map, pack
  failures, reading theme), `lib/utils/result.dart`, and `lib/data/` (manifest
  parser, signature seam, file service, the read-only `PackDatabase`, the pack and
  text repositories). Synthetic pack builder and independent reader in
  `testing/packs/`. The integrity suite in `test/integrity/`.
- About 1,070 tests: unit, widget, integrity, guards (fonts, imports, literals,
  design numbers, type rules, contrast, pack text, pack writes) and 60 golden images
  made on `ubuntu-24.04`. No content pack or feature yet.
- Tooling: strict `analysis_options.yaml` (D-046); CI in `.github/workflows/ci.yml`
  (D-043), with hand-started tasks `apk` (D-049) and `goldens` (D-056, D-059); the
  token and icon generator `tools/gen/` (D-054); the cloud-session setup hook
  `.claude/hooks/session-start.sh` (D-048). Milestone plans in `docs/plans/`. The
  pack format, version 1, in `docs/CONTENT_PACKS.md` (D-064).
- `docs/` — PRD export, plan, architecture, design-system mapping, sources, rights
  register, decisions, workflow, Zaydi-library notes, the prompts for starting a
  session.
- `design/` — the approved identity: design system (tokens, 31 components, fonts in
  WOFF2 and pinned TTF), the ten identity boards, and a script that builds offline
  previews of both.
- `.claude/` — eight agents, five project skills, twenty vendored official Flutter
  and Dart skills, the SessionStart hook. `.mcp.json` — the Dart and Flutter MCP
  server.
- `tools/ziydia/` — the extraction tool for the Zaydi Library.

Not in the repository: any content pack; any Quran text as data (the PRD and the
design files show a few sample words and ayat as illustration, never to be copied);
raw extraction output; signing keys. The 13 logo SVG files are in
`design/design-system/assets/Logos/` (hashes in `design/README.md`).

## Done

- **PRD** complete: 49 raw requirements analysed into 21 modules with IDs, acceptance
  criteria, five phases with gates, source registry, deferred features. Exported at
  revision 129 to `docs/prd/PRD.ar.md`.
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

## In progress

Nothing in stream A.

Stream B: the owner is extracting book 466 (التهذيب في التفسير, about 7,325 site
pages). The review of `docs/CONTENT_PACKS.md` by the planning session has not started.

## Next actions — stream A (the implementing account)

1. Read, in this order: `CLAUDE.md`, this file, `docs/WORKFLOW.md`, the whole of
   `docs/prd/PRD.ar.md` once, `docs/IMPLEMENTATION_PLAN.md`, `docs/ARCHITECTURE.md`,
   `docs/DESIGN_SYSTEM.md`, `docs/SOURCES.md`, `docs/DECISIONS.md`,
   `design/README.md`. Component sources and boards are read per task, not up front.
2. Check the environment (`flutter --version` should print 3.44.7; the SessionStart
   hook installs it in cloud sessions). If the machine differs from "Environment"
   below, record it.
3. Start **M0.4 Spikes** (`docs/IMPLEMENTATION_PLAN.md`): plan with
   `flutter-architect` and keep the plan in `docs/plans/M0.4.md`. S1, S5 and the
   playback part of S3 need nothing from stream B. The plan says spike code lives on
   `spike/*` branches that are never merged; a session bound to one branch (D-045)
   cannot push those, so settle where spike code lives first and record it. S1 needs
   the Tanzil file downloaded into the ignored `data/raw/`, never committed, with its
   SHA-256 on the spike page.
4. Golden images: after a push that adds or changes a golden test, start CI by hand
   on the branch with the task `goldens` (Actions → CI → Run workflow, or the API),
   pull the commit it pushes, and push again so the pull request is checked
   (D-056, D-059). Off `ubuntu-24.04` run `flutter test --exclude-tags golden test
   tools/gen/test`.
5. Draw the eight new icons of D-051 on the identity's icon rules and show each to
   the owner before M1.6 needs them; add them to the generator's input only after he
   approves.
6. If M0.4 is finished before Gate 0 is met, continue with **M0.5**, not with
   Phase 1.

## Next actions — stream B (planning session and the owner)

1. Owner: finish extracting book 466 and upload the result.
2. Owner: obtain the honorific glyph table from the site owner (O-07). It now has
   eleven codes, not eight.
3. Owner: choose the Phase 1 recitations (O-04), decide on the general tafsirs
   (O-06), name the proofreader of the Hafs text (O-16) and decide who keeps the
   pack-signing key (O-03). All four are needed inside Phase 0.
4. Owner with the planning session: fill the rights register from the permission
   papers (B0.1, `docs/content/RIGHTS_REGISTER.md`).
5. Planning session: build the ayah linker for book 183, then for 514, 471 and 276,
   which are marked the same way; inspect how 473, 165, 737 and 440 can be linked;
   prepare the reviewer's sample.
6. Planning session with the owner: the base pack (B0.2), KFGQPC assets (B0.3), the
   word index (B0.4), waqf-mark meanings (B0.8), acceptance data (B0.10), the pipeline
   (B0.11).
7. Planning session: review `docs/CONTENT_PACKS.md` (format v1, merged with
   pull request #4) and answer its questions P1–P7 and the signing note. Changes go
   into a new version of that file.
8. Planning session: run the app's integrity suite on the base pack when B0.2
   builds it: `flutter test test/integrity
   --dart-define=HOLYQURAN_PACK_DIR=<pack-id>/<version>` (D-067).

## Waiting on the owner

Kickoff questions K1–K4 were answered on 2026-10-07 (D-041 to D-044): keep the
placeholder application id for now (O-01 stays open, below); keep all six platform
folders; defer iOS builds to near the end of Phase 1; enable CI.

Open decisions that come later (full list in `docs/DECISIONS.md`):

| ID | Question, as it should be put to him | Needed by |
| --- | --- | --- |
| O-01 | «معرّف التطبيق في المتجرين (مثل com.اسمك.quran) واسم الناشر الذي سيظهر للمستخدمين. المعرّف لا يمكن تغييره بعد النشر.» | Before the first store upload |
| O-04 | «ما التلاوات التي تريدها في الإصدار الأول (خمس على الأقل، اثنتان منها بتوقيت كلمات)، ومن أين نأخذ ملفاتها، وهل يجيز إذن كل منها التنزيل دون اتصال والاستضافة على خادمك؟» | Phase 0 (B0.5) |
| O-06 | «هل تبقى التفاسير السبعة العامة (الميسر، المختصر، السعدي، الجلالين، البغوي، ابن كثير، الطبري) بجانب كتب المكتبة الزيدية؟» | Phase 0 (B0.7) |
| O-03 | «حزم المحتوى تُوقَّع بمفتاح خاص. من يحتفظ بالمفتاح، وأين يجري التوقيع؟» | Phase 0 (B0.11, and the base pack before M1.2) |
| O-16 | «من يدقّق نص حفص قبل اعتماده؟ الوثيقة تطلب حافظًا متقنًا. هل يتولاه القارئ المُجاز الذي ذكرتَه أم شخص آخر؟» | Gate 0 |
| O-07 | «نحتاج من صاحب المكتبة الزيدية جدول رموز خط الموقع: ما العبارة التي يرسمها كل من @ # ÷ ø $ ~ & ¥ ® ^ والخط العمودي؟» | Before any Zaydi-library book is shown |
| O-02 | «أدنى إصدار ندعمه من Android وiOS؟ توصية الوثيقة: Android 8.0 وiOS 15.» | End of Phase 0 |
| O-17 | «في الوثيقة توصيتان لم تعتمدهما بعد ونراهما لازمتين للإصدار الأول: «أبلغ عن خطأ» من أي آية أو مادة، وإعداد أولي من ثلاث خطوات (وضع العرض، المستوى، التلاوة). هل تعتمدهما؟» | M1.1 |
| O-08 | «أين تُستضاف حزم المحتوى للتجربة ثم للإطلاق؟ يكفي أي استضافة ملفات ثابتة عبر HTTPS.» | M1.4 for a test host; end of Phase 1 for launch |
| O-14 | «تصنيف «تفسير» في العلامات ليس له شكل ولا لون في الهوية، ولا توجد لوحة ألوان للتصنيفات التي يضيفها المستخدم. ما الشكل واللون، وما الألوان المتاحة؟ وهل تبقى ألوان التصنيفات الأربعة ثابتة في كل السمات كما في الهوية؟» | M1.6 |
| O-11 | «هل لديك حساب مطوّر في Google Play وفي App Store؟ ومن يحتفظ بمفتاح توقيع التطبيق؟» | M1.11 |
| O-18 | «هل نضيف تقارير أعطال وتشخيصًا مجهول الهوية بموافقة المستخدم، وعبر أي خدمة؟ بدونها لا يُقاس معدل الأعطال.» | M1.11 |
| O-12 | «في الهوية مواضع تباينها دون الحد المطلوب: التسمية الذهبية في بطاقة «أكمل القراءة» وسطر المرجع في بطاقة المشاركة الزمردية (3.9 إلى 1)، ورقم الآية داخل الفاصلة الممتلئة في سمة السيبيا (3.1 إلى 1)، وست قيم من ألوان التجويد (بين 3.85 و4.43 إلى 1)، ومسار المفتاح ومقبضه وهو مطفأ (بين 1.3 و1.5 إلى 1، والحد لحدود عناصر التحكم 3 إلى 1). هل نقبلها كما هي، أم يعدّل المصمم قيمها؟» | M1.1 for the switch; M1.2 for the card; M1.10 for the marker; before Phase 2 for tajweed |
| O-09 | «أي خدمة خادم نعتمد للحسابات والمزامنة في المرحلة 2؟» | Phase 2 |

Permission conditions to confirm with him when each is first needed are listed in
`docs/SOURCES.md` and recorded in `docs/content/RIGHTS_REGISTER.md`.

## Pending human checks

| Milestone | Check | Who | How |
| --- | --- | --- | --- |
| M0.1 | The shell launches on Android: the app opens in Arabic, right to left, on الرئيسية, and the five tabs switch | Owner, or a session with an Android SDK and emulator | Owner's choice (D-049): once, at the end of Phase 0 or when he wants to try it, start the CI workflow by hand (Actions → CI → Run workflow) and install the `holyquran-debug-apk` it attaches; or `flutter run` on a device. No session so far has had an Android SDK |
| M0.2 | Screen reader (TalkBack), keyboard focus ring, the system bold-text setting and 200% text on a real device, for the M0.2 widgets | Owner, on a device | With the debug APK (CI task `apk`): open More → «معرض المكوّنات» |
| M0.3 | Review of `docs/CONTENT_PACKS.md`, questions P1–P7 | Planning session | Read the file; answer in a change to it |
| M0.3 | The integrity suite passes on the real base pack | Planning session, when B0.2 delivers it | The command in stream B's next actions |
| M0.3 | The Android build links the bundled SQLite of `sqlite3` (its build hook) | CI | The hand-started `apk` task, with the final APK (D-049) |

## Environment

| Where | State |
| --- | --- |
| Planning session (cloud) | No Flutter SDK. Network policy blocks `pub.dev`, `storage.googleapis.com`, `dl.google.com` and Maven, so Flutter cannot be installed or run there. Public GitHub repositories are readable with `git`. `gh` works through the REST API only. The artifact asset store is unreachable. Nothing in this repository was compiled or run by that session. |
| Implementing session, 2026-10-07 (cloud) | Ubuntu 24.04.5 LTS, x86_64, 4 cores, 15 GB. No Flutter preinstalled: Flutter **3.44.7** stable (framework `84fc5cbb22`, engine `69c8c61792`, Dart 3.12.2) installed from `storage.googleapis.com` into `~/sdk/flutter` and linked into `/usr/local/bin`; this is the pinned version (D-040). `pub.dev`, `storage.googleapis.com`, Maven Central and Google Maven are reachable; `dl.google.com` is blocked, so there is **no Android SDK**, no emulator and no device: the app cannot be built or launched for Android here, only analysed and tested (CI builds the APK). `flutter doctor`: Flutter OK; Android toolchain missing; Chrome missing; Linux toolchain lacks GTK. No macOS. Java 21 present. `git` 2.43 works; `gh` 2.89 is installed: `gh auth status` reports the token as invalid, but `gh api` calls work through the session proxy; the session's GitHub tools also work. The Dart MCP server failed to connect at session start (`dart` was not on the PATH); it is not waiting for approval. The SessionStart hook (D-048) puts `dart` on the PATH for later sessions. iOS could not be tried: no macOS, and iOS builds are deferred (D-042). |

## Risks being watched

- Permission conditions have not been read clause by clause; every permission-based
  record in the rights register is open until the owner reads it from the paper.
- Word boundaries differ between sources; the unified word index and mapping tables
  (B0.4) must exist before search, sync, tajweed and linguistic features.
- Zaydi-library text needs an approved honorific table and reviewed ayah linking.
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
  - `tools/gen/test/generator_test.dart` scans for Arabic without the U+0870–089F
    block (the code guard covers it); add it with the next generator change.
  - `motionFast`, `motionSlow` and `context.shadows` have no caller yet; they are the
    identity's scale and are used by the first widgets that animate or float.
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
| 2026-10-07 | Planning session | Checked the owner's extraction of seven Zaydi-library books (471, 473, 514, 737, 165, 276, 440): all complete; multi-part navigation confirmed; three more honorific codes found; linking prospects noted per book. | Pull request #5 |
| 2026-10-07 | First implementing session (continued) | M0.3: plan in `docs/plans/M0.3.md`; pack format v1; addresses, `PackText`, manifest verification, read-only SQLite reader, text repository, integrity suite and guards; D-061 to D-067; code review applied. | Pull request #4 |
| 2026-10-07 | First implementing session (continued) | M0.2: plan in `docs/plans/M0.2.md`; owner decided follow-system dark (D-050, D-053), the APK only by hand (D-049), the missing icons (D-051, D-052), tab label scaling (D-058); generator, themes, fonts, 13 widgets, gallery, 60 goldens via the CI `goldens` task, guards; code and identity reviews applied. | Pull request #3 |
| 2026-10-07 | First implementing session | Read the documents; installed Flutter 3.44.7; recorded the environment; owner answered K1–K4, O-15 (D-050) and the APK question (D-049); fetched the 13 logo files and verified the identity copy against the live artifacts; M0.1: strict lints, Arabic five-tab shell, single ARB, CI with Android build, setup hook, README; `code-reviewer` findings applied. | Pull request #2 |
| 2026-10-07 | Planning session | Updated the PRD to revision 129 (sources ready, decisions, Zaydi-library section, section order fixed, registry row 19, new open points). Added the project foundation: PRD export, architecture, plan, design-system mapping, sources, rights register, decisions, workflow, identity files with verified fonts and a preview script, agents, skills, MCP configuration, extraction tool. No application code. | Pull request #1 |
| 2026-10-06 | Owner's other account | `flutter create` skeleton committed. | `664e167` |
