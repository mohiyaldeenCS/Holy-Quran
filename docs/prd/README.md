# Product requirements

`PRD.ar.md` is the product requirements document for «القرآن الكريم». It is written in
Arabic and is the source of truth for scope, requirement IDs, acceptance criteria,
phases and deferred features. Everything else in `docs/` is derived from it.

## Provenance

| Field | Value |
| --- | --- |
| Living document | <https://claude.ai/artifact/RMrzS7vqiKF2zRED2bE9SL> (owner's planning account) |
| Exported | 2026-10-07, document revision 129 |
| SHA-256 of `PRD.ar.md` | `35efb531b7184ba951db69e1a6ab9fbfadbc211be7dd4eeb4aad37fb4472e9fd` |

The file is the unedited Markdown export. Do not edit it here: changes are made in the
living document by the planning session and re-exported, so the two never drift. If
you find an error or a gap, record it in `docs/PROJECT_STATUS.md` under "Waiting on
the owner". To check that the file is untouched, compare `sha256sum docs/prd/PRD.ar.md`
with the value above; `.gitattributes` keeps the file free of line-ending conversion,
so the hash holds on every platform.

## Reading notes

- Two diagrams do not survive the export and appear as `[embedded content: …]`:
  the content layers (§10.1) and the phase roadmap (§12.1). Both are redrawn in
  `docs/ARCHITECTURE.md` and `docs/IMPLEMENTATION_PLAN.md`.
- Status cells in the source registry (§5.2) read «جاهز», «تحقق مطلوب» or «مؤجل».
  `docs/SOURCES.md` is the English working copy of that registry.
- The PRD quotes a few Quran words and ayat as examples (for instance in `SR-03`).
  They are illustration; never copy them into code, tests or packs.
- The PRD uses Western digits for specifications. The app UI uses Arabic-Indic digits.

## Section map

| § | Content | Use it for |
| --- | --- | --- |
| 1–2 | Summary, vision, users, product limits | Scope questions |
| 4 | Overlaps, conflicts and ambiguities resolved | Why a requirement reads the way it does |
| 5 | Source registry, trust grades, Zaydi library books | What data may be used |
| 6 | Decision per raw requirement, traceability matrix | Mapping client requests to module IDs |
| 7 | App structure, two display modes, UI levels, gestures, identity rules | UX and navigation |
| 8 | Functional requirements in 21 modules with acceptance criteria | Implementation |
| 9 | Quran text integrity and content governance | Rules that override convenience |
| 10 | Data model, Quranic address, packs, offline matrix, sync rules | Architecture |
| 11 | Non-functional requirements `NF-01` … `NF-21` | Budgets and limits |
| 12 | Phases and exit gates | Ordering |
| 13 | Deferred features and what would unlock each | What not to build |
| 14 | Risks, decisions taken, assumptions, open items | Context |
| 15 | Recommendations the client did not ask for | Not requirements until approved |
| 16 | Glossary, references, limits of the study | Terms |

## Module codes

`RD` reader · `NV` navigation · `AU` audio · `SY` audio–text sync · `TJ` tajweed ·
`WQ` waqf marks · `LX` linguistic study · `TF` tafsir · `RW` riwayat · `MT` mutashabihat ·
`SR` search · `UD` bookmarks and notes · `PG` khatma, goals, history · `HF` memorisation ·
`ST` ayah study hub · `SH` copy and share · `OF` offline and resources · `AC` account and sync ·
`WG` home-screen widgets · `AX` accessibility · `LV` UI levels · `NF` non-functional.
