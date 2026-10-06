---
name: session-handoff
description: Keeps the project resumable across sessions and accounts. Use at the start of every working session, after finishing any task or milestone, before stopping for any reason, and whenever the owner asks where the project stands or says he is switching accounts.
---

# Session handoff

The owner works on this project from more than one account. Nothing a session knows
survives except what is in Git. `docs/PROJECT_STATUS.md` is the single place that says
where the work stands; the commit history is the proof. If the two disagree, the code
and history are right and the status file must be corrected.

## At the start of a session

1. `git status` and `git fetch --all --prune`. If the working tree is dirty, find out
   why before touching anything: it may be the previous session's unfinished work.
2. `git log --oneline -15` and list open branches and pull requests.
3. Read `docs/PROJECT_STATUS.md` in full, then the current milestone in
   `docs/IMPLEMENTATION_PLAN.md`.
4. Check that the status file matches reality: the branch it names exists, the "done"
   items are in the history, the "in progress" item has the commits it claims. Fix the
   file first if it does not.
5. Check the environment: `flutter --version`. If Flutter is missing, say so to the
   owner at once; do not write code that cannot be analysed and tested. If this
   machine differs from the one recorded under "Environment", record it.
6. Tell the owner, in Arabic, in three or four lines: where the project stands, what
   you will do in this session, and any question that blocks it.

## After every completed task

1. Run the checks: `dart format .`, `flutter analyze`, `flutter test`.
2. Commit with an English Conventional Commit message that names the requirement ID,
   or the milestone where there is no requirement.
3. Push the branch.
4. Update `docs/PROJECT_STATUS.md` if the task changed what is done, in progress,
   next or blocked. Commit that with the work or as `docs(status): …`, and push.

A task is not "done" in the status file until its commit is pushed.

## Before stopping, for any reason

Assume the next session knows nothing. Leave the repository so that it can continue
in five minutes:

1. Commit and push everything worth keeping. Unfinished work goes on its branch as a
   `wip(scope): …` commit whose message says what is unfinished; never on `main`.
2. Update `docs/PROJECT_STATUS.md`:
   - **Snapshot**: date, phase, milestone, branch.
   - **In progress**: the exact state. What is half-built, which test is failing and
     why, what you were about to do next. "Nothing" when that is true.
   - **Next actions**: ordered, concrete, each startable without asking anyone.
   - **Waiting on the owner**: every open question with its Arabic wording.
   - **Pending human checks**: criteria waiting for a device, a reviewer or the owner.
   - **Session log**: one line added at the top — date, what was done, branch or pull
     request.
3. Push again and confirm with `git status` that the branch is up to date with its
   remote.
4. Tell the owner in Arabic what was finished, what is half-done and where it is, and
   what the next session will start with.

## At the end of a milestone

1. `code-reviewer` has reported "ready to merge" on the committed branch;
   `identity-auditor` has reported "conforms" for UI changes.
2. Open the pull request, so that it has a number. Its description lists the
   requirement IDs and, for each acceptance criterion, the test or evidence that
   proves it, or names it as a pending human check.
3. The **last commit on the branch** updates the status file to what will be true
   once the branch is merged: the milestone under "Done" with its pull request
   number, the next milestone set, "In progress" cleared, pending human checks
   listed. Push it.
4. Wait for CI to be green, then merge with a merge commit. Nothing is committed to
   `main` afterwards. If you cannot open or merge the pull request from your
   session, push the branch and tell the owner exactly what to click.
5. At a phase gate, record the gate evidence in the status file before merging and
   create the tag `phase-N-complete` on the merge commit.

## Writing the status file

- English, plain, specific. File paths, branch names, commit hashes, test names.
- Facts only. "Implemented, tests pass" and "implemented, not yet run" are different
  statements; write the true one.
- Keep it current rather than long. Finished detail belongs in the session log and the
  Git history, not in the top sections.
- Never delete an open question because it is old. It leaves only when answered, and
  the answer goes to `docs/DECISIONS.md`.
