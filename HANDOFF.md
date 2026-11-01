# Handoff — 2026-11-02

Where the work stands, for the next session. `docs/PROJECT_STATUS.md` stays the
authority for the project's state; if the two disagree, Git wins, then the status file.
Update this file after every finished step. Delete it, with the owner's permission, once
"In flight" is empty.

## 1. The plan the owner approved on 2026-11-02

1. Toolchain: move to the latest stable Flutter and packages (#75, D-154).
2. Correct the records (done with #75).
3. Finish what is open: #71 (P1-33), then P1-34.
4. First real run on the owner's phone (below).
5. Close the gaps that have no task (`docs/PROJECT_STATUS.md`, Next actions).
6. P1-35, P1-36, the rest of P1-37.
7. Stream B: everything that does not wait for the owner, plus a precise list of what
   does.

After the APK reaches the owner: give install steps and a short check list, carry on
with step 5 until his results arrive, then reorder by them.

**Conditions of the test pack (his words, in force):** text not yet approved by the
proofreader may be used only on his phone. The app must show that it is an unapproved
copy. The pack is never uploaded to GitHub and never enters a release. When the signing
key is reached, guide him through the steps on his machine.

**Ask him only for:** a package whose latest version needs replacing it with another or
a real change in behaviour; an irreversible act his answers do not cover (deleting
branches or data, rewriting history); a content, rights or publishing decision; the open
question of stand mode's entry point when work reaches it. Decide everything else and
record it. After each step send him two lines: what was done, what is next.

## 2. In flight

- **#75, `chore/upgrade-flutter-3.47.9`:** toolchain upgrade. Needs green CI, a review of
  every golden difference and an independent review before it merges.
- **#71, `agent/p1-33-recitation-downloads`:** see `docs/PROJECT_STATUS.md`.
- **`agent/p1-34-critical-path-tests`:** flow tests, review interrupted, no pull request.
- **`agent/p1-36-performance-budgets`:** only the dependency commit so far.
- **`agent/p1-37-release-readiness`:** two commits, review fixes interrupted.
- **`agent/p1-35-accessibility-pass`:** equal to the old `main`, nothing written.
- Other branches pushed on 2026-11-02 so that nothing is local only:
  `fix/bookmark-restore-nullable` (its commit is on #75) and
  `chore/analysis-exclude-platform-dirs` (superseded by #75).
- `stash@{0}` holds the tree changes of 2026-10-28. The owner said to leave it.

## 3. What happened on 2026-10-29

The session stopped at 08:57 on the owner's clock on `Failed to authenticate. API Error:
403 Request not allowed`. The agents of P1-34's review, P1-35, P1-36 and P1-37 died in
mid-work, and the status file was never updated. Their worktrees lived under the temp
folder, which has since been emptied. Every commit of 2026-10-28 and 2026-10-29 is on
`main` or on a pushed branch. The session's transcripts survive under
`~/.claude/projects/d--projects-Holy-Quran/1ccb67d8-0f86-4a0e-b93d-150b49ce6c2c/`.

## 4. Rules of the lead (the owner's words, still in force)

- **Act without asking for day-to-day work, including commits on the working branch.**
- **Ask him before anything hard to undo:** deleting files or data; `git push --force`
  or rewriting history; publishing or deploying; database migrations; adding major
  dependencies.
- **Merging into `main` is allowed without asking** after an independent review, by an
  agent that did not write the code, and green CI (D-136).
- **Do not use the `fable` model or `max` effort without his permission.**
- **No more than 3–4 agents at a time.** Each parallel code-editing agent gets its own
  git worktree, and each brief is self-contained: goal, files, decisions, constraints,
  done criteria and a short report format.
- **Agent model and effort:** haiku/low for searches and mechanical work; sonnet/medium
  for clearly scoped code; sonnet/high for edge cases and multi-file changes; opus/high
  for architecture, obscure diagnosis and review before acceptance.
- **Check agents' work yourself**, then get an independent `code-reviewer`, plus
  `identity-auditor` for UI, and run the tests after each merge.
- **Collect his questions into one `AskUserQuestion` batch**, in Arabic, with the
  recommended option first and marked «(موصى به)».
- **Reports to him are in Arabic.**
- **Push after every commit.** Nothing stays local only, least of all in a temp worktree:
  a killed session takes uncommitted work with it.

## 5. The check command

Git Bash, on the pinned SDK:

```sh
export PATH=/c/SDK/flutter/bin:$PATH
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden test tools/gen/test
```

On 2026-11-02 with Flutter 3.47.9 on Windows, on #75: analyze clean, 4941 passed,
4 skipped. Goldens run only on `ubuntu-24.04` in CI.

An APK builds locally with `flutter build apk --debug`. This machine needs
`kotlin.incremental=false` in `~/.gradle/gradle.properties` (D-154 (7)).
