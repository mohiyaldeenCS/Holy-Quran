# Handoff — 2026-11-04

For the next lead, on a new account. Nothing else from the earlier sessions survives, and
you do not need to repeat the audit: this file was checked against Git and GitHub when it
was written. `docs/PROJECT_STATUS.md` stays the authority for the project's state; if the
two disagree, Git wins, then the status file. Update this file after every finished step.
Delete it, with the owner's permission, once "In flight" is empty.

## 1. Your role (D-159)

**You are the team lead and only manage.** You write task texts, start agents in GitHub
Actions, read what they report, get an independent review, merge under D-136, keep the
records and report to the owner in Arabic. **You write no application code and fix no
test yourself:** a finding goes back to an agent. Local subagents are not the way of
working any more. Your own edits are the records (`docs/PROJECT_STATUS.md`,
`docs/DECISIONS.md`, `HANDOFF.md`, task texts) and, when needed, `.github/`, on a branch
with a pull request.

## 2. Starting an agent

Both repository secrets answered on 2026-11-04, and two small runs passed end to end, one
per key slot, one with `code-reviewer`, $0.06 together, on Flutter 3.47.9. Comment on a
pull request by a run without commits is new and was not exercised by those two runs,
which had no pull request; the whole report is also in the run's log either way.

```sh
gh workflow run agent.yml --ref main \
  -f branch=agent/<task> -f base=main -f key=1 -f budget_usd=15 \
  -f agent=test-engineer -f model=claude-sonnet-5-5 -f effort=high \
  -f task="<the whole task text>"
```

- `branch` must start with `agent/`; an existing one continues. `agent`: `none`,
  `ui-builder`, `data-builder`, `audio-builder`, `content-engineer`, `test-engineer`,
  `code-reviewer`, `identity-auditor`.
- **A task text stands alone:** goal, files, decisions, constraints, what done means, and
  "make your last message the whole report". Name the D-number it may use; agents do not
  touch `docs/PROJECT_STATUS.md` or `HANDOFF.md`. A review says read-only, commit nothing.
- **Results.** A run with commits opens or comments on the pull request, with its report
  and cost, and starts CI. Read a run with `gh run view <id> --log`, between
  `===== Agent's report =====` and `===== End of the report =====`.
- **Goldens.** Agents may not commit them. `gh workflow run ci.yml --ref <branch> -f
  task=goldens -f scope=<task>` makes them; look at every changed image before accepting.
- **The workflow refuses** a key, a golden image or any change under `.github/`, including
  one arriving by merging `main`. **So do not change `.github/` while a branch is open or a
  run is out** (`docs/WORKFLOW.md`). If you must, merge `main` into every open branch from
  your own session first, as was done on 2026-11-04.
- **Money.** The keys are the owner's (D-140 (13)); the balance shows only in his console.
  Caps: scoped code, sonnet high, $15; hard multi-file work $25; review, opus high, $10.
  `Credit balance is too low` in a log: use the other slot; both out: tell him. Ask him
  before this session's total passes $100, and state the spend in each report.
- **At most 3–4 runs at a time**, owning different files. No `fable`, no `max`, without his
  permission. An `apk` task never runs beside a test run.
- **From a cloud session** (2026-11-04): `gh auth status` calls the token invalid, yet `gh
  api` and `gh workflow run` work through the session's proxy, with admin rights. GraphQL is
  refused, so `gh pr list`, `gh pr view` and `gh run view` fail: use `gh api
  repos/mohiyaldeenCS/Holy-Quran/...` (pulls, issues/<n>/comments, actions/runs/<id>/jobs,
  actions/jobs/<id>/logs). Two runs on one branch queue (`concurrency: agent-<branch>`); a
  third cancels the waiting one.

## 3. In flight, in order

