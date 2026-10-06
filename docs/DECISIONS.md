# Decisions

One line of record per decision, newest at the bottom of each section. A decision is
changed by adding a new entry that supersedes the old one, never by editing history.
Product decisions belong to the owner and are mirrored from PRD §14.3.

Engineering decisions marked *Proposed* were set during planning, before any code
ran. Each names the milestone or spike that tests it. When that work is done, the
lead adds a new line with the next free number: the same subject, status *Decided*,
the evidence (pull request or spike page), and "supersedes D-0xx". If the evidence
goes against the proposal, the new line records what replaced it.

## Product decisions (owner)

| ID | Date | Decision | Why / note |
| --- | --- | --- | --- |
| D-001 | 2026-10-06 | The app is non-profit: free, no ads, no subscriptions, no purchases. | Owner. Also satisfies the non-commercial terms of some sources; any future revenue feature forces a licence re-check. |
| D-002 | Brief | Arabic-only interface, right to left. No translations of the Quran. | Brief. |
| D-003 | Brief | The reference (address, page, juz, hizb) is separate from how the text is displayed. Two display modes: surah (default) and page. | Brief and PRD §7.2. |
| D-004 | 2026-10-06 | Reference edition for page numbers: Madinah mushaf, KFGQPC 1421H, 604 pages. | Fonts and line layout are both available for it. |
| D-005 | 2026-10-06 | Two Hafs scripts in surah mode: Tanzil text with Amiri Quran (default) and KFGQPC text with its own font. | Owner. Tajweed and timing data are built on the Tanzil text and mapped word by word to the KFGQPC text. |
| D-006 | 2026-10-06 | Three UI levels (بسيط، متوسط، دراسة). The five tabs and the home doors are the same at every level. | Approved screens board. |
| D-007 | 2026-10-06 | Public launch after Phase 1, in the Arab market. | Owner. Home shows two doors until Phase 2 ships khatma and memorisation. |
| D-008 | 2026-10-06 | Screens the identity does not draw are built directly in Flutter, following the identity. No separate design phase. | Owner. Identity conformance is an acceptance item for every new screen. |
| D-009 | 2026-10-06 | Tafsir and reference books come from the Zaydi Library (ziydia.com). Asbab al-nuzul come from its books, subject to the reviewers. | Owner. |
| D-010 | 2026-10-06 | Audio is hosted on the owner's server once the app is complete. | Owner. |
| D-011 | 2026-10-06 | Reviewers are available on the owner's side: a certified reciter, a religious reviewer and a linguist. | Owner. |
| D-012 | 2026-10-07 | Every source that needed permission is treated as ready. | Owner's statement: he holds written, signed permissions from KFGQPC, the rights holders of the recitations to be used, the Quranic Arabic Corpus, MASAQ, and the remaining sources discussed, including the five contemporary Zaydi-library books. The papers stay with him. When a specific condition affects how something is built, stored, modified or attributed, name the source and the condition and ask him. |
| D-013 | 2026-10-06 | Zaydi-library text is extracted from the website by a tool the owner runs. Eight books are candidates for the first release, including «التيسير في التفسير», which the owner added. | The site owner declined to hand over the database and permitted extraction. See `docs/content/ZIYDIA_LIBRARY.md`. |
| D-014 | 2026-10-07 | The app is implemented from the owner's other account, on this repository. The planning session keeps the PRD and the content work, and writes no application code. | Owner. |
| D-015 | 2026-10-07 | Every step and phase is recorded in Git and GitHub and in `docs/PROJECT_STATUS.md`. Repository documents are Markdown in English. Commit messages and descriptions are in English. Code comments are kept few. | Owner. So that work continues from the same point after switching accounts. |
| D-016 | 2026-10-07 | Work is done by a lead that delegates to specialised agents, using skills, the official Flutter ones first. | Owner. See `docs/WORKFLOW.md`. |
| D-017 | 2026-10-07 | Questions to the owner go through the `AskUserQuestion` tool, in Arabic, with a recommendation. | Owner. |
| D-018 | Brief | Out of scope by the owner's brief: translations, a separate UI for the elderly, teacher tools, a standalone roots screen, reciter comparison, bookmarks on part of an ayah. Deferred: recitation recording and automatic correction, AI detection of pronunciation errors, an AI assistant, spaced repetition, advanced quizzes and games. | PRD §2.5, §13.1. |
| D-019 | 2026-10-07 | Books that exist only as scanned PDF are left out. No text recognition is run on religious text. | PRD §5.5. Recognition would introduce errors into the text; the rule of no generated content applies. Seven Zaydi-library books are affected. |

