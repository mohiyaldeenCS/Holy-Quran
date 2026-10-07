# القرآن الكريم — Holy Quran

An Arabic app for reading, listening to, studying and memorising the Quran, built
with Flutter for Android and iOS. It is a non-profit service to the community: free,
with no ads and no purchases.

**Status:** Phase 0 (foundation). The app is an empty shell: Arabic, right to left,
five tabs with placeholder screens. See [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md).

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

### Toolchain

Flutter **3.44.7** stable (Dart 3.12.2), the version pinned in `docs/DECISIONS.md`
(D-040) and used by CI. In Claude Code cloud sessions,
`.claude/hooks/session-start.sh` installs it automatically.

### Run, check, test

```bash
flutter pub get                                      # also generates lib/l10n/app_localizations*.dart
flutter run                                          # on an Android device or emulator
dart format --output=none --set-exit-if-changed .    # format check, as in CI
flutter analyze
flutter test test tools/gen/test                     # app and generator tests
flutter test --exclude-tags golden test tools/gen/test   # off the golden platform
flutter build apk --debug
```

Before every commit run `dart format .`, `flutter analyze` and `flutter test`. CI
(`.github/workflows/ci.yml`) runs the same checks, verifies that generated files are
up to date, on every pull request and every push to `main`. A debug APK is built only
when the workflow is started by hand (Actions → CI → Run workflow, task `apk`); it is
attached to the run as `holyquran-debug-apk` (D-049). The same button with task
`goldens` makes or updates the golden images on `ubuntu-24.04` and commits them to the
branch (D-056). Off that platform, run `flutter test --exclude-tags golden test
tools/gen/test` and never commit golden images.

### Generate

| What | Command | Output (committed) |
| --- | --- | --- |
| UI strings | `flutter gen-l10n` (also run by `flutter pub get`) | `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_ar.dart`, from `lib/l10n/app_ar.arb` |
| Design tokens and icons | `dart run tools/gen/bin/generate.dart` (`--check` only verifies) | `lib/ui/core/theme/tokens.g.dart`, `lib/ui/core/theme/ramps.g.dart`, `lib/ui/core/widgets/icon_paths.g.dart`, from `design/design-system/tokens.json` and the `ICONS` map; see `tools/gen/README.md` |

Generated files are never edited by hand: change the input and regenerate. A test
(`tools/gen/test/generator_test.dart`) fails when the committed output is stale.

### Platforms

Only Android and iOS are built and released. The `web`, `linux`, `macos` and
`windows` folders from `flutter create` are kept but not maintained (D-041). iOS builds
start near the end of Phase 1 (D-042).

To look at the identity (Python 3, nothing to install):

```bash
python3 design/preview/build.py
# then open design/preview/out/index.html
```

## Credits

Content and data come from the sources listed in [`docs/SOURCES.md`](docs/SOURCES.md),
each under its own licence or permission. Fonts: Amiri Quran, Reem Kufi and IBM Plex
Sans Arabic, under the SIL Open Font License 1.1.
