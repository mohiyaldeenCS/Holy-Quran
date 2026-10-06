# القرآن الكريم — Holy Quran app

An Arabic-only, right-to-left Flutter app for reading, listening to, studying and
memorising the Quran, for Android and iOS. It is a non-profit service to the
community: free, no ads, no purchases, no tracking. The owner is the client and
product authority; he writes Arabic.

## Start of every session

1. Read `docs/PROJECT_STATUS.md`. It says where the work stands and what is next.
   The owner switches between accounts, so nothing is remembered except what is in
   this repository. Use the `session-handoff` skill.
2. Read the current milestone in `docs/IMPLEMENTATION_PLAN.md` and the PRD sections
   it cites.
3. Run `flutter --version`. If Flutter is unavailable, tell the owner before doing
   anything else and do not write application code you cannot analyse and test.

## Documents

| File | What it decides |
| --- | --- |
| `docs/prd/PRD.ar.md` | **Scope.** Requirements with IDs (`RD-02`), acceptance criteria, phases, deferred features. Arabic. The source of truth: do not add, drop or reinterpret features. |
| `docs/PROJECT_STATUS.md` | Current state, next actions, open questions, session log |
| `docs/IMPLEMENTATION_PLAN.md` | Milestones, what each needs, definition of done |
| `docs/ARCHITECTURE.md` | Layers, folders, packs, data, budgets, testing |
| `design/` + `docs/DESIGN_SYSTEM.md` | **Looks.** The approved visual identity and how it maps to Flutter |
| `docs/SOURCES.md` + `docs/content/RIGHTS_REGISTER.md` | Which content may be used, and under what conditions |
| `docs/DECISIONS.md` | Decisions and open decisions |
| `docs/WORKFLOW.md` | Agents and the files each owns, Git protocol, language, code style |

The PRD decides scope, `design/` decides looks. If documents disagree on something
the owner cares about, ask him; on an engineering matter, decide, fix the weaker
document and record it (`docs/WORKFLOW.md`, "Which document decides").

## Rules that are never traded away

**Quran text.** It is verified, read-only data in a content pack, fetched by address
(`hafs:2:255`) and shown unchanged. Never type, paste, edit, trim, normalise,
re-encode, split or reassemble Quran text, in code, tests, fixtures, documents or
commit messages. Tests read it from the pack or use obviously synthetic text. A text
and its font are one pair. A failed hash or count means stop and report, never
adjust. Use the `quran-text-integrity` skill for anything that touches text.

**No generated content.** No tafsir, meaning, i'rab, summary, translation, surah
introduction or any religious or linguistic text is written or completed by a model
or by you. Content comes from a source marked `Ready` in `docs/SOURCES.md` and is
shown with its source. A field with no data is hidden; the few fixed sentences shown
instead are listed in `docs/DESIGN_SYSTEM.md`. Sample text inside `design/` and the
PRD is illustration, never content. A feature whose source is not ready is not built.

**The identity is closed.** `design/` is approved. Reproduce it; do not redesign,
restyle or "improve" it. Colours come from the generated tokens. A component is
copied from its reference implementation, including values outside the token scales;
such values are named constants that cite their source, never inline numbers in
feature code. Screens the identity does not draw are assembled from its existing
tokens and components. What it lacks, such as an icon, is asked of the owner. Use the
`apply-visual-identity` skill for all UI.

**Scope is the PRD's.** Build what the current phase lists, when its gate allows
(`docs/IMPLEMENTATION_PLAN.md`). Deferred and excluded features stay out (PRD §2.5,
§13). Ideas go to the status file as ideas.

**Non-profit and private.** No ad or purchase SDK. No analytics or crash reporting
without the user's consent and a recorded decision. Reading history and notes are
sensitive: local by default, never sent to third parties.

## How work is done

- You are the **lead**: plan, delegate to the agents in `.claude/agents/`, integrate,
  verify, commit, report. One agent per kind of work: `flutter-architect`,
  `data-builder`, `ui-builder`, `audio-builder`, `content-engineer`, `test-engineer`,
  `code-reviewer`, `identity-auditor`. `docs/WORKFLOW.md` says which files each may
  edit and which are yours alone.
- Use skills. Project skills: `session-handoff`, `implement-requirement`,
  `apply-visual-identity`, `quran-text-integrity`, `ask-owner`. The official Flutter
  and Dart skills are vendored in `.claude/skills/<name>/SKILL.md`; where a generic
  skill disagrees with this repository's documents, the documents win.
- The Dart and Flutter MCP server is configured in `.mcp.json`; use its tools when
  they are connected.
- Architecture: the Flutter team's layered MVVM. View → view model → (use case) →
  repository → service. `lib/domain` is pure Dart. Only services touch plugins.
- Every change comes with tests. Before every commit:
  `dart format .`, `flutter analyze`, `flutter test`. Never weaken or skip a test to
  pass. Golden tests are the one exception to "run everything": they belong to one
  platform, and elsewhere they are excluded by tag (`docs/DESIGN_SYSTEM.md`, "Type").
- State partial work as partial. Never mark a requirement done with a criterion
  unmet, and never claim a check passed that you did not run. A criterion that needs
  a device, a reviewer or the owner is listed as a pending human check.

## Git and records

- English: code, comments, commit messages, pull requests and the prose of every
  document. Arabic only where it is the subject: the PRD, `design/`, UI strings in
  `lib/l10n/app_ar.arb`, quoted terms and titles, and the wording of questions for
  the owner.
- Conventional Commits naming the requirement ID, or the milestone where there is
  none: `feat(reader): show page-boundary marks in surah mode (RD-06)`.
- Branch per milestone; commit per task; push after every commit and always before
  stopping; one pull request per milestone; merge with a merge commit; tag phase
  gates. Never commit to `main` directly, force-push it, or commit secrets, signing
  keys, raw extraction output, downloaded source files or build artefacts.
- Update `docs/PROJECT_STATUS.md` with the work, every session, in the branch. A
  session that stops without updating and pushing it has not finished.
- A new package, data shape or deviation gets an entry in `docs/DECISIONS.md`.

## Code style

- Few comments. Explain why, not what. No commented-out code, no banners, no
  restating the code.
- Small files, one responsibility, clear names. No speculative options or
  abstractions. No dead code.
- No hard-coded UI strings, literal colours or font names anywhere; no inline design
  numbers in feature code.
- Generated files (`*.g.dart`) are committed and never edited by hand.
- Arabic-Indic digits in the UI through the shared helper.

## Talking to the owner

- Reply in Arabic. Lead with the result; say plainly what failed or is unverified.
- Decisions that are his (scope, content, sources and permission conditions,
  identity gaps, identifiers, accounts, anything irreversible) go to him through
  `AskUserQuestion`, in Arabic, recommended option first and marked «(موصى به)».
  Use the `ask-owner` skill. Engineering choices with a conventional answer you
  decide and record.
