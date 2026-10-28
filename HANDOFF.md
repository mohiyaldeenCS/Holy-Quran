# Handoff — 2026-10-28

The owner switched accounts in the middle of a session. This file tells the next lead
exactly where the work stopped. Facts were taken from Git and GitHub at the time of
writing. `docs/PROJECT_STATUS.md` stays the authority for the project's state; if the
two disagree, Git wins, then the status file. Delete this file (with the owner's
permission) once its "In flight" section is empty.

## 1. The project

القرآن الكريم: an Arabic-only, right-to-left Flutter app for Android and iOS. It covers
reading, listening, study and memorisation. It is free and non-profit, with no ads,
purchases or tracking. The owner is the product authority; he writes Arabic.

- **Scope:** `docs/prd/PRD.ar.md`.
- **Looks:** `design/` and `docs/DESIGN_SYSTEM.md`. The identity is closed.
- **Phase 1:** the 40 tasks in `docs/plans/PHASE1.md`, with one task text each in
  `docs/plans/tasks/P1-xx-*.md`.
- **Never traded away** (`CLAUDE.md`):
  - Quran text is never typed, edited or normalised.
  - No generated religious content.
  - The identity is reproduced, not redesigned.
  - Scope belongs to the PRD.
  - User data stays local.

## 2. Done

**Phase 1 tasks merged into `main`: 23.**

- P1-01 to P1-13, P1-15, P1-16, P1-18 to P1-21, P1-25, P1-28, P1-38 and P1-39.
- Partial: P1-12, P1-15, P1-25 and P1-28. Each has its partial criteria in
  `docs/PROJECT_STATUS.md` → "In progress".

**Pull requests merged on 2026-10-28:**

| PR | What | Records |
| --- | --- | --- |
| #54 | Status corrected from Git; the owner's answers; resumption | D-128, D-129 |
| #55 | Tests portable to Windows; `.gitattributes` `eol=lf` | — |
| #44 | P1-12 copy and share | D-130 |
| #51 | P1-15 settings, onboarding, sources, report sheet; in-memory fallback; Android backup excluded | D-133, D-134 |
| #50 | P1-28 player control sheets (range, play options, repeat, silence, queue) | D-135 |
| #56 | Gallery tap-target test sized to the gallery; the owner's third batch of answers | D-136 |
| #57 | P1-39 eight project icons in the generator | — |
| #58 | P1-38 second batch of strings (83 keys) | — |
| #52 | P1-25 resource manager (`/more/resources`) | D-137 |
| #59 | `PlaybackPlanBuilder` provided; `SheetNeeds` guard; every sheet route tested through the real providers | D-138 |

`main` is at `23fe34b`, the #59 merge.

## 3. In flight, where work stopped

Agents were still running when this was written. Each was told to push after every
commit, so the branch on GitHub holds whatever they finished. Run
`git log origin/main..origin/<branch>` first, before anything else.

### 3.1 #53: P1-27, the full player, the mini player and the recitation picker (M1.9)

Branch `agent/p1-27-player-screens`, head `676a281`, after the CI golden images at
`7463fef`.

**Done:**

- The first code review found two blockers and five should-fix items. All are fixed
  in 6dc63ef, 6a2890f, 751d602, eb976a8 and c65052b.
- The second code review (opus) confirmed all seven fixes hold.
- Its should-fix items are fixed in `676a281`, where the full suite passes (3854
  passed, 4 skipped):
  - the range and silence chips always show while there is a plan:
    - unset silence shows «صمت ٠ ث» (`playerSilenceSeconds`);
    - an unset range shows «محدد النطاق» (`rangeSelectorTitle`);
  - `PlayerMetrics` references `SettingsMetrics`;
  - `PanelChip` was renamed `PlayerPanelChip`;
  - the dead `?? _state.ayah` was removed.
- The lead started the CI `goldens` task on `676a281` while writing this. Check that
  the bot's `test(ds): update golden images (P1-27)` commit landed after `676a281`; if
  it did not, run it again.

**Remaining before merge:**

1. Make sure the golden images are current, as above. To start the task again:
   `gh workflow run CI --ref agent/p1-27-player-screens -f task=goldens -f scope=P1-27`.
   Then pull the bot's commit.
2. Have `identity-auditor` (sonnet/high) audit the new images:
   - `player_screen_*`, `recitation_picker_*`, `tab_shell_mini_player_*` and
     `gallery_audio_*`;
   - the first audit's minor items: chips in `Wrap`; an empty 48 spacer instead of a
     back button; no time on the position line.
