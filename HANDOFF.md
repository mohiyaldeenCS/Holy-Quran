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
| #77 P1-37 | Re-review ($0.74): PASS WITH NITS; one should-fix (a re-export from a settings stop file passes) and three notes, for a follow-up branch after the merge (task text ready). The lead merged `main` into the branch (`53d4d51`, `docs/DECISIONS.md` conflict between D-156 and D-158, both rows kept); merge when CI on `53d4d51` is green | CI 41829053612 |
| #76 P1-34 | **Merged** 2026-11-04 (`a917862`) after a re-review (PASS WITH NITS, $0.88) and green CI on `e5caf8c` | none |
| #71 P1-33 | Review ($2.29): blocking, a surah name leaves `SurahName` as a `String` in five button labels; should-fix, a relaunch can re-issue a stopped task id so a download never finishes (reproduced), two test gaps. Identity audit ($0.52): the delete sheet bypasses `SheetPage` (motion, reduce-motion). The owner chose fix-then-merge (D-162 (1)) | 41827857238: data findings, `data-builder` sonnet, $12, key 2; then 41827908560 (queued): UI findings, the `SurahName` label as D-160 and the three approved strings, `ui-builder` sonnet, $12, key 2. Then a re-review |
| #80 AU-01 (item 5) | The stall was real and is fixed (`3317625`, `eba0735`, $2.07; D-161; 11 of the 19 new tests fail on main's code). Review ($1.39): CHANGES REQUIRED. B1, a completion during a pending removal is reported as the removed track (`_tracks.last`), a stall reachable by turning on stop-after at an ayah's end; S1, a replaced successor can start; both proved | 41829373362: fix, `audio-builder` sonnet, $10, key 1. Then a re-review |
| #78 P1-36 | Being finished: merge `main` (keep `flutter_driver` for `flutter drive`, amend D-157), the font from the bundle on a device, the acceptance list | 41828815745: `test-engineer` sonnet, $15, key 1. Then a review |

**Lost reports.** Two runs (the #71 audit and #80) ended with a short reply to a late background
notification, which replaced the report: only the last message is kept, and the log shortens
earlier messages. Every task text now ends with: run commands in the foreground, no background
shells or Monitor, and repeat the whole report if woken after writing it.
**`action_required` CI runs.** Each agent push starts two CI runs: the `workflow_dispatch` check,
which runs, and a `pull_request` run that waits for approval. The dispatch run is the check of
record for the head.
**Spend this session**, by the SDK's estimates: $7.28 for six finished runs; caps of the runs
out: $54.

`main` holds 35 of 40 tasks (16 partial); see the status file. **No app build has real
content yet and none has run on a device since the spike of 2026-10-12.** All four
branches below were brought up to `main` from the outgoing session, because the workflow
refuses an agent's merge that carries a `.github/` change. **Before the first run on a
branch, check it:** `git merge-base --is-ancestor origin/main origin/<branch>`. If `main`
changed `.github/` and the branch lacks it, merge `main` into the branch from your own
session. D-155 (#71), D-157 (#78), D-158 (#77) and D-159 are written; D-156 is reserved for
#76's `integration_test` decision. D-160 is reserved for #71's `SurahName` label and D-161 for the audio race; D-162 holds the owner's answers of 2026-11-04; the next free number is D-163.

1. **#77, P1-37 release readiness.** CI green at last check. Its author reports its own
   reviewers passed; the independent review of the final head died on a usage limit.
   Start it (`code-reviewer`, weight on `test/guards/privacy_test.dart`, which changed
   after the earlier review; D-158; the deny patterns `segment.*`, `clarity.*`). Then merge.
2. **#71, P1-33 recitation downloads.** Wired to the player, D-155 written, CI green at last
   check. Never had a final review on record, and that review died at its start. Start it:
   the shared `DownloadService`, a start with no pack, integrity before playing, deleting
   while downloading, catalogue paths. Known, stated in the PR: no OF-03 storage bar; the
   reciter's own basmala and isti'adha find no file; a refused resume untested. Three
   strings await the owner: `resourceStop`, `recitationDownloadWhole`,
   `recitationQualityKbps`.
3. **#76, P1-34 flow tests. Not ready: the review's findings are in a comment on the PR and
   none is fixed.** The most serious: every device test fails in `setUpAll`, and the
   lifecycle test never launches with the pack absent. Send it to `test-engineer`, then
   review again.
4. **#78, P1-36 performance harness.** Draft. Recovered, then continued; the last agent
   stopped before its report, with no self-review. Send it to `test-engineer` to go through
   the acceptance list, then review. It needs `flutter_driver`; #76 removes that from its
   own branch, so run these two one after the other and expect a `pubspec` merge.
5. **Check a possible stall** between ayat: `lib/data/services/audio_engine_service.dart:397-400`
   (details in the comment on #76). Not reproduced. An `audio-builder` task, test first.
6. **First real run on the owner's phone** (section 4).
7. **The gaps that have no task** (status file, Next actions), written up and sent to agents.
8. **P1-35 accessibility**, on the finished screens. Its audit died unfinished; nothing was
   written.
9. **Stream B**: everything that does not wait for the owner, and section 6's list.

After the APK reaches the owner: give install steps and a short check list, carry on with
item 7 until his results arrive, then reorder by them.


## 4. The test pack: never on GitHub

The owner allowed a pack with text the proofreader has not approved, on these conditions,
in force: it stays on his phone only; the app shows that it is an unapproved copy; it is
never uploaded to GitHub and never enters a release.

**So no Actions agent, CI task or GitHub artefact may touch this pack, or an APK holding
it. The CI `apk` task uploads to GitHub and must not be used for that build.**

- Agents build the code: the visible unapproved-copy marking, off unless a build flag asks
  for it, and the local steps written out. Ask the owner about the marking's wording if the
  identity and D-115 do not cover it.
- The rest happens on his machine, by him with your guidance, or by a session running
  there: fetch the source under `docs/SOURCES.md`'s conditions with `tools/packs`, run the
  integrity suite, generate the signing key (D-140 (8): it never leaves the machine and is
  never committed), sign, build the APK locally, install. The pack sits in `assets/packs/`
  for that build: `.gitignore` covers that folder and `*.apk` so that "push after every
  commit" cannot take it to GitHub; run `git status` before any commit there, never use
  `git add -f` on it, and remove the folder afterwards. D-140 (6) and (10) do not apply to
  this pack. Stop and report a failed hash or count.

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
