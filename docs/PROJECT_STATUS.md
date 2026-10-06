# Project status

Keep this file true. Update it with the work, in the same branch, every session
(`session-handoff` skill). If it disagrees with Git, Git is right and this file is
corrected first.

## Snapshot

| | |
| --- | --- |
| Updated | 2026-10-07 |
| Phase | 0 — Foundation. Gate 0 not met |
| Stream A — app | Not started. Next milestone: **M0.1 Repository and tooling** |
| Stream B — content | In progress, by the planning session and the owner |
| Working branch | None open. Start `feat/m0-1-tooling` from `main` |
| Last session | Planning session: project foundation, merged by pull request #1 |

## What is in the repository

- The untouched output of `flutter create` (commit `664e167`): the counter demo,
  package `holyquran`, Dart SDK `^3.12.2`, placeholder id `com.example.holyquran`,
  six platform folders. **No application code has been written.**
- `docs/` — PRD export, plan, architecture, design-system mapping, sources, rights
  register, decisions, workflow, Zaydi-library notes, the prompts for starting a
  session.
- `design/` — the approved identity: design system (tokens, 31 components, fonts in
  WOFF2 and pinned TTF), the ten identity boards, and a script that builds offline
  previews of both.
- `.claude/` — eight agents, five project skills, twenty vendored official Flutter
  and Dart skills. `.mcp.json` — the Dart and Flutter MCP server.
- `tools/ziydia/` — the extraction tool for the Zaydi Library.

Not in the repository: any content pack; any Quran text as data (the PRD and the
design files show a few sample words and ayat as illustration, never to be copied);
raw extraction output; the 13 logo SVG files; a CI workflow; signing keys.

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

## In progress

Nothing in stream A.

Stream B: extraction of seven Zaydi-library books is waiting for the owner to run the
tool (`docs/content/ZIYDIA_LIBRARY.md`).

## Next actions — stream A (the implementing account)

1. Read, in this order: `CLAUDE.md`, this file, `docs/WORKFLOW.md`, the whole of
   `docs/prd/PRD.ar.md` once, `docs/IMPLEMENTATION_PLAN.md`, `docs/ARCHITECTURE.md`,
   `docs/DESIGN_SYSTEM.md`, `docs/SOURCES.md`, `docs/DECISIONS.md`,
   `design/README.md`. Component sources and boards are read per task, not up front.
2. Record the environment in "Environment" below (the list is in M0.1).
3. Put the kickoff questions K1–K4 below to the owner in one `AskUserQuestion` call.
4. Start **M0.1** on `feat/m0-1-tooling` (`docs/IMPLEMENTATION_PLAN.md`).
5. Then **M0.2**, **M0.3**, **M0.4**, one at a time. Spikes S1, S5 and the playback
   part of S3 need nothing from stream B. If they are finished before Gate 0 is met,
   continue with **M0.5**, not with Phase 1.
6. If the Artifact tool is available in your session, fetch the 13 logo files as
   `design/README.md` describes. If not, ask the owner to export them. They are
   needed by M1.11, not before.

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

Kickoff questions for the implementing session to ask first:

| ID | Question, as it should be put to him | Recommendation | Needed by |
| --- | --- | --- | --- |
| K1 (O-01) | «معرّف التطبيق في المتجرين (مثل com.اسمك.quran) واسم الناشر الذي سيظهر للمستخدمين. المعرّف لا يمكن تغييره بعد النشر، والمستودع فيه الآن معرّف مؤقت com.example.holyquran.» | Decide now; if he has no name yet, keep the placeholder and change it before the first store upload | M0.1 |
| K2 (O-05) | «مشروع Flutter أُنشئ بست منصات. النطاق المعتمد Android وiOS فقط. هل أحذف مجلدات web وlinux وmacos وwindows؟» | Remove all four. Keep `windows` only if he wants to preview the app on his Windows PC without an emulator | M0.1 |
| K3 (O-10) | «بناء نسخة iOS يحتاج جهاز Mac. هل لديك Mac، أم نعتمد على GitHub Actions لبناء iOS، أم نؤجل تجربة iOS إلى قرب نهاية المرحلة 1؟» | Develop and test on Android now; run an iOS build on a macOS CI runner at the end of each milestone, so problems surface early. macOS runners use up the free minutes much faster than Linux ones, so not on every push | M0.1 |
| K4 (D-029) | «هل أفعّل GitHub Actions ليفحص كل تغيير آليًا (التنسيق والتحليل والاختبارات)؟ في المستودعات الخاصة له حصة دقائق مجانية شهرية.» | Yes | M0.1 |

Open decisions that come later (full list in `docs/DECISIONS.md`):