3. Write D-139 in `docs/DECISIONS.md`, taking the number after the highest on `main`
   and the open pull requests. It records:
   - the riwaya is hidden, because `Recitation.riwaya` is an id (`hafs`), not a
     display name. Follow-up: a riwaya display-name field in the catalogue (P1-33);
   - the mini player shows while paused (an interpretation of «عند التشغيل فقط»);
   - the mini player is hidden for whole-surah plans without timing, because its title
     needs an ayah (LV-03 partly met);
   - the shell receives a `MiniPlayerSource` from `lib/routing/router.dart`, so
     `ui/core` never imports a feature;
   - buttons are hidden until `hasRoute` finds their route (sleep waits for AU-07);
   - the 5-second screen-reader seek step (`PlayerMetrics.seekStep`);
   - the view model reads the segment being heard before `PlayerState.ayah`;
   - plain calls instead of commands, a deviation from `docs/ARCHITECTURE.md`
     "State and navigation";
   - errors:
     - only «تعذّر الاتصال» is shown, and only in the full player;
     - `fileMissing` and `playbackFailed` have no wording;
     - buffering is not shown;
   - the chip labels above.
4. Update `docs/PROJECT_STATUS.md` in the branch.
   - P1-27 is merged, partial:
     - AU-01 partial (no choosing in the picker; riwaya hidden);
     - AU-05 partial;
     - seeking impossible until the plan carries timings (D-135).
   - Pending human checks:
     - mini player contrast in the contrast and night themes (non-text contrast,
       for the owner);
     - the `RecitationCard` badge merging with the surface in night and contrast;
     - TalkBack;
     - 200% on a device.
5. Wait for CI to pass, then merge under D-136.

### 3.2 P1-14: the reader screen in surah mode (M1.2)

Branch `agent/p1-14-reader-surah-screen`, from `main` 9802482, no pull request yet.

- The architect's plan, approved by the lead, is
  `docs/plans/handoff/P1-14-architect-plan.md`. Build from it.
- Pushed when this section was first written (the branch was at `4f76582` by the
  time it was committed; check what was added):
  - `a167bf6` position bar and tappable surah-header info line;
  - `20e9648` surah-mode reader;
  - `70322c8` surah-info sheet.
- Plan steps 4 to 6 remain:
  - saving and restoring the reading position;
  - the tests (byte-exact text, 200%, landscape, offline, failed pack, goldens);
  - `feat(config): provide the reading position`, which wires
    `LocalReadingPositionRepository` in `lib/config/providers/reading_providers.dart`
    under D-133's condition.
- After that: update from `main`, the pinned checks, `goldens`, `code-reviewer`
  (opus/high), `identity-auditor` (sonnet/high), records, PR, merge.
- Kept out by the plan:
  - margin marks (they need P1-22's engine hook and the owner's answer, §6);
  - loading the previous surah when scrolling up;
  - a `PositionBar` gallery entry (`mushaf_gallery.dart` belongs to P1-22).

### 3.3 P1-22: reader targets, the tap resolver and highlights (M1.2, M1.6)

The build is finished, on branch `agent/p1-22-reader-targets` (from `main` 23fe34b).
No pull request yet.

**Commits:**

- `20da938` (wip) engine files;
- `cbd26ae` targets and tap resolution (AX-02), with tests;
- `8edc254` selection, recitation and search highlights.

**Checks on `8edc254`:** format clean, analyze clean, 3837 passed, 4 skipped.

**The tap rule** is S7's `priorityZonesWithSlop` (D-097), one rule with no options:

1. A word wins when the tap is more than 12 px inside both of its edges.
2. Otherwise markers and marks win within a 48 px zone, nearest centre first, the
   marker before the mark on a tie.
3. Otherwise the nearest target on the line, or the margin.

**The agent's acceptance report:**

- Met:
  - every centre resolves to itself;
  - 48 px zones;
  - pinch steps and the focal ayah kept;
  - painters leave the text bytes untouched;
  - every highlight has a shape or line as well as colour, in the four themes.
- Partial:
  - the 6, 12 and 18 px taps are tested on the synthetic pack only, because the
    real-text figures are S7's;
  - the line-start mark case was the old engine's.
- Pending human check: how taps and pinch feel on a device.
- Golden test `highlights_golden_test` is written but has no image yet; run
  `goldens`.

**New public API, added without touching `SurahSliver`:**

- `InteractiveSurahSliver`: `SurahSliver`'s inputs plus `highlights`, `onTap`,
  `onLongPress` and `blockOverlayBuilder(context, BlockLayout)`. The overlay sits
  above each block and takes no taps. `BlockLayout.marginMarks` gives each mark with
  its line band, which is P1-14's hook for `MarginMarkView`.
