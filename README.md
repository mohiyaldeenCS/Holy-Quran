# القرآن الكريم — Holy Quran

An Arabic app for reading, listening to, studying and memorising the Quran, built
with Flutter for Android and iOS. It is a non-profit service to the community: free,
with no ads and no purchases.

**Status:** Phase 0 (foundation). The repository holds the project documents, the
approved visual identity and an untouched `flutter create` skeleton. Application code
has not been started. See [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md).

## Where things are

| Path | Content |
| --- | --- |
| [`docs/prd/PRD.ar.md`](docs/prd/PRD.ar.md) | Product requirements (Arabic). The source of truth for scope. |
| [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) | Where the work stands, next actions, open questions |
| [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) | Phases, milestones, definition of done |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, content packs, data, budgets, testing |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | The visual identity in Flutter |
| [`docs/SOURCES.md`](docs/SOURCES.md) | Content sources, their status and conditions |
| [`docs/content/RIGHTS_REGISTER.md`](docs/content/RIGHTS_REGISTER.md) | What each licence or permission allows, per source, book and recitation |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Decisions taken and open |
| [`docs/WORKFLOW.md`](docs/WORKFLOW.md) | Agents, Git protocol, code style |
| [`docs/content/`](docs/content/) | Notes on content preparation |
| [`docs/KICKOFF_PROMPT.md`](docs/KICKOFF_PROMPT.md) | The messages that start and resume a working session |
| [`design/`](design/) | The approved identity: design system and boards, with a script that builds offline previews |
| [`tools/`](tools/) | Tools: extraction now; generators and the pack pipeline later |
| [`.claude/`](.claude/) | Agents and skills for Claude Code |
| `lib/`, `android/`, `ios/`, … | The Flutter project |

## Principles

- The Quran text is verified, read-only data. It is never typed, edited or normalised
  anywhere in this repository.
- No religious or linguistic content is generated. Every piece of content has a
  recorded source and is shown with it.
- The visual identity is fixed and applied as designed.
- The PRD decides what is built and when.
- The app is non-profit: no ads, no purchases, no tracking.

## Working on it

The project is developed with Claude Code. Open the repository, and the session reads
[`CLAUDE.md`](CLAUDE.md). To start or resume work, use the prompt in
[`docs/KICKOFF_PROMPT.md`](docs/KICKOFF_PROMPT.md).

With Flutter installed:

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

To look at the identity (Python 3, nothing to install):

```bash
python3 design/preview/build.py
# then open design/preview/out/index.html
```

## Credits

Content and data come from the sources listed in [`docs/SOURCES.md`](docs/SOURCES.md),
each under its own licence or permission. Fonts: Amiri Quran, Reem Kufi and IBM Plex
Sans Arabic, under the SIL Open Font License 1.1.