**Where each pull request stands** (cloud lead, 2026-11-04 07:00 UTC; check a run with `gh api
repos/mohiyaldeenCS/Holy-Quran/actions/runs/<id>`; task texts the lead wrote are kept in the
session only, so a run's task is in its log under "Task as given" or the workflow inputs):

| PR | State | Runs out |
| --- | --- | --- |
| #77 P1-37 | **Merged** 2026-11-04 (`1b4fa07`) after a re-review (PASS WITH NITS, $0.74) and green CI on `53d4d51`. Follow-up for the re-review's should-fix and notes: task text ready, starts when a slot frees (new branch `agent/nf-14-guard-followup`) | none |
| #76 P1-34 | **Merged** 2026-11-04 (`a917862`) after a re-review (PASS WITH NITS, $0.88) and green CI on `e5caf8c` | none |
| #71 P1-33 | Review ($2.29) and identity audit ($0.52) found a blocking `SurahName` misuse, a download that hangs after a relaunch, two test gaps and a sheet that ignores reduce-motion; the owner chose fix-then-merge (D-162 (1)). Data findings fixed by `data-builder` (`8df5ec0`..`fb71981`, $1.05; the hang's test failed before the fix) | 41827908560: UI findings, D-160 and the three approved strings, `ui-builder` sonnet, $12, key 2. Then a re-review |
| #80 AU-01 | Stall fixed (D-161); first review's B1 and S1 fixed (`8dab48b`, `21547ae`, $0.37). Second review ($1.14): CHANGES REQUIRED, one more stall of B1's kind (`:498`, a completion during a removal with a replacement already wanted: stop-after on then off), one-line fix tried by the reviewer; a note on the advance-then-complete variant. A third, outside the diff, in `player_repository.dart:330-335` (a segment ending while `_refreshNext` awaits `_locate`) is a separate task to write | 41833804107: fix, `audio-builder` sonnet, $10, key 1. Then a re-review |
| #78 P1-36 | Finished by `test-engineer` ($2.03). Review ($1.63): CHANGES REQUIRED. B1 search never types on a device in profile (test text input unregistered); B2 a phone run rewrites the app's data with no warning; B3 failed runs vanish so a budget can read MET; seven should-fix. The lead reversed his earlier call: nothing imports `flutter_driver`, so it is removed and D-156 stands; NF-05's «فتح» is measured from the tap to the first frame with the sheet visible, the slide's end reported beside it | 41835778640: fix and merge of `main`, `test-engineer` sonnet, $15, key 2. Then a re-review |
| #81 records | **Merged** 2026-11-04 (`a412d79`) after two reviews (sonnet, $0.26) and green CI: D-162, `docs/plans/TEST_COPY.md` | none |
| T3 test copy | The pipeline's test-copy mode and the owner's scripts (`tools/test_copy/`), D-165; no real text in Actions | 41832095481: `content-engineer` sonnet, $15, key 2 |

**Lost reports.** Two runs (the #71 audit and #80) ended with a short reply to a late background
notification, which replaced the report: only the last message is kept, and the log shortens
earlier messages. Every task text now ends with: run commands in the foreground, no background
shells or Monitor, and repeat the whole report if woken after writing it.
**`action_required` CI runs.** Each agent push starts two CI runs: the `workflow_dispatch` check,
which runs, and a `pull_request` run that waits for approval. The dispatch run is the check of
record for the head.
**Spend this session**, by the SDK's estimates: about $14.1 for fourteen finished runs, by
13:30 UTC.

`main` holds 37 of 40 tasks (18 partial); see the status file. **No app build has real
content yet and none has run on a device since the spike of 2026-10-12.** **Before the first
run on a branch, check it:** `git merge-base --is-ancestor origin/main origin/<branch>`. If
`main` changed `.github/` and the branch lacks it, merge `main` into the branch from your own
session. Decision numbers: D-156, D-158, D-159 and D-162 are on `main`; D-155 and D-160 (#71), D-157
(#78) and D-161 (#80) are on open branches; D-163 to D-165 are reserved for the
test-copy tasks T1 to T3; the next free number is D-166.

The queue, after the table above:

1. **#71, #80, #78:** each fix or finishing run, then an independent re-review, then merge
   under D-136.
2. **`agent/nf-14-guard-followup`:** the re-review of #77's should-fix and notes (task text
   written; a `test-engineer` run when a slot frees).
3. **The local test copy** by `docs/plans/TEST_COPY.md` (section 4): T3 and T2 first (T2 after
   #71 merges: both edit `app_ar.arb`), then T1, then T4. Then guide the owner through its
   local steps; that build is his first device session (D-162 (9)).
4. **Stand mode's button** «وضع الحامل» in `ReaderPlayerBar` (D-162 (3)), and the 1:1 and 9:16
   share cards (D-162 (6)); `ui-builder` tasks, the share images shown to the owner before merging.
5. **Candidate recitations** for O-04 (D-162 (10)): a read-only proposal from `docs/SOURCES.md`.
6. **The gaps that have no task** (status file, Next actions), written up and sent to agents.
7. **P1-35 accessibility**, on the finished screens. Its audit died unfinished; nothing was
   written.
8. **Stream B**: everything that does not wait for the owner, and section 6's list.

After the test copy reaches the owner's phone: give a short check list, carry on with item 6
until his results arrive, then reorder by them.


## 4. The test pack: never on GitHub

The owner allowed a pack with text the proofreader has not approved, on these conditions,
in force: it stays on his phone only; the app shows that it is an unapproved copy; it is
never uploaded to GitHub and never enters a release.

**So no Actions agent, CI task or GitHub artefact may touch this pack. The CI `apk` task
uploads to GitHub and must not be used for that build.**

- **The route is `docs/plans/TEST_COPY.md`** (D-162 (13), (14); D-163 to D-165 when written).
  It replaces the bundling this section used to describe: the pack is never put in
  `assets/packs/` or an APK. A profile APK built with `--dart-define=HOLYQURAN_TEST_PACK=...`
  and a throwaway test key (never the production key of D-140 (8)) reads the signed pack
  from the phone's own files, pushed there with `adb`; a release build refuses the define.
  The app shows «نسخة تجريبية غير معتمدة» on every screen; copied text ends with that line and
  image sharing is off.
- Agents build the code and `tools/test_copy/`. The rest happens on his machine, by him with
  your guidance: fetch the Tanzil source under `docs/SOURCES.md`'s conditions, build the pack
  with the pipeline's test-copy mode, run the integrity suite on it, sign with the throwaway
  key, build the profile APK, install, push the pack, delete the key and the local copies.
  Stop and report a failed hash or count.
- `.gitignore` still covers `assets/packs/` and `*.apk`, and `agent.yml` refuses both: if
  either ever appears in a working tree, run `git status` before any commit, never use
  `git add -f` on it, and remove it. D-140 (6) and (10) do not apply to this pack.

## 5. What happened, and what is kept

- 2026-10-29: the session died at 08:57 on the owner's clock on a 403. Its worktrees were
  in the temp folder, later emptied. What agents had not committed was replayed from their
  transcripts on 2026-11-02 and pushed. P1-34 lost nothing and P1-35 had written nothing.
- 2026-11-03: agents and reviewers stopped on the account's usage limit. All their commits
  are pushed.
- `refs/archive/2026-10-orphans/*` on GitHub: 27 stashes of the review rounds, in case one
  is wanted. `stash@{0}` on the owner's machine: the owner said to leave it.
  `fix/bookmark-restore-nullable` (on `main` through #75) and
  `chore/analysis-exclude-platform-dirs` (superseded) are pushed and unneeded; deleting
  branches is his decision.
- This machine: Flutter 3.47.9 in `C:/SDK/flutter`, `kotlin.incremental=false` in
  `~/.gradle/gradle.properties` (D-154 (7)).

## 6. What only the owner can do

Given to him on 2026-11-04; his answers are D-162. Still his to do:

- **B0.1, first (D-162 (12)):** the rights register, read clause by clause from the permission papers.
- **His phone:** the device checks in the status file, in one session on the local test-pack
  build (D-162 (9)); the lead guides the build when the marking task is merged.
- **O-04:** choose from the candidates an agent will propose (D-162 (10)).
- **O-16:** the proofreader's sign-off, once the base pack is built.
- **The religious reviewer:** the linking pages of books 183, 514, 276, 471, 473 and 440,
  and the honorific table (D-140 (7)) when the lead has derived it.
- **Book 466:** finish extracting it and upload the result.
- **Branches (D-162 (11)):** delete the 55 merged branches from his machine; the cloud
  session cannot. The command is in the status file's next actions.
- **Later:** O-01 and O-11 when a store account exists (D-162 (7), (8)); the launch host;
  iOS with Gate 0 (no iOS build has ever been made).
- **To approve when built:** the stand-mode button's label (D-162 (3), D-115); the 1:1 and
  9:16 share images (D-162 (6)).

## 7. When to ask him, and his rules

**Ask through `AskUserQuestion`, in Arabic, recommended option first with its reason,
only for:** a package whose latest version needs replacing it or a real change in
behaviour; an irreversible act his answers do not cover (deleting branches or data,
rewriting history); a content, rights or publishing decision; stand mode's entry. Decide
everything else and record it. Collect his questions into one batch.

- **Merging into `main` needs no asking** after an independent review, by an agent that did
  not write the code, and green CI (D-136). Check an agent's claims yourself against the
  branch and CI: its report is not evidence.
- Every code change: a branch, the checks on Flutter 3.47.9, a pull request.
- After each finished step send him two lines: what was done, what is next. Reports are in
  Arabic, and say plainly what failed or is unverified.
- `docs/PROJECT_STATUS.md` and this file are updated after each finished step.

## 8. The checks

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden test tools/gen/test
```

On `main` at `cbafe65` plus the review test: analyze clean, 4942 passed, 4 skipped on
Windows. Goldens are compared only on `ubuntu-24.04`, in CI.
