# How work is done here

The owner asked for four things (decisions D-015 to D-017): work is done by a lead
that delegates to specialised agents and uses skills; every step is recorded in Git,
on GitHub and in the status file, so that another account can continue from the same
point; repository text and commits are in English; and questions come to him in
Arabic with a recommendation.

## Which document decides

| Question | Decided by |
| --- | --- |
| What is built, when, and what counts as done | `docs/prd/PRD.ar.md` |
| How it looks | `design/`, read through `docs/DESIGN_SYSTEM.md` |
| Whether content may be used | `docs/SOURCES.md` and `docs/content/RIGHTS_REGISTER.md` |
| How the code is organised | `docs/ARCHITECTURE.md`, `docs/DECISIONS.md` |
| How the work is run | `CLAUDE.md`, this file, the project skills, the agents |

If two of these disagree on something the owner cares about (scope, content, looks),
ask him. If they disagree on an engineering matter, the lead decides, fixes the
weaker document in the same pull request and records the decision. The vendored
official skills are generic advice; project documents always win over them.

## Roles

The main Claude session is the **lead**. It reads the status, plans the milestone,
delegates, integrates, verifies, commits, pushes, updates the status file and talks
to the owner. Agents do one kind of work each and report back to the lead. Only the
lead commits, pushes and edits `docs/`.

| Agent (`.claude/agents/`) | Job | Files it may edit |
| --- | --- | --- |
| `flutter-architect` | Turns requirements into a file-level plan that fits the architecture | None |
| `data-builder` | Domain models, use cases, repositories, services, pack reading, user database | `lib/domain`, `lib/data`, `lib/utils`, and the tests that mirror them |
| `ui-builder` | Design-system widgets, screens, view models, routes, strings | `lib/ui`, `lib/routing`, `lib/l10n`, and the tests that mirror them |
| `audio-builder` | Playback plan, audio engine, background playback, audio–text sync | The audio files named in its brief, across `lib/domain`, `lib/data` and their tests; native audio settings in `android/` and `ios/` when the brief names them |
| `content-engineer` | Generators for tokens and icons in `tools/gen/`; the pack pipeline in `tools/packs/` when a session works on stream B | `tools/` |
| `test-engineer` | Integration tests, guard tests, the integrity suite, shared fakes; test gaps named in its brief | `integration_test/`, `testing/`, `test/guards`, `test/integrity` |
| `code-reviewer` | Reviews a diff against the rules, the architecture and the requirement | None |
| `identity-auditor` | Audits UI against the identity and accessibility requirements | None |

Files that belong to the lead alone, because every task touches them:
`pubspec.yaml` and `pubspec.lock` (packages are added by the lead, one at a time),
`analysis_options.yaml`, `l10n.yaml`, `lib/main.dart`, `lib/config/`, `assets/`,
`android/`, `ios/`, `.github/`, `.claude/`, `CLAUDE.md`, `README.md`, the root
dotfiles and `docs/`. The lead may hand one of them to an agent for a single task by
naming it in the brief. `design/` is changed by no one, except to add the logo files
it still lacks.

Two tasks running at the same time never own the same file.

## Skills

| Skill | When |
| --- | --- |
| `session-handoff` | Start and end of every session; after each task and milestone |
| `implement-requirement` | Any requirement ID or milestone |
| `apply-visual-identity` | Any UI work |
| `quran-text-integrity` | Anything touching Quran text or sourced content |
| `ask-owner` | A decision that belongs to the owner |
| Official Flutter and Dart skills | The matching task: architecture, routing, localisation, layouts, widget and integration tests, static analysis, coverage, package conflicts |

Skills are files: `.claude/skills/<name>/SKILL.md`. An agent that cannot invoke a
skill by name reads the file.

## The loop for a milestone

1. **Orient.** `session-handoff`: read the status, check it against Git, check the
   environment.
2. **Clear blockers.** Check that the milestone may start: its phase is open and its
   registry rows are `Ready` (`docs/IMPLEMENTATION_PLAN.md`). Put pending owner
   questions that block it to him in one batch (`ask-owner`).
3. **Plan.** `flutter-architect` produces the plan. The lead trims it to the
   requirement and turns it into tasks with the built-in task list.
4. **Build.** One brief per task to the right builder. Tasks that own different files
   may run in parallel; tasks that share a file run one after another.
5. **Check.** Format, analyse, test. `test-engineer` for gaps and critical flows.
6. **Commit and push** the task. Steps 4 to 6 repeat for every task.
7. **Review** what was committed. `code-reviewer` reads a task as soon as it is
   pushed when the task touches Quran text, packs, user data or more than one layer,
   and reads the whole branch before the pull request is merged. `identity-auditor`
   reads every UI change. Fix findings as new commits, re-run the checks.
