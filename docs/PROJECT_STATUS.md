# Project status

Keep this file true. Update it with the work, in the same branch, every session
(`session-handoff` skill). If it disagrees with Git, Git is right and this file is
corrected first.

## Snapshot

| | |
| --- | --- |
| Updated | 2026-10-07 |
| Phase | 0 — Foundation. Gate 0 not met |
| Stream A — app | M0.1 merged with one human check pending (pull request #2). **M0.2 Design-system foundation** in progress (draft pull request #3) |
| Stream B — content | In progress, by the planning session and the owner |
| Working branch | `claude/great-hamilton-9n23mt`, restarted from `main` after pull request #2 (D-045) |
| Last session | First implementing session: environment, kickoff answers, M0.1 (pull request #2) |

## What is in the repository

- The Flutter app (package `holyquran`, Flutter 3.44.7 pinned, placeholder id
  `com.example.holyquran`, six platform folders of which only Android and iOS are
  built): an empty Arabic, right-to-left shell. `lib/ui/core/app.dart` (`QuranApp`),
  `lib/routing/` (go_router stateful shell with five branches and a label-only
  placeholder tab bar), five placeholder screens under `lib/ui/features/*/views/`,
  `lib/l10n/app_ar.arb` with its committed generated `AppLocalizations`. Nine widget
  tests. No design system, no domain or data code yet.
- Tooling: strict `analysis_options.yaml` (D-046); CI in `.github/workflows/ci.yml`
  (D-043); the cloud-session setup hook `.claude/hooks/session-start.sh` (D-048).
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
- **Zaydi Library**: category index of 39 books; book 183 extracted completely and
  checked; structure of book 466 inspected (fixed sub-headings, including النزول).
- **Project foundation**: this document set, agents, skills. Reviewed twice by an
  independent agent; its findings were applied before the merge.
- **M0.1 Repository and tooling** (pull request #2): environment recorded, Flutter
  pinned, kickoff answers applied (D-040 to D-045), strict lints, the Arabic
  five-tab shell, single ARB file, CI (Android build by hand, D-049), README, cloud
  setup hook. Logo files fetched from the identity artifact; the repository's copy of
  the identity verified byte-identical to the live artifacts. Pending: launch on an
  Android device (below).

## In progress

Stream A: M0.2, following `docs/plans/M0.2.md`, on `claude/great-hamilton-9n23mt`,
draft pull request #3. Done and pushed, CI green: step 0 (fonts and OFL texts in
`assets/`, dev packages, `ubuntu-24.04` as golden platform, a hand-started `goldens` task in CI); T1
generator and its three outputs (D-054); T2 `ReadingTheme` and `ThemePreference`;
T3a font loading in tests and font and import guards (type answers D-055); T3b
literal, feature-number, type-rule and contrast guards; T4 themes, `QuranApp`
theme wiring, motion constants, digit and ayah-count helpers. Next: T3c golden
harness (`testing/golden.dart`), then T5a and T5b widgets, T6 `TabBar`, T7 gallery,
then step 7 (run CI with the `goldens` task, reviews, documents, merge).

Stream B: extraction of seven Zaydi-library books is waiting for the owner to run the
tool (`docs/content/ZIYDIA_LIBRARY.md`).

## Next actions — stream A (the implementing account)

1. Read, in this order: `CLAUDE.md`, this file, `docs/WORKFLOW.md`, the whole of
   `docs/prd/PRD.ar.md` once, `docs/IMPLEMENTATION_PLAN.md`, `docs/ARCHITECTURE.md`,
   `docs/DESIGN_SYSTEM.md`, `docs/SOURCES.md`, `docs/DECISIONS.md`,
   `design/README.md`. Component sources and boards are read per task, not up front.
2. Check the environment (`flutter --version` should print 3.44.7; the SessionStart
   hook installs it in cloud sessions). If the machine differs from "Environment"
   below, record it.
3. Start **M0.2 Design-system foundation** (`docs/IMPLEMENTATION_PLAN.md`), opening
   its pull request early as a draft, since CI runs only on pull requests and `main`
   (D-043). In this order:
   1. Plan with `flutter-architect`.
   2. Token generator in `tools/gen/` (`content-engineer`), generated files, themes.
   3. Fonts to `assets/fonts/` with the hash test.
   4. The three type questions of `docs/DESIGN_SYSTEM.md`.
   5. Icons generated from `ICONS`.
   6. The M0.2 widgets (`ui-builder`). The identity's `TabBar` replaces the
      placeholder `NavigationBar` in `lib/routing/tab_shell.dart`; move the shell
      view under `lib/ui/` then, and update the tab finders in
      `test/routing/router_test.dart`.
   7. Gallery, goldens through a manually started CI workflow, contrast and guard
      tests.
4. The follow-system option is decided (D-050): `night` while the system is dark,
   the user's chosen theme otherwise. Compile the list of icons Phase 1 needs beyond
   the 26 and show it to the owner, then put O-13 (who draws them) to him (in "Waiting on the
   owner").
5. Then **M0.3** and **M0.4**, one at a time. Spikes S1, S5 and the playback part of
   S3 need nothing from stream B. If they are finished before Gate 0 is met, continue
   with **M0.5**, not with Phase 1.

## Next actions — stream B (planning session and the owner)

1. Owner: run the extraction for the seven pending books and upload the result
   (`docs/content/ZIYDIA_LIBRARY.md`). This is also the first test of multi-part
   navigation in the tool.
2. Owner: obtain the honorific glyph table from the site owner (O-07).
3. Owner: choose the Phase 1 recitations (O-04), decide on the general tafsirs
   (O-06), name the proofreader of the Hafs text (O-16) and decide who keeps the
   pack-signing key (O-03). All four are needed inside Phase 0.
4. Owner with the planning session: fill the rights register from the permission
   papers (B0.1, `docs/content/RIGHTS_REGISTER.md`).
5. Planning session: check completeness of each extracted book; build the ayah linker
   for book 183; prepare the reviewer's sample.
6. Planning session with the owner: the base pack (B0.2), KFGQPC assets (B0.3), the
   word index (B0.4), waqf-mark meanings (B0.8), acceptance data (B0.10), the pipeline
   (B0.11).
7. Planning session: review `docs/CONTENT_PACKS.md` when stream A opens its pull
   request for M0.3.

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
| O-07 | «نحتاج من صاحب المكتبة الزيدية جدول رموز خط الموقع: ما العبارة التي يرسمها كل من @ # ÷ ø $ ~ & والخط العمودي؟» | Before any Zaydi-library book is shown |
| O-02 | «أدنى إصدار ندعمه من Android وiOS؟ توصية الوثيقة: Android 8.0 وiOS 15.» | End of Phase 0 |
| O-17 | «في الوثيقة توصيتان لم تعتمدهما بعد ونراهما لازمتين للإصدار الأول: «أبلغ عن خطأ» من أي آية أو مادة، وإعداد أولي من ثلاث خطوات (وضع العرض، المستوى، التلاوة). هل تعتمدهما؟» | M1.1 |
| O-08 | «أين تُستضاف حزم المحتوى للتجربة ثم للإطلاق؟ يكفي أي استضافة ملفات ثابتة عبر HTTPS.» | M1.4 for a test host; end of Phase 1 for launch |
| O-14 | «تصنيف «تفسير» في العلامات ليس له شكل ولا لون في الهوية، ولا توجد لوحة ألوان للتصنيفات التي يضيفها المستخدم. ما الشكل واللون، وما الألوان المتاحة؟ وهل تبقى ألوان التصنيفات الأربعة ثابتة في كل السمات كما في الهوية؟» | M1.6 |
| O-11 | «هل لديك حساب مطوّر في Google Play وفي App Store؟ ومن يحتفظ بمفتاح توقيع التطبيق؟» | M1.11 |
| O-18 | «هل نضيف تقارير أعطال وتشخيصًا مجهول الهوية بموافقة المستخدم، وعبر أي خدمة؟ بدونها لا يُقاس معدل الأعطال.» | M1.11 |
| O-12 | «في الهوية مواضع تباينها دون 4.5 إلى 1: التسمية الذهبية في بطاقة «أكمل القراءة ووُجد في المعلم M0.2 أيضًا: مسار المفتاح (Switch) وهو مطفأ تباينه بين ١٫٣ و١٫٥ إلى ١، والحد المطلوب لحدود عناصر التحكم ٣ إلى ١.» وسطر المرجع في بطاقة المشاركة الزمردية (3.9 إلى 1)، ورقم الآية داخل الفاصلة الممتلئة في سمة السيبيا (3.1 إلى 1)، وأربع قيم من ألوان التجويد (بين 3.9 و4.4 إلى 1). هل نقبلها كما هي، أم يعدّل المصمم قيمها؟» | M1.2 for the card; M1.10 for the marker; before Phase 2 for tajweed |
| O-09 | «أي خدمة خادم نعتمد للحسابات والمزامنة في المرحلة 2؟» | Phase 2 |

Permission conditions to confirm with him when each is first needed are listed in
`docs/SOURCES.md` and recorded in `docs/content/RIGHTS_REGISTER.md`.

## Pending human checks

| Milestone | Check | Who | How |
| --- | --- | --- | --- |
| M0.1 | The shell launches on Android: the app opens in Arabic, right to left, on الرئيسية, and the five tabs switch | Owner, or a session with an Android SDK and emulator | Owner's choice (D-049): once, at the end of Phase 0 or when he wants to try it, start the CI workflow by hand (Actions → CI → Run workflow) and install the `holyquran-debug-apk` it attaches; or `flutter run` on a device. No session so far has had an Android SDK |

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
- The identity has no icon for several Phase 1 actions (O-13).
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
| 2026-10-07 | First implementing session | Read the documents; installed Flutter 3.44.7; recorded the environment; owner answered K1–K4, O-15 (D-050) and the APK question (D-049); fetched the 13 logo files and verified the identity copy against the live artifacts; M0.1: strict lints, Arabic five-tab shell, single ARB, CI with Android build, setup hook, README; `code-reviewer` findings applied. | Pull request #2 |
| 2026-10-07 | Planning session | Updated the PRD to revision 129 (sources ready, decisions, Zaydi-library section, section order fixed, registry row 19, new open points). Added the project foundation: PRD export, architecture, plan, design-system mapping, sources, rights register, decisions, workflow, identity files with verified fonts and a preview script, agents, skills, MCP configuration, extraction tool. No application code. | Pull request #1 |
| 2026-10-06 | Owner's other account | `flutter create` skeleton committed. | `664e167` |
