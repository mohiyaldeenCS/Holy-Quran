---
name: implement-requirement
description: The workflow for implementing any product requirement in this app, from its PRD ID (such as RD-02, AU-09 or TF-05) to merged, tested code. Use whenever a task names a requirement ID, a module code or a milestone from the implementation plan.
---

# Implementing a requirement

The PRD decides what is built. This skill is how one requirement becomes merged code
without drifting from it.

## 1. Read the requirement where it is written

```
grep -n "RD-02" docs/prd/PRD.ar.md
```

Read the whole module section in §8 of `docs/prd/PRD.ar.md`: the requirement row, the
notes under the table and the acceptance criteria («معايير القبول»). Then the
sections it leans on: §7 for UX, §9 for anything showing Quran text, §10 for data, §11
for limits. The PRD is in Arabic; quote it in Arabic when you cite it.

Do not work from a summary, a milestone title or memory. If two passages disagree,
stop and ask the owner; do not pick one.

## 2. Check that it may be built now

- **Phase**: the requirement's phase column is the current phase or earlier
  (`docs/PROJECT_STATUS.md`), and that phase is open: the gate before it is met, or
  the owner opened the milestone (`docs/IMPLEMENTATION_PLAN.md`).
- **Source**: every kind of data it shows is `Ready` in `docs/SOURCES.md`. If not, the
  feature is not built; say so and move on (PRD §12.3).
- **Item**: a particular book or recitation is shown only with a complete record in
  `docs/content/RIGHTS_REGISTER.md`.
- **Not deferred or excluded**: PRD §13 and §2.5.
- **Conditional**: if the row says «مشروط», the condition is met and recorded.

## 3. Plan

For anything beyond a small change, get a plan from the `flutter-architect` agent:
files, interfaces, data, tests, task split. Keep the plan as small as the requirement.
Do not add options, settings or abstractions the requirement does not ask for.

## 4. Build

Delegate by layer, one clear brief per task, no two tasks owning the same file
(ownership table in `docs/WORKFLOW.md`):

| Work | Agent |
| --- | --- |
| Domain, repositories, services, packs, database | `data-builder` |
| Widgets, screens, view models, routes, strings | `ui-builder` |
| Playback and audio–text sync | `audio-builder` |
| Generators, pack tools and checks | `content-engineer` |

A brief states: the goal and why; the requirement IDs with the PRD passages; the files
the agent owns; the interfaces it must use or provide; what "done" means; and what to
return.

Build against the real pack where it exists, otherwise against a synthetic pack whose
text is plainly not Quran text.

## 5. Verify, commit, review

1. `dart format .`, `flutter analyze`, `flutter test` — all clean.
2. Each acceptance criterion has a test or recorded evidence. A criterion that needs a
   device, a reviewer or the owner is listed as a pending human check, not as passed.
3. `test-engineer` for gaps and integration tests on critical flows.
4. Commit and push. Reviewers read what is committed.
5. `code-reviewer` on the branch; `identity-auditor` if UI changed. Fix what they
   find in new commits and run the checks again.

## 6. Record

- Commit: `feat(reader): show page-boundary marks in surah mode (RD-06)`. Work with no
  requirement ID names its milestone: `build(ci): add format, analyze and test
  workflow (M0.1)`.
- Pull request description: requirement IDs, the acceptance criteria as a checklist
  with evidence, tests run, screenshots for UI in the four themes, pending human
  checks, what is left.
- A new package, data shape or deviation gets an entry in `docs/DECISIONS.md`.
- Update `docs/PROJECT_STATUS.md` (`session-handoff` skill).

## Partial work is stated as partial

If a requirement is only partly done, say exactly which part in the commit, the pull
request and the status file. Never mark a requirement complete with a criterion
unmet, and never fill a gap with stand-in content to make a screen look finished.
