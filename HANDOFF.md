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
| #82 (was #71) P1-33 | **Merged** 2026-11-04 (`bc73b54`) after a short review of the post-merge commits (PASS, $0.30) and green CI on `3b4b671` | none |
| #87 T2 marking | **Merged** 2026-11-04 (`67425d7`) after the re-audit (CONFORMS WITH NITS, $0.17) and a full check on `2e76494` (5,538 tests passed; the jobs API stayed stale, the log was read) | none |
| T1 test copy | Done ($1.33, `164e527`): `TestCopy.parse` (release refused, production keys refused), `DevicePackBundle`, `SignatureRequired`, the Gradle release refusal, the copy line and no share card in the test copy, D-163 | 41885971333: review, `code-reviewer` opus, $3, key 1 |
| P1-35 build | The audit's fixes, `test/a11y/`, «نُسخت الآية», the fifteen D-166 descriptions | 41881058535: `ui-builder` sonnet, $15, key 2 |
| P1-35 audit | Done ($1.46): two must-fix (no keyboard route into the reader's ayahs; the seek track not keyboard-operable), five should-fix (`IntegrityAlert` not a live region, no copy confirmation, no `test/a11y/`, settings headings read twice…), four nits; a ten-task TalkBack protocol for the owner. The owner answered D-168; the lead ruled D-169. Kept in `docs/plans/P1-35_AUDIT.md` | none |
| SH-02 share sizes | Built ($1.26): automatic 4:5 → 9:16, 1:1 built but not offered; the lead looked at the images and the owner approved them (D-170) | review, then merge |
| #86 NF-14 guard follow-up | **Merged** 2026-11-04 (`695c5c8`) after a review (PASS WITH NITS) and green CI; D-158 (4) now says the database-handle check is name-based | none |
| #80 AU-01 | **Merged** 2026-11-04 (`3aca395`) after six reviews (the sixth PASS WITH NITS, $0.56) and green CI on `f302a39`. Left open, recorded in D-161: a seek given between the engine's end report and the repository's handling still lands on the successor (needs an interface change); the walk takes about 50 s | none |
| #78 P1-36 | **Merged** 2026-11-04 (`6f57d75`) after a third review (PASS WITH NITS, $1.09; seven findings closed and checked by mutation) and green CI | none |
| #85 P1-36 follow-up | **Merged** 2026-11-04 (`ad545cc`) after a review (PASS WITH NITS) and green CI | none |
| #81 records | **Merged** 2026-11-04 (`a412d79`) after two reviews (sonnet, $0.26) and green CI: D-162, `docs/plans/TEST_COPY.md` | none |
| #83 T3 test copy | **Merged** 2026-11-04 (`9ca8b65`) after two reviews (the second PASS WITH NITS, $0.98; the first re-review run died on an API overload) and green CI. Its notes (S1: the dirty-tree message suggested a whole-tree `git clean -fd`; a killed run's key unnoticed; the pack check after signing) go to the follow-up below, which must merge before the owner uses the script | none |
| #84 T3 polish | **Merged** 2026-11-04 (`f10e248`) after a review (PASS WITH NITS, $0.10; the reviewer ran the mutation the author skipped) and green CI: per-file clean-up commands, a leftover key refused, the tree checked before signing. The script is ready; it waits for T1 and T2 in the app | none |
| O-04 candidates | Research done ($0.83), kept in `docs/content/RECITATION_CANDIDATES.md`. The owner chose four (D-167): Minshawi and Abdul Basit, murattal and mujawwad, all word-timed; the PRD's five replaced by his decision. He fills `docs/content/RECITATION_RIGHTS_FORM.md` | none |

**Lost reports.** Two runs (the #71 audit and #80) ended with a short reply to a late background
notification, which replaced the report: only the last message is kept, and the log shortens
earlier messages. Every task text now ends with: run commands in the foreground, no background
shells or Monitor, and repeat the whole report if woken after writing it.
**The owner's rule (2026-11-04): the lead's session spends nothing on checks.** No local `flutter analyze` or tests, no long log reading: merging `main` into a branch and checking the result is a task for an agent in Actions (a clean textual merge can still break the build, #82 and the flow rig). The lead only writes task texts, starts runs, reads the reports' verdicts, merges and keeps the records.
**`action_required` CI runs.** Each agent push starts two CI runs: the `workflow_dispatch` check,
which runs, and a `pull_request` run that waits for approval. The dispatch run is the check of
record for the head.
**Spend this session**, by the SDK's estimates: $74.74 for 56 finished runs by 19:00 UTC, summed from the run logs; the caps of the runs out keep the worst case under $100 (the largest single run: #80's last round, $14.63). The owner asked to be told before the total passes $100.

`main` holds 37 of 40 tasks (18 partial); see the status file. **No app build has real
content yet and none has run on a device since the spike of 2026-10-12.** **Before the first
run on a branch, check it:** `git merge-base --is-ancestor origin/main origin/<branch>`. If
`main` changed `.github/` and the branch lacks it, merge `main` into the branch from your own
session. Decision numbers: D-155 to D-160, D-162 and D-165 are on `main`; D-166 and D-167 on the
lead's records pull request; D-161 (#80) and D-164 (#87) on open branches; D-163 is reserved for T1;
D-168 and D-169 are the P1-35 answers and rulings; D-170 the share sizes; the next free number is D-171.

The queue, after the table above:

1. **#80, #87:** each fix run, then an independent re-review, then merge
   under D-136.
2. **`agent/nf-14-guard-followup`:** the re-review of #77's should-fix and notes (task text
   written; a `test-engineer` run when a slot frees).
3. **The local test copy** by `docs/plans/TEST_COPY.md` (section 4): T3 is merged (#83, #84);
   T2 is #87; then T1, then T4. Then guide the owner through its
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

- **The route is `docs/plans/TEST_COPY.md`** (D-162 (13), (14); D-163 (T1) and D-164 (T2) when merged; D-165 is written).
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
- **O-04:** chosen (D-167). Fill `docs/content/RECITATION_RIGHTS_FORM.md` from the permission papers and send it back.
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
