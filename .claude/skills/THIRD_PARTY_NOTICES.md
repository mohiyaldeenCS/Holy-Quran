# Skills in this folder

Two kinds of skills live here. Claude Code discovers every `<name>/SKILL.md` automatically.

## Project skills (written for this repository)

| Skill | Use it when |
| --- | --- |
| `session-handoff` | Starting or ending a working session, finishing a task or milestone, or switching accounts. |
| `implement-requirement` | Implementing any PRD requirement (an ID such as `RD-02`). |
| `apply-visual-identity` | Building or changing any screen or widget. |
| `quran-text-integrity` | Touching Quran text, search, copy, share, export, widgets or content packs. |
| `ask-owner` | A decision belongs to the product owner. |

## Official Dart and Flutter skills (vendored, unmodified)

Copied byte-for-byte from the Flutter team's repository so that every account and
machine that clones this repo gets the same skills without installing a plugin.

- Source: <https://github.com/flutter/agent-plugins> (`skills/`), plugin `dart-flutter` 1.0.6
- Commit: `0ef3972f93e2baa4156ba1cbb1e515cd53079c68` (2026-09-30)
- Dart skills are synced there from <https://github.com/dart-lang/skills> at `0d9f1c4a0ae29d6f5180bf6143d7997ec3bacf49`
- Licence: BSD-3-Clause, Copyright 2026 The Flutter Authors. Full text in `LICENSE.flutter-agent-plugins`.

Included (20): `flutter-add-integration-test`, `flutter-add-widget-preview`,
`flutter-add-widget-test`, `flutter-apply-architecture-best-practices`,
`flutter-build-responsive-layout`, `flutter-fix-layout-issues`,
`flutter-implement-json-serialization`, `flutter-setup-declarative-routing`,
`flutter-setup-localization`, `flutter-use-http-package`, `dart-add-unit-test`,
`dart-build-cli-app`, `dart-collect-coverage`, `dart-fix-runtime-errors`,
`dart-generate-test-mocks`, `dart-resolve-package-conflicts`,
`dart-run-static-analysis`, `dart-use-path-package`, `dart-use-pattern-matching`,
`dart-write-documentation`.

Left out because this app does not need them: `dart-setup-ffi-assets`,
`dart-use-ffigen`, `dart-use-doc-examples`, `dart-migrate-to-checks-package`,
`dart-use-primary-constructors`.

### Rules for the vendored copies

- Do not edit them. To change behaviour, write the project rule in `CLAUDE.md` or a
  project skill; project rules win over a generic skill.
- They are generic. Where an example disagrees with the installed Flutter version,
  trust `flutter analyze` and the current Flutter docs.
- Do not also install the `dart-flutter` plugin in this project: it would load the
  same skills twice. The plugin's other part, the Dart and Flutter MCP server, is
  configured in `.mcp.json` at the repo root.

### Refreshing

```bash
git clone --depth 1 https://github.com/flutter/agent-plugins /tmp/agent-plugins
# for each skill listed above:
rm -rf .claude/skills/<skill> && cp -R /tmp/agent-plugins/skills/<skill> .claude/skills/
```

Then update the commit hash above and commit as `chore(skills): refresh official Flutter skills`.
