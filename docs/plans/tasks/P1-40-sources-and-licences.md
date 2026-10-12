# P1-40 — Sources and licences screen, link service (M1.1)

Wave 3 · Agent `ui-builder` · Key 1 · Cap $20 · Base `main` · Needs: P1-05, P1-07,
P1-15.

## Why

PRD §11.1: «ذكر المصدر ورابطه حيث تشترطه الرخصة يظهر في شاشة «المصادر والتراخيص» وفي شارة
المصدر». `docs/SOURCES.md`, "Conditions that shape the build": Tanzil is credited with
a link and its copyright notice stays verbatim; the three OFL texts ship in the
licences screen (registry row 17); every aggregator is named as a channel, the content
attributed to its origin. PRD §7.1 lists «المصادر والتراخيص» under المزيد. The screen
is an extension (PRD §7.6): build it from existing components and tokens.

## Do

1. `lib/data/services/link_service.dart` (`url_launcher`, behind an interface;
   delegate it to `data-builder` through the Task tool) and
   `lib/config/providers/links_providers.dart`.
2. Sources screen (`/more/sources`): for each installed pack (P1-07's list, the base
   pack through P1-05), its manifest sources: name, publisher, version, the link
   opened through the link service, and the licence notice shown verbatim; the three
   fonts with their OFL texts from `assets/`. Headings and each source's credit
   wording are Appendix C (question 13 of `docs/plans/PHASE1.md` §9): show only data
   until the keys exist, and report.
3. `lib/routing/routes/sources_routes.dart`; metrics in `sources_metrics.dart`.

## Tests

A synthetic pack's sources and notice listed unchanged; the link service called with
the manifest's URL; the three OFL texts present; four themes and 200%. Golden tests
of the screen.

## Acceptance

- `dart format .` changes nothing, `flutter analyze` reports no issues, and
  `flutter test --exclude-tags golden test tools/gen/test` passes (add `spike` if that
  folder exists). Run all three before the last commit, fix what fails, and run them
  again. Never weaken, skip or delete a test to make it pass.
- Golden images are made only by the CI `goldens` task (D-056). Write new golden tests
  tagged `golden`; never create or commit a `.png` file. A new golden test without its
  image is expected.
- The acceptance checklist of `docs/DESIGN_SYSTEM.md` holds for every widget and
  screen you touched: four themes, right to left, 200% text, 48 hit areas, labels,
  focus ring, reduce motion, Arabic-Indic digits, strings from the ARB file.
- Each acceptance criterion quoted above is reported as met (with its test), partial
  (with the reason) or a pending human check (device, reviewer or owner).

## Self-review

Through the Task tool, run `code-reviewer` on your whole diff and `identity-auditor` on every UI change. Fix every blocking
and should-fix finding, re-run the checks, and ask again until none remains. Say in
the report which nits you left and why.

## Files

### You own
- `lib/ui/features/sources/`
- `lib/data/services/link_service.dart`
- `lib/config/providers/links_providers.dart`
- `lib/routing/routes/sources_routes.dart`
- `lib/ui/core/metrics/sources_metrics.dart`
- `test/ui/features/sources/`, `test/data/services/link_service_test.dart`

### Do not touch
`lib/ui/features/more/`, `lib/l10n/`, `assets/`, other features.

## Rules

- `CLAUDE.md` and `docs/WORKFLOW.md` apply in full. Quran text comes only from packs,
  by address, through `QuranText`, `SurahName` or a sink listed under
  `test/guards/allow/`; it is never typed, pasted, trimmed, normalised or split by the
  app. Tests use the synthetic packs of `testing/packs/` and obviously synthetic text.
- No generated content. The identity is closed. No Arabic wording of your own: use
  only keys in `lib/l10n/app_ar.arb`; if one you need is missing, leave that element
  out and list it in the report.
- Edit only the files under "You own"; every file listed there is handed over to you
  for this task, whatever your agent file says. If another file must change, stop that
  part and report it. A gallery title or sample label reuses an existing key. Never edit `docs/PROJECT_STATUS.md`, `docs/DECISIONS.md`, `.github/`, or
  `pubspec.*`.
- Few comments, saying why; small files; no dead code or speculative options; no
  literal colours, font names or inline design numbers in feature code.
- Never print, write or commit secrets or environment variables; do not run `env`,
  `printenv` or `set`.
- Commit on the current branch only. Do not push, open pull requests, change remotes or
  call the GitHub API.

## Commits

`feat(settings): sources and licences screen with links (M1.1)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