- `TargetGestures`, `ReaderPinch`, `stepAfterPinch`, `focalAyahAt` and
  `yOfFocalAyah`.

**To record**, as D-140 or the next free number:

- the tap rule above;
- `InteractiveSurahSliver` duplicates about 100 lines of `SurahSliver`. Make
  `SurahSliver` delegate to it, or replace it, after P1-14;
- the recited ayah's filled marker is an `AyahMarker(playing: true)` laid over the
  engine's marker. A `playingAyah` input on `ReaderBlock` would be cleaner;
- highlights are rounded rects per line, not the board's sliced edges;
- the reader has no screen-reader route to the marker or the selected state; P1-14
  or P1-23 needs one.

**Remaining before merge:**

1. Update from `main` and run the pinned checks.
2. Open the PR.
3. Run `goldens` and pull the bot's commit.
4. Get `code-reviewer` (opus/high) and `identity-auditor` (sonnet/high).
5. Apply their fixes, then write the records and the status update.
6. Merge.

P1-14 can then use `InteractiveSurahSliver` once the owner answers the margin-mark
question (§6).

## 4. The system as it is

**Checked on 2026-10-28** with Flutter 3.44.7 on Windows, full suite without goldens:

- `main` after #59: 3798 passed, 4 skipped. `flutter analyze` is clean, and
  `dart format` changes nothing.
- P1-27 after merging `main` (`9e90d15`): 3854 passed, 4 skipped.

**What works:**

- the shell and five tabs;
- home;
- settings, onboarding, sources and the report sheet;
- copy and share;
- the player sheets, reachable once a plan exists;
- the resource manager screen;
- the component gallery (debug builds);
- packs verified with SHA-256 and Ed25519.

**What exists but is not reachable or not wired:**

- **The reader.** The mushaf tab is still a placeholder on `main` until P1-14.
- **Audio.** Nothing can play in the app, because the recitation locator returns
  null until P1-13 or P1-33. No seeking is possible either: the plan carries no
  `AyahTimings` (D-135).
- **The resource manager.** It cannot be reached until the installer is wired into
  `lib/config` (free space, Wi-Fi only, integrity reset, rollback; D-137).
- **`userDataProviders`.** Not wired. D-133's condition: when settings fall back to
  memory, the user database must too.
- **The reading position.** It is not provided (P1-14 step 6).

**Not tested:** anything on a device, which is the owner's pending human checks in
the status file. Golden images are compared on ubuntu-24.04 CI only.

**Known defects or gaps:** none on `main` that fail a test. The partial criteria are
listed per task in the status file.

## 5. Decisions, constraints and preferences

The full log is `docs/DECISIONS.md`. The decisions of 2026-10-28:

- **D-128:** the owner's answers.
  - The session is local, on his machine, with Git as the authority.
  - One status file.
  - Appendix B is approved.
  - Appendix C's wording is delegated to the lead, except religious content and
    source credits.
  - The eight icons are approved.
  - A bookmark takes the last category used.
  - Four categories now.
  - O-12 has declared contrast exceptions.
  - Credits are shown as each source publishes them.
  - The short tafsir is proposed with the packs.
  - No crash reports in Phase 1.
- **D-129:** pinned SDK `C:/SDK/flutter-3.44.7`, and the order of work.
- **D-131:** the lead may make goldens on ubuntu-24.04 when CI cannot.
- **D-132:** the owner's working rules (below).
- **D-136:** standing permission to merge into `main` after an independent review and
  green CI. User data stays on the device. The setup's recitation step stays hidden
  until a recitation is Ready.
- **D-133, D-134, D-135, D-137, D-138:** engineering records for P1-15, P1-28, P1-25
  and #59. Each lists its follow-ups.

**The owner's rules for the lead** (his words, still in force):

- **Act without asking for day-to-day work, including commits on the working branch.**
- **Ask him before anything hard to undo:**
  - deleting files or data;
  - `git push --force` or rewriting history;
  - publishing or deploying;
  - database migrations;
  - adding major dependencies.
- **Merging into `main` is allowed without asking** after an independent review and
  green CI (D-136).
- **Do not use the `fable` model or `max` effort without his permission.**
- **No more than 3–4 agents at a time.**
- **Agent model and effort:**
  - haiku/low for searches, summaries and mechanical work;
  - sonnet/medium for clearly scoped code;
  - sonnet/high for edge cases and multi-file changes;
  - opus/high for architecture, obscure diagnosis and review before acceptance.
  - Raise one level only when needed.