## Engineering decisions

| ID | Date | Status | Decision | Why, and what confirms it |
| --- | --- | --- | --- | --- |
| D-020 | 2026-10-07 | Proposed | Layered architecture from the Flutter architecture guide: MVVM in the UI layer, repositories and services in the data layer, use cases only where justified. | Official recommendation; matches the vendored official skill. Confirmed by M0.3. |
| D-021 | 2026-10-07 | Proposed | View models are `ChangeNotifier`s exposing commands; fallible calls return `Result`; dependencies are provided with `provider`. | Same guide. Small, explicit, no code generation. Confirmed by M0.3; revisit only with a concrete problem. |
| D-022 | 2026-10-07 | Proposed | `go_router` with a stateful shell of five branches. | Flutter recommendation; each tab keeps its stack; addresses map to routes. Confirmed by M0.1. |
| D-023 | 2026-10-07 | Proposed | SQLite everywhere: one read-only database per content pack, one read/write user database (`drift`). | PRD §10.8. Keeps Quran text physically separate from user data. Confirmed by M0.3. |
| D-024 | 2026-10-07 | Open | Pack manifests are signed (Ed25519 proposed) and verified with a public key in the app. Who holds the private key and where signing runs is undecided. | PRD §9.2. Needs the owner (O-03). |
| D-025 | 2026-10-07 | Proposed | Design tokens and icons are generated from `design/design-system/` (`tokens.json`, the `ICONS` map) by generators in `tools/gen/`, never typed by hand. Generated files are committed and checked in CI. | Removes transcription errors and keeps the identity exact. Confirmed by M0.2. |
| D-026 | 2026-10-07 | Decided | App fonts are the official TTF builds pinned in `design/design-system/fonts/ttf/` (Amiri Quran 1.003, Reem Kufi 2.000, IBM Plex Sans Arabic 1.101). | Verified identical to the identity's fonts. Text and font are one pair. |
| D-027 | 2026-10-07 | Decided | The official Dart and Flutter skills are vendored unmodified into `.claude/skills/`; the Dart and Flutter MCP server is configured in `.mcp.json`. The `dart-flutter` plugin is not installed on top. | Same tools for every account and machine without per-account setup. |
| D-028 | 2026-10-07 | Proposed | Build targets are Android and iOS only. The `web`, `linux`, `macos` and `windows` folders created by `flutter create` are removed in Phase 0. | PRD scope. Ask the owner first (O-05): he may want `windows` kept for local preview. |
| D-029 | 2026-10-07 | Proposed | GitHub Actions runs format check, `flutter analyze` and `flutter test` on every push and every pull request. | A build machine every account can rely on, including sessions with no Flutter SDK. Needs the owner's yes (kickoff question K4). |
| D-030 | 2026-10-07 | Decided | Raw extraction output and unverified content never enter Git. The base pack enters under `assets/` only as a signed, verified file; other packs are hosted. | Content becomes part of the product only as a verified, signed pack. |
| D-031 | 2026-10-07 | Decided | Quran text is never typed or pasted into code, tests, fixtures, documentation or commit messages. Tests read it from the pack. | PRD §9.1. The PRD export and the design files carry a few sample words and ayat as illustration; they are never used as data or copied from. |
| D-032 | 2026-10-07 | Decided | For a component, the identity's reference implementation (`index.jsx`, `bundle.css`) is normative, including its metrics outside the token scales. Colours always come from tokens. Metrics that are not tokens are named constants with their source: in the widget for a component or a board element, in `lib/ui/core/metrics/` for the layout of a drawn screen. Feature code holds no design numbers. Brand surfaces (share cards, splash, app-icon tile) keep fixed colours in every theme. | The components and about half of the board layouts use values off the scales; "tokens only" and "reproduce exactly" cannot both hold otherwise. `docs/DESIGN_SYSTEM.md`. |
| D-033 | 2026-10-07 | Decided | What the user sees when data is missing: fields, rows and sections without data are hidden; three cases show a fixed UI sentence instead (a tafsir with no passage for the ayah, the identity's empty and error states, the download offer of `ST-03`). | Reconciles `LX-11` with the acceptance criteria of `TF` and the identity. `docs/DESIGN_SYSTEM.md`. |
| D-034 | 2026-10-07 | Decided | Clearance has three levels: the source registry (`docs/SOURCES.md`), a rights record per book, recitation and data set (`docs/content/RIGHTS_REGISTER.md`), and the manifest of each built pack. | "Ready" for a source does not by itself clear one book or one recording. |
| D-035 | 2026-10-07 | Proposed | The pack format is specified by stream A in `docs/CONTENT_PACKS.md` (M0.3). The pipeline belongs to stream B, in `tools/packs/`, in Python 3 with the standard library; signing is a separate step. | The reader defines what it can read; the owner already runs Python tools on his computer. Confirmed by M0.3 and B0.11. |
| D-036 | 2026-10-07 | Proposed | Pack strings travel through the app as an opaque `PackText`; only the listed sinks read the raw value; a test enforces it. This is the "no normalisation on text fields" check of PRD §9.4. | A text search of the code cannot prove the property. Decided in M0.3. |
| D-037 | 2026-10-07 | Proposed | Display text is never folded. Search matches source-provided search forms stored in the pack; only the query, and at most a rebuildable app-side index built from those forms, pass through one fold function. | `SR-03`, PRD §9.6. Whether the index is needed is decided in M1.8 against the golden query set. |
| D-038 | 2026-10-07 | Proposed | In the word index a token made only of marks is not a word; it stays attached to the word before it. | In the Tanzil text a pause mark stands as a token of its own. To be verified and fixed in B0.4 against the timing data. |
| D-039 | 2026-10-07 | Decided | Nothing is committed to `main` directly. The last commit of a milestone branch carries the status file as it should read after the merge. A milestone may merge with named human checks pending; a phase gate may not. | Keeps `main` correct at every merge without a follow-up commit; keeps reviewer and device checks visible. `docs/WORKFLOW.md`. |

## Open decisions

Tracked with their owner-facing wording in `docs/PROJECT_STATUS.md`.

| ID | Needed by | Question |
| --- | --- | --- |
| O-01 | M0.1; at the latest before the first store build | Application id (Android) and bundle id (iOS), and the publisher name. The repo currently has the placeholder `com.example.holyquran`. An id cannot be changed after publishing. |
| O-02 | End of Phase 0 | Minimum OS versions. PRD recommends Android 8.0 and iOS 15. |
| O-03 | Phase 0: B0.11 and the base pack of B0.2, before M1.2 | Custody of the pack-signing key (D-024). |
| O-04 | Phase 0, task B0.5 | Recitations for Phase 1 (PRD suggests at least five, two with word timing), the source of their files, and what each permission allows for hosting and offline download. |
| O-05 | M0.1 | Keep or remove the non-mobile platform folders (D-028). |
| O-06 | Phase 0, task B0.7 | Whether the seven general tafsirs of PRD §8.8 stay next to the Zaydi-library books. |
| O-07 | Before any Zaydi-library book is shown | The honorific glyph table of the site's font, from the site owner. |
| O-08 | M1.4 for a test host; end of Phase 1 for launch | Where content packs are hosted (HTTPS static hosting is enough). |
| O-09 | Phase 2 | Backend service for accounts and sync. |
| O-10 | M0.1 | How iOS builds are made: the owner's Mac, a macOS CI runner, or deferred. |
| O-11 | M1.11 | Developer accounts on the two stores, and who holds the app-signing keys. |
| O-12 | M1.2 for the card label; M1.10 for the marker; before Phase 2 for tajweed | Places in the identity that fall below the 4.5:1 of `AX-03`: the gold label of the continue-reading card and the gold reference line of the emerald share card (3.9:1); the ayah number inside the filled marker in sepia (3.1:1); four values of three tajweed colours (3.85 to 4.43:1, above the 3:1 that WCAG AA asks of large text). Accept them as they are, or have the designer change the values. |
| O-13 | M0.2 for the list; M1.6 for first use | Icons Phase 1 needs that the identity's 26 do not include: who draws them. |
| O-14 | M1.6 | Shape and colour of the category «تفسير»; whether the four built-in category colours stay fixed in every theme, as the preview draws them; and the palette offered for user-made categories. |
| O-15 | M0.2 | Which themes the "follow system dark" option switches between. |
| O-16 | Gate 0 | Who proofreads the Hafs text (PRD §9.3 asks for a proficient hafiz). D-011 names a certified reciter, a religious reviewer and a linguist; say whether the reciter takes this role or a fourth person does. |
| O-17 | M1.1 | PRD §15 recommendations 3 and 4, which the study calls necessary for the first release and the owner has not yet approved: "report an error" from any ayah or item, and a three-step onboarding (display mode, level, recitation). |
| O-18 | M1.11 | Whether the app has crash reporting and anonymous diagnostics with the user's consent (`NF-07`, `NF-21`, PRD §9.5), and through which service. |
