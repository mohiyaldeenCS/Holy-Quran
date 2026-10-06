# Source registry

English working copy of PRD §5.2. It answers one question for every kind of content:
may the app use it, and what must be true before it is shown.

**Rule of the project:** no feature is built on data whose source is not `Ready` here
(PRD §12.3), and nothing religious or linguistic is ever generated to fill a gap.

## Three levels of clearance

| Level | Where | Says |
| --- | --- | --- |
| Source | This file | Whether a kind of content may be used at all: `Ready`, `Verify` or `Deferred` |
| Rights record | `docs/content/RIGHTS_REGISTER.md` | For one book, recitation or data set: what its licence or permission allows, and whether that is complete |
| Pack manifest | Inside each built pack (PRD §9.2) | Source version, hashes, counts, who reviewed it and when |

A feature may be built when its source row is `Ready`. A particular book or
recitation appears in the app only when its rights record is complete and its pack
has passed its checks and review.

## Trust grades (PRD §5.1)

| Grade | Meaning | Shown in the app |
| --- | --- | --- |
| أ (A) | Authoritative body for the mushaf, or a classical text of known authorship | Yes, with the source's name |
| ب (B) | Published scholarly work reviewed by specialists | Yes, with the source's name and version |
| ج (C) | Machine-derived with partial review | After a verification gate and with a visible label; or used as technical data only, such as timing |
| د (D) | Compilation source undisclosed or unverifiable | No |

## Status values

- **Ready** — the source may be used: its licence or permission is in place. Each
  pack built from it still passes its own checks before it ships.
- **Verify** — usable in principle; the verification step in the last column must
  pass first.
- **Deferred** — not used.

## Basis for "Ready" where permission was needed

On 2026-10-07 the owner stated that he holds written, signed permissions from the
rights holders of every source that needed one: KFGQPC (text, fonts, riwayat and
whatever else is needed), the holders of the recitations to be used, the Quranic
Arabic Corpus, MASAQ, and the remaining sources discussed, including all Zaydi-library
content. The papers stay with him. This file records that statement as the basis; it
does not reproduce the permissions. Their exact conditions are checked with the owner
the first time a condition affects the build (see "Conditions to confirm").

## Registry