- **Agent briefs are self-contained:** goal, files, decisions, constraints, done
  criteria and a short report format.
- **Parallel code-editing agents each get their own git worktree.**
- **Check agents' work:**
  - verify each result yourself;
  - get an independent `code-reviewer`, plus `identity-auditor` for UI;
  - run the tests after each merge.
- **Collect the owner's questions into one `AskUserQuestion` batch.** Ask in Arabic,
  with the recommended option first and marked «(موصى به)».
- **Reports to the owner are in Arabic.** They cover what was done, by whom and with
  which model, the test results, what remains, and the decisions needed. Update the
  status file afterwards.

**How work is done** (`CLAUDE.md`, `docs/WORKFLOW.md`):

- English for code and docs.
- Conventional Commits naming the requirement ID.
- A branch per task and a commit per step; push after each commit.
- Merge commits.
- The status file is updated in the branch.

## 6. Open problems and questions

**For the owner** (not yet asked; batch them):

1. **Where the marks go in surah mode.** P1-14's architect asks:
   «أين توضع علامات الربع والحزب والجزء و«سجدة» في وضع السورة، والهامش ٢٨ فقط؟»
   Options: «تُرسم فوق حافة الهامش دون تضييق النص (موصى به)» or
   «يُضيَّق عمود النص لإفساح الهامش».
2. **Mini player contrast.** In the contrast theme the mini player is black on black,
   and in night it barely stands apart (a non-text contrast case not covered by O-12).
   Ask whether a border or token is allowed, or whether it stays as drawn.
3. **The rest.** Every older open question is in `docs/PROJECT_STATUS.md` → "Waiting
   on the owner" (M0.4-x, O-01, O-04, O-07, O-11, O-09, …).

**Engineering follow-ups** (decide and do):

- a synthetic-pack fault that reaches the builder's rejection (D-138);
- timings in the plan;
- AU-07, AU-08, unlimited repeat and add-to-queue (D-135);
- installer wiring (D-137);
- `userDataProviders` (D-133);
- iOS `isExcludedFromBackup`;
- LV-04;
- the setup redirect (its strings now exist);
- a shared sheet-frame widget, since `.qk-sheet` is copied five times;
- SH-01's several-ayat copy;
- the catalogue riwaya display name.

**Environment quirks:**

- **`analysis_options.yaml` keeps changing** in `D:/projects/Holy-Quran`, most likely
  an editor tab saving itself. Never commit it. The stash `stash@{0}` holds an
  earlier copy of the same changes; do not drop it without asking.
- **The Dart MCP server failed to connect** in this session.
- **Worktrees under the old session's temp scratchpad belong to that session.**
  Create your own: `git worktree add <dir> <branch>`. Removing the old ones deletes
  files, so ask first.
- **Worktrees from branches older than PR #55 need renormalising:**
  `git rm -q --cached -r . && git reset -q --hard HEAD`.
- **After merging `main` into a branch,** run `flutter gen-l10n`.
  `docs/DECISIONS.md` and `docs/PROJECT_STATUS.md` conflict often; keep both sides.
- **A CI run after the goldens bot's commit can be `action_required`.** Approve it
  with
  `gh api -X POST repos/mohiyaldeenCS/Holy-Quran/actions/runs/<id>/approve`,
  or push a new commit.

## 7. Next steps, in order

1. **Verify the state:**
   - `git fetch --all --prune`;
   - `gh pr list`;
   - `git log origin/main..origin/<branch>` for the three branches in §3.
2. **Finish #53 (P1-27)** as in §3.1, and merge it.
3. **Finish P1-14** (§3.2): its PR, the reviews, the merge.
4. **Finish P1-22** (§3.3): its PR, the reviews, the merge. Then give P1-14 the
   margin-mark hook once the owner answers question 1.
5. **Start P1-17** (index, go-to sheet, context sheet, ayah cards; `ui-builder`
   sonnet/high). It is the last of wave 2.
6. **P1-29, then waves 3 to 5** in `docs/plans/PHASE1.md` order, each when its
   "Needs" are merged.
7. **Ask the owner** the §6 questions in one batch when one blocks work.
8. **End every session** by updating `docs/PROJECT_STATUS.md` (snapshot and session
   log), pushing, and reporting to the owner in Arabic.

**The check command** (Git Bash; run `dart format` on paths, never on `.`):

```sh
F=/c/SDK/flutter-3.44.7/bin
$F/dart format --output=none --set-exit-if-changed lib test testing tools
$F/flutter analyze
$F/flutter test --exclude-tags golden test tools/gen/test -r compact
```
