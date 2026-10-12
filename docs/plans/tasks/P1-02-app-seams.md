# P1-02 — App seams: composition root, route table, route seams, Command (M1.1)

Wave 0 · Agent `ui-builder` · Key 2 · Cap $15 · Base `main` · Needs: the lead's step 0
(`provider` added) merged.

## Why

Phase 1 runs as many tasks in parallel (`docs/plans/PHASE1.md`). They must plug their
screens, routes and repositories into the app without sharing a file. This task makes
the seams once: D-102 and D-103 as proposed in `docs/plans/PHASE1.md` §6, read them
first. It also shows the identity's in-app `Splash` while the app starts (M1.1) and
closes the M0.1 note that an unknown location shows go_router's English error page.
`NV-06`: «كل عنوان قرآني رابط يفتح موضعه داخل التطبيق».

## Plan first

Ask `flutter-architect` through the Task tool for a short file-level plan of the
route tree and the composition root against `docs/ARCHITECTURE.md` ("State and
navigation") and D-047. Keep it to what this task lists.

## Do

1. `lib/utils/command.dart`: `Command0` and `Command1` as in
   <https://docs.flutter.dev/app-architecture/design-patterns/command>, over the
   existing `Result` (`lib/utils/result.dart`): running, error and completed states,
   no concurrent runs.
2. `lib/routing/routes.dart`: every Phase 1 path and a typed location builder for
   each. Tab roots: `/home`, `/mushaf` (reader at the last position),
   `/mushaf/read/:address` (reader at an address; the canonical address of D-063,
   encoded and decoded through `QuranAddress`), `/mushaf/index`, `/listen`,
   `/listen/recitations`, `/study`, `/study/search`, `/study/tafsir/:address`,
   `/more`, `/more/bookmarks`, `/more/resources`, `/more/settings`, `/more/sources`,
   `/onboarding` (outside the shell), `/gallery` (debug only, as today). Sheets are
   top-level modal routes on the root navigator, so that any tab can open them:
   `/sheet/goto`, `/sheet/context/:address`, `/sheet/word/:address`,
   `/sheet/ayah/:address`, `/sheet/surah-info/:surah`, `/sheet/tafsir/:address`,
   `/sheet/copy/:address`, `/sheet/share/:address`, `/sheet/note/:address`,
   `/sheet/play-options/:address`, `/sheet/range`, `/sheet/repeat`,
   `/sheet/silence`, `/sheet/stop-after`, `/sheet/sleep`, `/sheet/queue`,
   `/sheet/first-use-tafsir`, `/sheet/report/:address` (with an optional `pack`
   query; «أبلغ عن خطأ», O-17). Sheets are opened with `push` only, as a modal-sheet
   `Page`; a cold start at a sheet path redirects to the screen it belongs to.
3. `lib/routing/routes/<feature>_routes.dart`, one per feature of D-101: `onboarding`,
   `home`, `mushaf`, `index`, `listen`, `listen_controls`, `study`, `search`,
   `tafsir`, `sheets`, `share`, `more`, `bookmarks`, `resources`, `settings`,
   `sources`, `report`. Each exports the routes its feature adds to its tab branch and the
   top-level sheet routes it adds. Today they return only the existing placeholder
   tab screens (`HomeScreen`, `MushafScreen`, `ListenScreen`, `StudyScreen`,
   `MoreScreen`) and the gallery; the rest are empty until their tasks fill them.
   `lib/routing/router.dart` composes them and is not edited again in Phase 1.
4. A location that matches no route redirects to `/home`; no English page can show.
5. `lib/routing/startup_redirect.dart`: the start-up decision as a function the
   router's `redirect` calls; it returns no redirect for now (P1-15 and P1-26 fill it).
6. `lib/config/dependencies.dart` builds the app's providers from one file per area
   in `lib/config/providers/`: `user_database`, `settings`, `reading`, `quran`,
   `pack_install`, `catalogue`, `user_data`, `audio`, `tafsir`, `search`, `share`,
   `address`, `links`, in that order (later areas may read earlier ones through `provider`).
   Each returns its providers, possibly after async set-up; today each is empty.
7. `lib/main.dart`: show the identity's `Splash` widget (`lib/ui/core/widgets/splash.dart`)
   at once, build the dependencies, then show `QuranApp` under a `MultiProvider`.
   No design number in `main.dart`.
8. `lib/ui/core/shell_chrome.dart`: a `ChangeNotifier`, provided above the shell, by
   which a screen hides the tab bar (the reader's distraction-free mode and simple
   level); `TabShell` honours it.
9. `lib/domain/models/quran_structure.dart`: the one pure interface for the facts of
   the reference edition that plans, parsers and screens need (ayah count per surah,
   first ayah of each page, juz, hizb and rub, page of an ayah, next surah). P1-05
   implements it; P1-08 and P1-10 consume it.

## Tests

- `test/utils/command_test.dart`: states, error, no concurrent run.
- `test/routing/routes_test.dart`: every builder round-trips with the path it builds
  (addresses of several forms, Arabic-Indic digits never in paths); an unknown
  location lands on الرئيسية; a sheet route opens over each of the five tabs; a child
  route keeps its branch stack when the user switches tabs and comes back (the M0.1
  note on weak branch-stack tests).
- `test/config/dependencies_test.dart`: the composition root builds with every area
  empty and keeps the area order.
- The existing app and shell tests still pass; the app still opens in Arabic, right
  to left, on الرئيسية.

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
- `lib/main.dart` (handed over for this task)
- `lib/config/dependencies.dart`
- `lib/config/providers/` (the thirteen area files)
- `lib/ui/core/tab_shell.dart` and `lib/ui/core/shell_chrome.dart`
- `lib/domain/models/quran_structure.dart`
- `test/ui/core/tab_shell_test.dart`, `test/ui/core/shell_chrome_test.dart`
- `lib/routing/router.dart`
- `lib/routing/routes.dart`
- `lib/routing/startup_redirect.dart`
- `lib/routing/routes/` (the sixteen feature files)
- `lib/utils/command.dart`
- `test/utils/command_test.dart`
- `test/routing/`
- `test/config/`

### Do not touch
The rest of `lib/ui/` (read the placeholder screens, do not change them), `lib/l10n/`,
`pubspec.*`, `test/guards/`.

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

- `feat(utils): add Command over Result (M1.1)`
- `feat(routing): fix the Phase 1 route table and feature route seams (M1.1)`
- `feat(config): add the composition root and area provider seams (M1.1)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
