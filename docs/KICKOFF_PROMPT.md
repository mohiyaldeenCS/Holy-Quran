# Prompts for starting and resuming work

Paste one of these as the first message of a Claude Code session opened on this
repository. They are written for the owner to send; the session answers him in
Arabic.

## 1. First implementing session

```text
You are taking over the implementation of «القرآن الكريم», an Arabic Flutter app for
reading, listening to, studying and memorising the Quran. I am the product owner.
The product was studied and planned from another account of mine. Everything that
work produced is in this repository, and nothing else carries over: the repository
is your only memory of the project.

Repository: https://github.com/mohiyaldeenCS/Holy-Quran (private). Work in its clone,
starting from an up-to-date main branch. If CLAUDE.md or docs/PROJECT_STATUS.md is
missing on main, stop and tell me: the planning documents have not been merged yet.

READ FIRST, before writing any code, in this order:
1. CLAUDE.md
2. docs/PROJECT_STATUS.md
3. docs/WORKFLOW.md
4. docs/prd/PRD.ar.md — the whole document, not a summary. It is long and in Arabic.
   It is the source of truth for what is built: requirement IDs, acceptance criteria,
   phases, deferred features.
5. docs/IMPLEMENTATION_PLAN.md, docs/ARCHITECTURE.md, docs/DESIGN_SYSTEM.md,
   docs/SOURCES.md, docs/DECISIONS.md
6. design/README.md
7. The agents in .claude/agents/ and the five project skills in .claude/skills/
   (session-handoff, implement-requirement, apply-visual-identity,
   quran-text-integrity, ask-owner)
Component sources and identity boards are read later, for each task that needs them.

THE VISUAL IDENTITY is approved and is the design source of truth. Do not redesign it.
- Design system: https://claude.ai/artifact/HLcBx5kyT7DLrnZuyhwDpo
- Identity boards: https://claude.ai/artifact/FVTTx77gMSAyvMQJQRUu6N
The same material is in design/ in the repository, and you build from those files.
The links are for viewing only and may not open from this account. To see the
identity rendered, run design/preview/build.py as design/README.md explains.

HOW I WANT YOU TO WORK
- You are the lead. Give each kind of work to its specialised agent, one clear job
  per agent, then integrate and verify the result yourself.
- Use skills: the project skills, and the official Flutter and Dart skills vendored
  in .claude/skills/.
- Apply the identity exactly: colours, shapes, components, spacing, icons. A screen
  the identity does not draw is built from the same tokens and components. If the
  identity lacks something you need, ask me; do not invent it.
- Follow best practice in code, UI and layering as set out in docs/ARCHITECTURE.md.
- Record every step: a commit per task, pushed; a pull request per milestone; and
  docs/PROJECT_STATUS.md kept current, so that I can switch accounts and continue
  from exactly where the work stopped without redoing anything.
- All repository text, code comments and commit messages are in English. Keep code
  comments few.
- Speak to me in Arabic. When a decision is mine to make, ask me with the
  AskUserQuestion tool, in Arabic, with your recommended option first.
- Never type or alter Quran text. Never generate religious or linguistic content. Do
  not build a feature whose data source is not marked ready.
- Tell me the truth about the state of the work: what passed, what failed, what you
  could not run.

WHAT TO DO NOW
1. Do the reading above.
2. Check the environment (flutter --version, flutter doctor, git, gh) and record it
   in docs/PROJECT_STATUS.md. If Flutter is not available, stop and tell me. The
   repository configures the Dart and Flutter MCP server in .mcp.json; if it is
   waiting for my approval in this account, tell me how to approve it.
3. Tell me in Arabic, briefly: what the app is, which phase we are in, what you will
   build first, and what you need from me.
4. Ask me the kickoff questions K1–K4 from docs/PROJECT_STATUS.md in a single
   AskUserQuestion call.
5. Start milestone M0.1 on its own branch, following docs/IMPLEMENTATION_PLAN.md.

Do not start Phase 1 features before the Phase 0 gate is met. If the documents are
unclear or contradict each other on what to build, what content to use or how it
looks, ask me; do not guess. Engineering contradictions you settle and record, as
CLAUDE.md says.
```

## 2. Every later session, including after switching accounts

```text
Continue the «القرآن الكريم» project in this repository
(https://github.com/mohiyaldeenCS/Holy-Quran).

Use the session-handoff skill: read CLAUDE.md and docs/PROJECT_STATUS.md, check them
against the Git history, open branches and pull requests, and check that Flutter is
available. Then tell me in Arabic, in a few lines, where the project stands and what
you will do in this session, and continue with the first item under "Next actions".

Work as the lead with the agents and skills described in docs/WORKFLOW.md. Commit and
push after every task, and update docs/PROJECT_STATUS.md before you stop. Ask me in
Arabic through AskUserQuestion, with your recommendation, whenever a decision is mine.
```

## 3. Before leaving a session

```text
I am about to switch accounts. Use the session-handoff skill: commit and push
everything worth keeping, bring docs/PROJECT_STATUS.md fully up to date (what is done,
what is half-done and where, the next actions, open questions), push again, and tell
me in Arabic what the next session should start with.
```