8. **Close.** Open the pull request with the acceptance checklist, as a draft if the
   work is not finished, so that it has a number. Make the last commit: the status
   file as it should read once merged, with that number. Wait for CI; merge. Nothing
   is committed to `main` afterwards. Report to the owner in Arabic.

Milestones run one at a time. A second branch is opened only for a small fix.

### A brief to an agent contains

- The goal, and why it matters to the user.
- The requirement IDs, with the PRD passages quoted or located.
- The files the agent owns for this task, and those it must not touch.
- Interfaces it must use or provide.
- What "done" means: tests, checks, criteria.
- What to return: files changed, tests run with results, assumptions, open questions.

An agent starts with no memory of the conversation. Put everything it needs in the
brief or point to the file that has it.

## Tasks run by agents in GitHub Actions

Since 2026-10-11 the owner has implementation tasks run by agents inside GitHub
Actions, paid from his API accounts (D-092). The lead session plans, writes the task
texts, reviews the pull requests and keeps the documents; it does not write
application code itself.

- **Workflow.** `.github/workflows/agent.yml`, started by hand from the Actions tab
  (Run workflow) with: the task text, a branch starting with `agent/`, the base branch
  it starts from and its pull request goes to (`main`, or the milestone branch when the
  task needs code that lives only there, such as `spike/`), the key slot
  (1 or 2, one per API account), a budget cap in dollars, the project agent for the
  main thread, the model and the effort. `.github/agent.mjs` runs the task with the
  Claude Agent SDK, loading `CLAUDE.md`, the agents and the skills (`settingSources:
  ["project"]`) under the cap (`maxBudgetUsd`).
- **What the workflow does.** The agent commits on the task branch but never pushes.
  The workflow then refuses commits that hold a key, a golden image or a change under
  `.github/`; runs format, analyze and the tests; pushes the branch; opens a pull
  request (a draft when anything failed) or comments on the open one; and starts
  `ci.yml` with the task `check`, because a pull request opened by the workflow token
  starts no `pull_request` run.
- **Parallel runs.** Two runs, one per key, can work at once. Their tasks must own
  different files. Agents do not edit `docs/PROJECT_STATUS.md` or
  `docs/DECISIONS.md`; their reports say what those files should record, and the lead
  records it.
- **Workflow files stay still while a run is out.** The workflow token has no
  `workflows` permission, and GitHub refuses its push when the branch carries a
  version of a file under `.github/workflows/` that no longer matches the base. So
  while any run started from a base branch is in progress, the lead does not change
  `.github/workflows/` on that base. On 2026-10-11 a change to `ci.yml` on the
  milestone branch made task D's finished push fail, and the run's work was lost.
- **The last message is the report.** Only the last message of each turn reaches the
  pull request. A background task that finishes after the report starts a new turn
  whose short answer replaces it, so task texts tell the agent to wait for its
  background tasks and to make its last message the whole report.
- **A task text** contains everything an agent needs: the goal, the requirement IDs
  and acceptance criteria, the files it may change and those it must not, the project
  agent to use, the checks to run and what to report. It is self-contained: the agent
  has no memory of the lead's session.
- **Review.** The lead (or `code-reviewer`) reviews each pull request against the
  project rules and CI and tells the owner which can be merged. Nothing is merged
  without the owner's approval, unless he has delegated merges to the lead (as he did
  for his absence from 2026-10-11, D-093): then the lead merges a pull request once
  its review and CI pass and reports it.

## Git and GitHub

- `main` is always analysable, tested and runnable. Nothing is committed to it
  directly; it changes only by merging a pull request.
- One branch per milestone or change:
  `feat/m0-1-tooling`, `feat/m1-2-reader-surah`, `fix/…`, `docs/…`, `chore/…`.
  Spike code lives in `spike/` on the milestone branch and is deleted by the last
  code commit before the merge; the page that reports a spike cites the SHA of the
  last commit that holds its code (D-068).
- **Conventional Commits, in English**: `type(scope): summary` in the imperative, at
  most 72 characters. The body says what and why and names the requirement IDs, or
  the milestone where there is no requirement (`M0.1`). No Arabic and no Quran text
  in commit messages.

  | | Values |
  | --- | --- |
  | Types | `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`, `chore`, and `wip` for unfinished work saved before stopping |
  | Scopes, product | `home`, `onboarding`, `settings`, `reader` (RD), `index` (NV), `audio` (AU), `av-sync` (SY), `waqf` (WQ), `word` (LX), `tafsir` (TF), `search` (SR), `bookmarks` (UD), `ayah` (ST), `share` (SH), `resources` (OF), `account` (AC), `a11y` (AX), `levels` (LV) |
  | Scopes, engineering | `ds` (design system), `theme`, `l10n`, `routing`, `domain`, `packs`, `db`, `tools`, `ci`, `deps`, `skills`, `agents`, `status`, `prd`, `design` |

- Commit after each completed task. Push after each commit, and always before
  stopping. Finished work never stays only on one machine.
