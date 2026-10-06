---
name: ask-owner
description: How and when to put a question to the product owner — in Arabic, through the AskUserQuestion tool, with a recommended option. Use when a decision is the owner's to make (scope, content, sources, permissions, identity, store accounts, money, anything irreversible) or when documents contradict each other.
---

# Asking the owner

The owner is the client and the product authority. He writes Arabic and reads the
answers on his phone or desktop between other work. A good question costs him ten
seconds; a vague one stalls the project.

## Ask, or decide?

**Ask** when the answer is his to give:

- Scope: adding, dropping or reinterpreting a requirement; anything the PRD defers.
- Religious and linguistic content: which book, which recitation, which wording.
- Sources and permissions: a condition that affects how something is built, stored,
  modified or credited. Name the source and the exact condition (decision D-012).
- The identity: anything the identity does not cover and cannot be composed from it,
  such as a missing icon, and any place where the identity disagrees with itself.
- Opening a Phase 1 milestone before Gate 0 is met.
- Accounts, identifiers, keys, hosting, costs, store listings.
- Anything that cannot be undone: an application id, deleting data, publishing.
- Two documents that contradict each other on scope, content or looks
  (`docs/WORKFLOW.md`, "Which document decides").

**Decide yourself**, and record it in `docs/DECISIONS.md`, when it is an engineering
matter with a conventional answer: file layout, naming, a private helper, a test
approach, a lint rule. Do not ask about what the PRD, `CLAUDE.md` or `docs/` already
answer. Read first.

When unsure whether it is his decision, it probably is if he would be surprised to
learn about it afterwards.

## How

Use the `AskUserQuestion` tool.

- **Arabic**, plain and short. One decision per question.
- Give the context he needs in the question itself, in a sentence: what you are doing
  and what depends on the answer.
- Two to four options. Put **your recommendation first** and end its label with
  «(موصى به)». Use the option's description for the consequence of choosing it.
- The `header` is a short tag of at most 12 characters.
- Options are real alternatives, mutually exclusive, each one something you can act
  on. No "other": the tool adds it.
- At most four questions in one call. Batch what is pending for the current
  milestone; do not interrupt him for each small point.
- Ask before the work that depends on the answer, not after.

Example:

```
question: "معرّف التطبيق في المتجرين لا يمكن تغييره بعد النشر. أيّ معرّف أعتمده قبل أول بناء؟"
header:   "المعرّف"
options:
  - label: "com.<اسمك>.quran (موصى به)"
    description: "معرّف باسم الناشر. أحتاج منك الاسم الذي سيظهر في المتجر."
  - label: "أبقِ المؤقت الآن"
    description: "أواصل بالمعرّف المؤقت com.example.holyquran وأغيّره قبل أول رفع للمتجر."
```

If the tool is not available in the session, ask the same question as plain Arabic
text, options numbered, recommendation first.

## After the answer

1. Act on it.
2. Record it: a decision goes to `docs/DECISIONS.md` with the date, and its open
   entry there (`O-xx`) is closed by naming the new decision. A permission condition
   goes to the item's record in `docs/content/RIGHTS_REGISTER.md`. Where the answer
   changes the product, flag it in `docs/PROJECT_STATUS.md` so the planning session
   can update the PRD's living document.
3. Remove the question from "Waiting on the owner" in the status file.

## If he does not answer

Do not guess on his behalf for anything in the "ask" list. Continue with work that
does not depend on the answer, keep the question in the status file with its Arabic
wording, and raise it again at the start of the next session. For a reversible
engineering default you may proceed with your recommendation and say so plainly.

## Talking to the owner in general

- Reply to him in Arabic. Repository files stay in English.
- Lead with the result: what was finished, what is not, what you need from him.
- Report problems as they are. If something failed, was skipped or is unverified, say
  that first.