| # | Data | Source and version | Grade | Coverage | Basis for use | Status | Our verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Hafs text for surah mode and search | [Tanzil](https://tanzil.net/docs/tanzil_project), Uthmani 1.1 | A | 6,236 ayat | CC BY 3.0: verbatim only, credit Tanzil with a link, keep the copyright notice | Ready | Automatic comparison with the KFGQPC text, then human proofreading |
| 2 | Hafs witness text; Warsh, Qalun and five more riwayat with their fonts | [KFGQPC developer platform](https://qurancomplex.gov.sa/techquran/dev), Hafs update 2.0 of 2020-11-16 | A | 8 complete riwayat with page and line per ayah | Owner holds KFGQPC's permission. The page publishes no licence text. | Ready | Published MD5 and SHA-1 checksums |
| 3 | Mushaf page fonts and line layout | KFGQPC fonts; layouts from [QUL](https://qul.tarteel.ai/resources/mushaf-layout) for the 1405H, 1421H and 1441H editions | A fonts, B layout | 604 pages | Fonts belong to KFGQPC, permitted. Layout under QUL's terms. | Ready | First and last word of every line; visual comparison with print |
| 4 | Indexes: juz, hizb, rub, page, sajda, Makki/Madani | Tanzil metadata; page and juz fields in the KFGQPC files | A | Complete | As the texts | Ready | Compare the two sources |
| 5 | Tajweed rule positions | [quran-tajweed](https://github.com/cpfair/quran-tajweed) | C, becomes B after review | Hafs, about 60,000 positions | CC BY 4.0 | Verify | Cross-check with a [second source](https://huggingface.co/datasets/Quran-Lab/quran-tajweed-phonetics) (non-profit licence, fits the app) and review by a certified reciter |
| 6 | Ayah and word timing | [quran-align](https://github.com/cpfair/quran-align); [QUL](https://qul.tarteel.ai/resources) (58 timed recitations); [mp3quran](https://www.mp3quran.net/ar/api) for ayah timing | C, technical | Varies by recitation | quran-align CC BY 4.0; others per provider | Verify | Measure drift on a sample per recitation |
| 7 | Audio recordings | The reciters and producing bodies | n/a | Per recitation | Owner holds the rights holders' permission for the recitations to be used | Ready | SHA-256 per file; one rights record per recitation |
| 8 | Classical tafsirs and al-Sa'di | Texts of al-Tabari, Ibn Kathir, al-Baghawi, al-Jalalayn, al-Sa'di, digitised by [Quranpedia](https://quranpedia.net/dumps?lang=en), release 2026-10-03 | A text, B digitisation | Whole Quran | Digitisation free for use in apps. Protection term of al-Sa'di's tafsir to be checked per country. | Verify | Sample against a critical printed edition |
| 9 | Al-Mukhtasar fi al-Tafsir; al-Siraj fi Gharib al-Quran | Tafsir Center, via [QuranEnc](https://quranenc.com/ar) | A | Whole Quran | Rights reserved by the Center; permission held by the owner. Publish unmodified with source, version and update date. | Ready | Version match |
| 10 | Al-Tafsir al-Muyassar | KFGQPC | A | Whole Quran | Belongs to KFGQPC, permitted | Ready | Sample against print |
| 11 | Roots, lemmas, morphology | [Quranic Arabic Corpus](https://corpus.quran.com/faq.jsp) 0.4 | B (about 99% stated accuracy after two reviewers) | 77,429 words | GPL with a stated non-commercial condition; permission held by the owner; the app is non-profit. Credit the source. | Verify | Link every word to its counterpart in the approved text |
| 12 | Word-level i'rab | [MASAQ](https://data.mendeley.com/datasets/9yvrzxktmr), version 6 of 2024-12-09 | B | Whole Quran: 131k+ morphological entries, 123k syntactic functions | CC BY 3.0 per its paper; permission held by the owner | Verify | Sample reviewed by a linguist |
| 13 | Syntax tree | [EQTB](https://pmc.ncbi.nlm.nih.gov/articles/PMC12361616/), repository [Quranic](https://github.com/NoorBayan/Quranic) | C | Whole Quran nominally; about 40% hand-made, the rest parsed automatically; its authors do not call it a gold standard | MIT | Verify | Independent verification gate (PRD §8.7) |
| 14 | Books of i'rab, asbab al-nuzul, mutashabih | Al-Tibyan (al-'Ukbari), Asbab al-Nuzul (al-Wahidi), al-Muharrar fi Asbab al-Nuzul and others, via Quranpedia | A for classical works | Partial per book | Classical works available; contemporary ones need their publisher | Verify | Sample per book |
| 15 | Repeated phrases | [QUL](https://qul.tarteel.ai/resources/mutashabihat), 5,277 phrases | C, computed, with an approval flag per phrase | Whole Quran | Per provider | Verify | Use approved entries only; recompute locally |
| 16 | Positions of qira'at differences; topics | Quranpedia; [QUL](https://qul.tarteel.ai/resources/ayah-topics) (2,512 topics) | D until the compilation source is disclosed | Unknown | Unspecified | Deferred | Not shown |
| 17 | UI and Quran fonts | Amiri Quran 1.003, Reem Kufi 2.000, IBM Plex Sans Arabic 1.101 | n/a | Complete | SIL OFL 1.1 | Ready | Pinned files and hashes in `design/README.md` |
| 18 | Zaydi tafsir and reference books | [المكتبة الزيدية](https://ziydia.com): 604 books, 39 in tafsir and Quran sciences (27 with text), 17 dictionaries | Set per book with the owner's reviewers | Per book | Site owner's written permission for everything on the site, held by the owner; database not provided, extraction permitted | Ready | Extraction by the owner's tool, completeness check per book, approved honorific table, sample reviewed by the religious reviewer — `docs/content/ZIYDIA_LIBRARY.md` |
| 19 | Meanings of the waqf marks | The appendix of the Madinah mushaf (conventions of marking and waqf marks), reference edition 1421H | A | The seven marks of `WQ-02`; the list is checked against the appendix | Belongs to KFGQPC and falls under its permission to the owner; confirm with him that the appendix text is covered when the pack is built | Verify | Transcribed from the printed appendix, never written from memory, then reviewed by the scholarly reviewer |

Counts: 9 Ready, 9 Verify, 1 Deferred.

Rows that Phase 1 needs and that are not `Ready` yet: 6 (timing, per recitation), 8
(per classical tafsir chosen) and 19 (waqf-mark meanings). They are stream B's work
in Phase 0 (`docs/IMPLEMENTATION_PLAN.md`).

## Rules for handling sources (PRD §5.3, §5.4)

- Every resource is recorded with its version, fetch date, SHA-256 and the licence
  text as its owner published it.
- An aggregator is not a source. What comes through QUL or Quranpedia is attributed
  to its origin, and the aggregator is named as the channel.
- "Unmodified" in the Tanzil and QuranEnc terms is applied literally: no correction
  and no formatting inside the text.
- A contemporary work enters a pack only with written permission from its rights
  holder, even when an aggregator offers it.
- The app is non-profit, so licences limited to non-commercial or non-profit use are
  open to it under their terms. Any revenue added later forces a re-check.
- Updates: Quranpedia publishes what changed since a date, checked monthly; QUL
  e-mails when a downloaded resource changes; the rest are reviewed by hand every
  three months. Any update passes through the whole pipeline (PRD §9).

## Conditions that shape the build

These hold regardless of who granted what.

| Source | Condition | Consequence in code and content |
| --- | --- | --- |
| Tanzil | Verbatim copies only; credit with a link to tanzil.net; the copyright notice stays in every copy and derived file | The notice that ships in the downloaded file is kept verbatim inside the pack. No correction, formatting or normalisation of the text. The sources screen credits Tanzil with the link. |
| QuranEnc, Tafsir Center | Republish unmodified; state source, version and update | Version and update date live in the manifest and the source badge. |
| Quran Foundation API | Terms forbid a prepackaged database and caching beyond one week | Not a text source and not used for offline audio. |
| Quranic Arabic Corpus | GPL plus a non-commercial condition | Ships as its own unmodified pack with attribution. The app must stay non-profit. |
| quran-tajweed, quran-align, MASAQ | Attribution (CC BY) | Credited on the sources screen. |
| Quran-Lab tajweed phonetics | Non-profit use | Used for cross-checking; the app must stay non-profit. |
| EQTB | Not a gold standard | Shown only after its gate, labelled, limited to the reviewed surahs if the gate fails. |
| Fonts | OFL | The three OFL texts ship in the licences screen. Fonts are not renamed or modified. |
| Zaydi Library | Modern editions and contemporary works | Publisher, edition and editor appear in the source badge and sources page. |
| Every recitation | Rights are per recording | A recitation appears in the app only with a complete rights record (stream, host, offline download, attribution). |
| Every aggregator (QUL, Quranpedia) | An aggregator is a channel, not a source | Content is attributed to its origin; the aggregator is named as the distribution channel. |

## Conditions to confirm with the owner when first needed

Ask by naming the source and the condition (decision D-012). None of these block
Phase 0 engineering. Each answer is written into the source's record in
`docs/content/RIGHTS_REGISTER.md`.

| Source | What to confirm | Needed before |
| --- | --- | --- |
| KFGQPC | That the permission covers shipping the page fonts and the Hafs font inside the app and distributing the riwayat texts as downloadable packs; that it covers the appendix text for waqf-mark meanings; any required credit wording | Building the mushaf-pages pack, the KFGQPC Hafs pack and the waqf-marks data |
| Each recitation | Streaming, hosting on the owner's server, offline download, re-encoding or cutting the files, and credit wording | Listing that recitation |
| Tafsir Center | Offline packaging of al-Mukhtasar and al-Siraj inside the app | Building those packs |
| Quranic Arabic Corpus | Distribution of its data inside the app and the credit wording | Phase 3 |
| Zaydi Library | The credit wording the site owner wants; the honorific glyph table | Showing any of its books |

## Updating this file

- A source changes status only with a dated line in the log below and a matching
  change in the PRD's living document.
- Each pack records the source version, fetch date and SHA-256 of the source file
  (PRD §5.3, §9.2).

## Log

| Date | Change |
| --- | --- |
| 2026-10-06 | Registry created from the PRD study: 3 Ready, 6 needing permission, 8 Verify, 1 Deferred. |
| 2026-10-07 | Rows 2, 3, 7, 9, 10 and 18 moved to Ready on the owner's statement that he holds the written permissions. Rows 11 and 12 keep Verify (word linking, linguist review). |
| 2026-10-07 | Row 19 added (meanings of the waqf marks, Verify). `WQ-02` already named this source; the registry had no row for it. Exported with PRD revision 129. |
