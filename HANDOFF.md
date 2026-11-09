# Handoff — 2026-11-09

For the next lead, on a new account. Nothing else from the earlier sessions survives, and
you do not need to repeat the audit: this file was checked against Git and GitHub when it
was written. `docs/PROJECT_STATUS.md` stays the authority for the project's state; if the
two disagree, Git wins, then the status file. Update this file after every finished step.
Delete it, with the owner's permission, once "In flight" is empty.

## 0. Start here (local lead, 2026-11-09)

The last session ran **locally on the owner's Windows machine** (`D:/projects/Holy-Quran`, Flutter 3.47.9, his phone SM-G998U on `adb`, Python `py -3`), not in the cloud. It ran his test copy end to end, found and fixed three pipeline defects, fetched the KFGQPC Hafs text, built the KFGQPC comparison and the reciter's review page. Since then #98 (records), #91 (P1-35), #99 (recitation drift tool) and #100 (margin-mark rows) are merged, and the records of 2026-11-09 (D-179 to D-182, drift in `RIGHTS_REGISTER.md`) are on `main` through `claude/records-2026-11-09`. The next free decision number is D-183.

**State that is not in Git** (owner's machine, never committed or uploaded):
- `$HOME/holyquran-test-copy/`: `raw/` (Tanzil Uthmani 1.1 fetched without `rub`, sha256 `5ea5cbab…`; metadata `8867c1d8…`), `build.json`, `kfgqpc/` (KFGQPC `UthmanicHafs_v2-0.zip`, MD5/SHA-1 equal to KFGQPC's published values; extracted in `kfgqpc/x/`), `compare/report*.json` (code points only), `review/` (**the reciter's review page**: `review.html` + two fonts, built from `main` `06bb22f`), `screens/` (phone screenshots), `diag/` (diagnostic pulls: delete it), `shot.sh`.
- The phone runs a **debug** build of the test copy (same defines, same data), because the profile rebuild failed for lack of memory on 2026-11-06. Reinstall the profile build with `tools/test_copy/test_copy.sh` when memory allows (the script now opens the pushed folders, D-173).
- `$HOME/holyquran-test-copy/recitations/`: quran-align release 2016-11-24 (`align/`, SHA-1 matching its README), 72 MP3s per recitation (`audio/<folder>/`, `SHA256SUMS`), drift reports (`reports/drift72-*.json`). Rerun: `py -3 tools/packs/pack.py drift --timing … --audio … --edition … --text raw/quran-uthmani.xml --metadata raw/quran-data.xml --report …` (without `-I`, which breaks the `hqpack` import).
- `D:/projects/New folder/ziydia_out/`: the owner's Zaydi extraction, 34 books; book 466 stopped at page 30.

**Waiting on the owner:** the reciter's decisions file from `review/review.html` (D-176). Then: approved encoding patterns become kind (b) rules (`approved_by` the reciter, the date); the owner decides the base text (Tanzil or KFGQPC, D-176 (1)); then the manifest change so pages, juz and quarters come from KFGQPC (D-176 (2)).

**Next, decided by the owner on 2026-11-09 (all three; at most two lanes at a time, in this order):**
1. **Recitations (B0.5): done.** Drift measured (D-179, D-182). Left: the owner's listening check of two recitations; word-index problems at `hafs:10:1` and `hafs:14:1` to look at when the recitation packs are built.
2. **App fixes:** (b) and (c) done (#100, #91). **Left: (a)**, the missing base pack (D-180): its own title and body from the first start, distinct from a failed pack, no empty index.
3. **Zaydi tafsir:** derive the sixteen-code honorific table from the site's font with images for approval (D-140 (7)); then the tafsir pack (pack format v2 `tafsir`, D-110 proposed). The owner finishes book 466.

**Rules learned this session:** every question to the owner through `AskUserQuestion`, in Arabic, recommended option first; D-176 (4): merge any pull request that passes an independent review and CI, and tell him; run long waits as one background command (`until [ "$(gh run view <id> --json status -q .status)" = completed ]; do sleep 60; done`; `gh run watch` once exited early), never polling; API key 2 is out of credit, so start runs with `key=1` until the owner tops it up; the owner's global rules (`~/.claude/CLAUDE.md`): Opus for code and review, Sonnet for mechanical work, at most two lanes, `model` passed explicitly. Agents' spend this session ≈ $35 (largest: #95 $7.10, #97 $10.64).

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
| #90 T1 test copy | **Merged** 2026-11-04 (`cbd7acb`) after its fix (Gradle compiles and refuses release with the test pack, five dry runs; home shows a failed test-copy pack), a re-review (PASS, $0.10) and green CI on the merge with `main`. T1, T2 and T3 are all on `main`: the owner's local build can start (T4, the extra guards and flow test, does not gate it) | none |
| P1-35 build | Built, then the owner's D-171 applied ($1.46). Review ($1.63): CHANGES REQUIRED — the ayah ring was painted over the Quran text's edge letters and diacritics while focused (1,761 pixels); a weakened assertion; the branch's D-171 row (the lead records D-171 instead) | fix: ring under the text with a pixel test, `ui-builder` sonnet, $4, key 2; then goldens, review, merge |
| #92 T4 | **Merged** 2026-11-04 (`e48cd90`) after a review (PASS WITH NITS, $0.23) and green CI. **The test copy is complete; the owner was given the steps of `tools/test_copy/README.md`** | none |
| Owner's local build | **Done** 2026-11-06. #93 (`agent/tanzil-real-files`, $0.87) fixed the two defects his first run found on 2026-11-05 (Tanzil's `quran-data.xml` has no notice comment; `rub=false` turns U+06DE on, Tanzil reads presence); review PASS WITH NITS (opus, run 42080330700), green CI, merged `d294ea2` on the owner's word (D-172 reserved for it, row not yet written). Then on his machine: text re-fetched without `rub` (sha256 `5ea5cbab…`), pack built and verified (114/6236, 77,433 words, 4,379 marks, 30 juz, 240 rub, 604 pages, 15 sajdas), 322 integrity/copy/share tests passed on it, signed, private key deleted; `adb install -r` failed on the old app's signature, so on his prior choice the old app was uninstalled (its data erased) and the profile build installed; pack pushed; packs and keys deleted; tree clean. On the phone the banner «نسخة تجريبية غير معتمدة» shows on home, no pack-failure alert. `$HOME/holyquran-test-copy` keeps only `raw/` and `build.json` | Follow-up for #93's should-fix (dead branches in `options.py` `option_problems`) and nits (three printable helpers, `object` types in `TanzilMetadata`, `agree`-only URL skips the rub check); write the D-172 row; then his device check list |
| Device findings 2026-11-06 | On the phone the copy first showed an empty index, then «نص المصحف لم يجتز التحقق»; the integrity log (read from a temporary **debug** build of the same copy, `run-as`) said `missing` both times. Cause: `adb push` creates `files/test_copy/...` owned by `shell`, mode `drwxrws---`, which the app's uid cannot enter. `chmod 2775` on the three folders fixed it: index (114 surahs, 30 juz, pages 1/2/50/77/106/128), reader, word sheet, ayah toolbar, copy sheet and copy, go-to all work. Findings: (1) `tools/test_copy/test_copy.sh install` must open the pushed folders (`chmod 2775`) after `adb push` — a `content-engineer` task; (2) a missing pack reads as «لم يجتز التحقق» and on first start as an empty index with no alert — the states should differ; (3) the margin label «الجزء ١» overlaps the first word of the first line in the reader — identity audit. **The phone still runs the debug build** (same defines, same data): the profile rebuild failed for lack of memory (paging file; ~21 GB held by idle Gradle/Kotlin daemons); reinstall the profile build when memory allows. Screenshots stay on the owner's machine in `$HOME/holyquran-test-copy/screens`; `diag/` there holds the pulled pack and APK pieces, to delete | (1) #94 **merged** `19f4033` (review PASS WITH NITS, CI green, owner's approval D-176 (4)). (2), (3) not yet sent; profile reinstall; delete `diag/` |
| KFGQPC Hafs text (B0.2, B0.3) | 2026-11-06, under D-174 (1): `qurancomplex.gov.sa` and `download.qurancomplex.gov.sa` do not answer from the owner's machine (port 443 times out; the apex answers with the ministry's `*.moia.gov.sa` certificate, which was not bypassed). Fetched instead from the Internet Archive's capture of 2025-09-01 of the official developer page (`web.archive.org/web/20250901042942id_/https://download.qurancomplex.gov.sa/resources_dev/UthmanicHafs_v2-0.zip`): 10,729,285 bytes, MD5 `cf6841ae…0278` and SHA-1 `36ea5ab0…7ebf` **equal to the values KFGQPC publishes on that page**; SHA-256 `a7b0e559…d72c`. Kept outside Git in `$HOME/holyquran-test-copy/kfgqpc/` (13 files: data as xlsx/csv/json/xml/sql/txt/html, the font `uthmanic_hafs_v20.ttf`, read.me). Not opened | Comparison run 42219026507's sibling **42218954003**: `content-engineer` opus high, $20, key 1, branch `agent/kfgqpc-compare` (D-175 reserved): KFGQPC reader, table of known differences (presentation rules only), code-point report, page/juz check, `kfgqpc-counts`. Measured inventory: KFGQPC 359 code points, Tanzil 69; mark encodings differ (e.g. U+06E1 37,148 only in KFGQPC, U+06DF 3,988 only in Tanzil), so kind (b) rules need the owner and proofreader. Then: run `compare` on the owner's machine, show him the pattern summary |
| KFGQPC comparison (B0.2) | #95 **merged** `f0ee030` ($7.10; review PASS WITH NITS, CI green). Run on the owner's machine (BOM check relaxed in memory: the lead's task text wrongly said the JSON has a BOM): 54,798 undocumented differences in 94 patterns (≈51,500 encoding in 41 patterns, ≈2,900 spaces before pause marks, 355 pause-mark differences, ≈30 rare letters), 44 presentation problems (42 surah-opening quarters without the sign, `15:49`, `2:286`), 56 page and 2 juz differences. Report in `$HOME/holyquran-test-copy/compare/report.json` (code points only, never committed). Owner's answers D-176: reciter reviews first; divisions from KFGQPC; encoding rules approved by the reciter | #96 **merged** `06cb6fa` ($5.04; review PASS WITH NITS, CI green): runs on the real files with no patch — presentation problems 0; 54,797 differences in 93 patterns, 56 page, 2 juz, 2 quarter differences. Review page run **42291128611** (`agent/kfgqpc-review-page`, opus, $15, D-178 reserved), with #96's review notes. Pending human check: the 42 surah-opening quarter starts P-3 takes from Tanzil. Then: build the page on the owner's machine, the reciter reviews, the owner decides the base text, then the manifest change for KFGQPC divisions |
| Reciter's review page (B0.2) | #97 **merged** `06bb22f` ($10.64 + fix $~2; review CHANGES REQUIRED → fixed → PASS WITH NITS; CI green). Built from `main` on the owner's machine: `$HOME/holyquran-test-copy/review/review.html` with both fonts (section A 376 places, B 26 patterns, C 1, D 101 rows incl. 41 surah-opening quarter starts). Holds Quran text: never committed or uploaded. The reciter opens it in a browser, marks each item and saves the decisions file (`holyquran-kfgqpc-review-decisions` v1) | Owner gives it to the reciter (O-16); his decisions file comes back to the lead; approved B/C patterns become kind (b) rules; then the base-text decision (D-176 (1)) and the manifest change for KFGQPC divisions |
| P1-35 audit | Done ($1.46): two must-fix (no keyboard route into the reader's ayahs; the seek track not keyboard-operable), five should-fix (`IntegrityAlert` not a live region, no copy confirmation, no `test/a11y/`, settings headings read twice…), four nits; a ten-task TalkBack protocol for the owner. The owner answered D-168; the lead ruled D-169. Kept in `docs/plans/P1-35_AUDIT.md` | none |
| #89 SH-02 share sizes | **Merged** 2026-11-04 (`0928573`) after the owner approved the images (D-170), a review (PASS WITH NITS, $0.18) and green CI | none |
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
**An agent cannot push a merge of `main` that brings golden images** (agent.yml's guard sees them as committed by the agent): let an agent merge and check, then repeat the same merge from the lead's session with git only and let CI run (#90, 2026-11-04).
**`action_required` CI runs.** Each agent push starts two CI runs: the `workflow_dispatch` check,
which runs, and a `pull_request` run that waits for approval. The dispatch run is the check of
record for the head.
**Spend this session**, by the SDK's estimates: $74.74 for 56 finished runs by 19:00 UTC, summed from the run logs; the caps of the runs out keep the worst case under $100 (the largest single run: #80's last round, $14.63). The owner raised the cap to $150 at about $82.

`main` holds 37 of 40 tasks (18 partial); see the status file. **No app build has real
content yet and none has run on a device since the spike of 2026-10-12.** **Before the first
run on a branch, check it:** `git merge-base --is-ancestor origin/main origin/<branch>`. If
`main` changed `.github/` and the branch lacks it, merge `main` into the branch from your own
session. Decision numbers: D-001 to D-182 are in `docs/DECISIONS.md` (D-073 to D-075 have no row, as on `main` before) (D-172 to D-178 are #93 to #97 and the owner's answers; D-179 to D-182 are the records of 2026-11-09); the next free number is D-183.

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