- One pull request per milestone, description in English: summary; requirement IDs;
  acceptance criteria as a checklist with the test or evidence for each; checks run;
  screenshots in the four themes for UI; human checks still pending; what is left.
  Open it with `gh pr create` where `gh` is installed and signed in; otherwise
  through the GitHub tools the session has, or ask the owner to open it from the
  branch.
- CI (GitHub Actions) runs the format check, `flutter analyze` and `flutter test` on
  every pull request and every push to `main` (D-043). Open the pull request early, as
  a draft, so that a milestone branch is checked from its first pushes. A red run is fixed before anything else.
- Merge with a merge commit, so the task commits stay in the history.
- At a phase gate, tag the merge commit: `phase-0-complete`, `phase-1-complete`.
- Never force-push `main`, rewrite pushed history, or commit secrets, signing keys,
  raw extraction output or build artefacts.

## The status file

`docs/PROJECT_STATUS.md` is updated in the same branch as the work it describes. The
pull request is opened first, so that its number is known; the last commit of the
branch then writes the status as it should read after the merge, including that
number, so that `main` is correct the moment the merge lands. The `session-handoff` skill has the exact procedure. The rule in one
line: a session that stops without updating and pushing the status file has not
finished.

## Two sessions at once

The implementing session (stream A) and the planning session (stream B) work at the
same time, each on its own branch, and talk only through this repository.

- A question for the other session is written where the work is: under "Questions"
  in the milestone plan, or in the document being reviewed. The other session answers
  in a change to that document and says so in the status file.
- Before taking a decision number, fetch `main` and every open pull request, and take
  the number after the highest found in any `docs/DECISIONS.md` or reserved in an
  open plan (D-076).
- Before the last commit of a branch, merge `main` into it if `main` has moved, so
  that the status file and the decisions keep what the other session wrote.

## Documents

| File | Holds | Changes when |
| --- | --- | --- |
| `docs/prd/PRD.ar.md` | Requirements (Arabic, export of the living PRD) | Re-exported by the planning session only |
| `docs/PROJECT_STATUS.md` | Where the work stands | Every session |
| `docs/IMPLEMENTATION_PLAN.md` | Milestones | A milestone is added, split or reordered |
| `docs/ARCHITECTURE.md` | Structure and rules of the code | An architectural decision changes |
| `docs/CONTENT_PACKS.md` | The pack format (written in M0.3) | The format changes |
| `docs/DESIGN_SYSTEM.md` | Identity in Flutter | The mapping changes; never the identity itself |
| `docs/SOURCES.md` | What content may be used | A source changes status |
| `docs/content/` | Rights register; notes on preparing each source | Content work advances |
| `docs/DECISIONS.md` | Decisions with reasons | Any decision |
| `docs/spikes/` | Results of experiments | A spike ends |
| `docs/plans/` | The architect's plan for a milestone, trimmed by the lead, so that another session can continue it | A milestone starts; the plan changes |

## Language

English: code, identifiers, comments, commit messages, pull requests, and the prose
of every document in this repository.

Arabic appears only where it is the subject matter:

- the PRD (`docs/prd/PRD.ar.md`) and the identity files in `design/`;
- UI strings, in `lib/l10n/app_ar.arb` and nowhere else in `lib/`;
- content packs, and synthetic Arabic strings in tests («نص تجريبي»);
- an Arabic term, title, label or name quoted inside an English sentence because the
  term itself is meant: a book title, a UI label, the name of a mark;
- the wording of questions for the owner, kept in the status file so they can be put
  to him as written.

Quran text is not in that list: it is never typed anywhere (`quran-text-integrity`).

## Code style

- Follow Effective Dart and the project's lints; `dart format` decides formatting.
- **Few comments.** Write code that reads without them. A comment earns its place by
  explaining why: a constraint, a source rule, a non-obvious trade-off. No comments
  that restate the code, no banners, no commented-out code, no change history in
  comments. Public APIs in `lib/domain` and repository interfaces get a one-line doc
  comment when the name alone is not enough. A metric constant carries its source
  (`docs/DESIGN_SYSTEM.md`).
- Small files with one responsibility; names that say what a thing is.
- No dead code, unused parameters or options "for later".
- Generated files (`*.g.dart`) are committed and never edited by hand; change the
  generator or its input and regenerate.

## When Flutter is not available

Some cloud sessions cannot reach `pub.dev` or Flutter's download servers. In such a
session do not write application code that you cannot analyse and test. Say so to the
owner, and limit the session to planning, documents, review, or changes verified by
the CI run on a pushed branch. The planning session for this project was one of those
environments.

## When something is wrong

- A check fails: fix the cause. Do not disable the test or the lint.
- A hash, count or text comparison fails: stop and report (`quran-text-integrity`).
- The requirement is unclear or two documents disagree: see "Which document decides".
- You are about to build something the PRD does not ask for: do not; note the idea in
  the status file under "Ideas, not requirements".