| ID | Question, as it should be put to him | Needed by |
| --- | --- | --- |
| O-04 | «ما التلاوات التي تريدها في الإصدار الأول (خمس على الأقل، اثنتان منها بتوقيت كلمات)، ومن أين نأخذ ملفاتها، وهل يجيز إذن كل منها التنزيل دون اتصال والاستضافة على خادمك؟» | Phase 0 (B0.5) |
| O-06 | «هل تبقى التفاسير السبعة العامة (الميسر، المختصر، السعدي، الجلالين، البغوي، ابن كثير، الطبري) بجانب كتب المكتبة الزيدية؟» | Phase 0 (B0.7) |
| O-03 | «حزم المحتوى تُوقَّع بمفتاح خاص. من يحتفظ بالمفتاح، وأين يجري التوقيع؟» | Phase 0 (B0.11, and the base pack before M1.2) |
| O-16 | «من يدقّق نص حفص قبل اعتماده؟ الوثيقة تطلب حافظًا متقنًا. هل يتولاه القارئ المُجاز الذي ذكرتَه أم شخص آخر؟» | Gate 0 |
| O-07 | «نحتاج من صاحب المكتبة الزيدية جدول رموز خط الموقع: ما العبارة التي يرسمها كل من @ # ÷ ø $ ~ & والخط العمودي؟» | Before any Zaydi-library book is shown |
| O-13 | «الهوية فيها 26 أيقونة، وتنقصها أيقونات تحتاجها المرحلة 1 مثل النسخ والمشاركة والملاحظة والحذف. من يرسمها: المصمم، أم أرسمها على قواعد أيقونات الهوية وأعرضها عليك قبل اعتمادها؟» | M0.2 for the full list; M1.6 for first use |
| O-02 | «أدنى إصدار ندعمه من Android وiOS؟ توصية الوثيقة: Android 8.0 وiOS 15.» | End of Phase 0 |
| O-15 | «خيار «اتبع وضع النظام الداكن»: هل يبدّل بين سمة الليل والسمة الفاتحة التي اختارها المستخدم؟» | M0.2 |
| O-17 | «في الوثيقة توصيتان لم تعتمدهما بعد ونراهما لازمتين للإصدار الأول: «أبلغ عن خطأ» من أي آية أو مادة، وإعداد أولي من ثلاث خطوات (وضع العرض، المستوى، التلاوة). هل تعتمدهما؟» | M1.1 |
| O-08 | «أين تُستضاف حزم المحتوى للتجربة ثم للإطلاق؟ يكفي أي استضافة ملفات ثابتة عبر HTTPS.» | M1.4 for a test host; end of Phase 1 for launch |
| O-14 | «تصنيف «تفسير» في العلامات ليس له شكل ولا لون في الهوية، ولا توجد لوحة ألوان للتصنيفات التي يضيفها المستخدم. ما الشكل واللون، وما الألوان المتاحة؟ وهل تبقى ألوان التصنيفات الأربعة ثابتة في كل السمات كما في الهوية؟» | M1.6 |
| O-11 | «هل لديك حساب مطوّر في Google Play وفي App Store؟ ومن يحتفظ بمفتاح توقيع التطبيق؟» | M1.11 |
| O-18 | «هل نضيف تقارير أعطال وتشخيصًا مجهول الهوية بموافقة المستخدم، وعبر أي خدمة؟ بدونها لا يُقاس معدل الأعطال.» | M1.11 |
| O-12 | «في الهوية مواضع تباينها دون 4.5 إلى 1: التسمية الذهبية في بطاقة «أكمل القراءة» وسطر المرجع في بطاقة المشاركة الزمردية (3.9 إلى 1)، ورقم الآية داخل الفاصلة الممتلئة في سمة السيبيا (3.1 إلى 1)، وأربع قيم من ألوان التجويد (بين 3.9 و4.4 إلى 1). هل نقبلها كما هي، أم يعدّل المصمم قيمها؟» | M1.2 for the card; M1.10 for the marker; before Phase 2 for tajweed |
| O-09 | «أي خدمة خادم نعتمد للحسابات والمزامنة في المرحلة 2؟» | Phase 2 |

Permission conditions to confirm with him when each is first needed are listed in
`docs/SOURCES.md` and recorded in `docs/content/RIGHTS_REGISTER.md`.

## Pending human checks

None yet. Acceptance criteria that wait for a device, a reviewer or the owner are
listed here when a milestone merges with them open.

## Environment

| Where | State |
| --- | --- |
| Planning session (cloud) | No Flutter SDK. Network policy blocks `pub.dev`, `storage.googleapis.com`, `dl.google.com` and Maven, so Flutter cannot be installed or run there. Public GitHub repositories are readable with `git`. `gh` works through the REST API only. The artifact asset store is unreachable. Nothing in this repository was compiled or run by that session. |
| Implementing session | **To be recorded by the first implementing session.** |

## Risks being watched

- Permission conditions have not been read clause by clause; every permission-based
  record in the rights register is open until the owner reads it from the paper.
- Word boundaries differ between sources; the unified word index and mapping tables
  (B0.4) must exist before search, sync, tajweed and linguistic features.
- Zaydi-library text needs an approved honorific table and reviewed ayah linking.
- Rendering fidelity of the Quran fonts in Flutter is unproven until spikes S1 and S2.
- The identity has no icon for several Phase 1 actions (O-13).
- iOS cannot be built without macOS, and Gate 0 asks for measurements on both
  systems (`docs/IMPLEMENTATION_PLAN.md`, "Gate 0 and iOS").
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
| 2026-10-07 | Planning session | Updated the PRD to revision 129 (sources ready, decisions, Zaydi-library section, section order fixed, registry row 19, new open points). Added the project foundation: PRD export, architecture, plan, design-system mapping, sources, rights register, decisions, workflow, identity files with verified fonts and a preview script, agents, skills, MCP configuration, extraction tool. No application code. | Pull request #1 |
| 2026-10-06 | Owner's other account | `flutter create` skeleton committed. | `664e167` |
