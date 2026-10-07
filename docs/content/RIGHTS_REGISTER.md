# Rights register

One record per source, and one per book and per recitation, saying what its licence
or permission allows. `docs/SOURCES.md` says whether a kind of content may be used;
this file says what may be done with each item. It is task B0.1 of the plan and is
filled in with the owner.

The signed permissions themselves stay with the owner and are not copied here. A
record holds only what is needed to build correctly: the scope, the conditions and
the credit wording, as the owner reads them from the paper.

**Rule:** a book or a recitation appears in the app only when its record is
`Complete`. A field marked `To confirm` is asked of the owner by naming the source
and the condition (decision D-012); it is never assumed.

## What a record holds

| Field | Meaning |
| --- | --- |
| Item | The source, book, recitation or data set |
| Rights holder | Who granted the licence or permission |
| Basis | A public licence by name, or "written permission held by the owner" with its date if he gives one |
| Bundle | May the files ship inside the app? |
| Host | May they be served from the owner's server? |
| Offline | May the user download them for offline use? |
| Convert | May the format be changed (packaging, re-encoding, cutting audio by ayah)? The wording of a text is never changed in any case |
| Export | May the content appear in a file the user exports (`ST-05`)? |
| Credit | The exact credit line to show in the source badge and on the sources screen |
| Limits | Territory, expiry, non-commercial or other conditions |
| Status | `Complete` when every field above is known; otherwise `Open`, with what is missing |

## Sources under a public licence

Nothing to ask of anyone; the obligations come from the licence text. The cells below
are what the study recorded. A row becomes `Complete` when the licence text has been
read in full from the file that ships with the source and stored beside the source
file (B0.1, B0.2), as `docs/SOURCES.md` requires.

| Item | Licence | Bundle | Host | Offline | Convert | Export | Credit and limits | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tanzil Uthmani text 1.1 and metadata | CC BY 3.0 with Tanzil's own terms | Yes | Yes | Yes | Packaging only; the text stays verbatim | Yes | Credit Tanzil with a link to tanzil.net; the copyright notice of the downloaded file stays in every copy | Open: licence text to be stored |
| quran-tajweed | CC BY 4.0 | Yes | Yes | Yes | Yes | Yes | Attribution | Open: licence text to be stored |
| quran-align timing | CC BY 4.0 | Yes | Yes | Yes | Yes | n/a | Attribution | Open: licence text to be stored |
| EQTB syntax trees | MIT | Yes | Yes | Yes | Yes | Yes | Licence notice | Open: licence text to be stored |
| Amiri Quran, Reem Kufi, IBM Plex Sans Arabic | SIL OFL 1.1 | Yes | Yes | Yes | No renaming or modification | n/a | The OFL text of each family ships in the licences screen | Complete |
| Quran-Lab tajweed phonetics | Its dataset licence, non-profit use | Not shipped: used for cross-checking only | — | — | — | — | The app must stay non-profit | Open: licence text to be stored |
| QUL resources (layouts, timing, phrases) | Per resource, as QUL states for each | To confirm per resource when it is fetched | | | | | Attributed to the origin; QUL named as the channel | Open |
| Quranpedia digitisations | Free for use in apps, as Quranpedia states | To confirm per book when it is fetched | | | | | Attributed to the origin; Quranpedia named as the channel | Open |

## Sources under a written permission held by the owner

The scope column is the owner's statement of 2026-10-07 (2026-10-06 for the Zaydi
Library). The other fields are `To confirm` until he has read them from the paper.

| Item | Rights holder | Scope as stated | Bundle | Host | Offline | Convert | Export | Credit | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Hafs text, riwayat texts, fonts, page fonts | KFGQPC | Text, fonts, riwayat and whatever else is needed | To confirm | To confirm | To confirm | To confirm | To confirm | To confirm | Open |
| Al-Tafsir al-Muyassar | KFGQPC | Covered by the same permission | To confirm | To confirm | To confirm | To confirm | To confirm | To confirm | Open |
| Appendix of the Madinah mushaf (waqf-mark meanings) | KFGQPC | To confirm that the permission covers it | | | | | | | Open |
| Al-Mukhtasar fi al-Tafsir, al-Siraj fi Gharib al-Quran | Tafsir Center | Permission held | To confirm | To confirm | To confirm | Unmodified, with source, version and update date | To confirm | To confirm | Open |
| Quranic Arabic Corpus 0.4 | Its authors | Permission held | To confirm | To confirm | To confirm | Unmodified pack | To confirm | To confirm | Open |
| MASAQ 6 | Its authors | Permission held; the data set is also published under CC BY 3.0 according to its paper | To confirm | To confirm | To confirm | To confirm | To confirm | To confirm | Open |
| Everything published on ziydia.com | The site owner | Everything on the site, including contemporary works. The database is not provided; taking the text from the website is permitted | To confirm | To confirm | To confirm | To confirm | To confirm | To confirm | Open |

## Recitations

Empty until the owner chooses the Phase 1 recitations (O-04). One row each.

| Reciter | Riwaya and style | Rights holder | File source | Stream | Host | Offline | Cut or re-encode | Credit | Timing source and measured drift | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | | |

## Books

One row per book that is to ship. The Zaydi-library candidates are listed in
`docs/content/ZIYDIA_LIBRARY.md`, with the steps each must pass. Publisher, edition
and editor are part of the credit line.

| Book | Source | Publisher, edition, editor | Rights record | Extraction | Honorific table applied | Ayah linking reviewed | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| تفسير غريب القرآن — الإمام زيد بن علي (183) | Zaydi Library | الدار العالمية، الأولى، 1412 هـ - 1992 م | Under the site-wide record above | Complete, checked | No | Linked by the tool, not reviewed | Open |
| تفسير الإمام الهادي يحيى بن الحسين (471) | Zaydi Library | See the library notes | Under the site-wide record above | Complete, checked | No | Partly linked by the tool, not reviewed | Open |
| تفسير غريب القرآن — الإمام المهدي العياني (473) | Zaydi Library | See the library notes | Under the site-wide record above | Complete, checked | No | Partly linked by the tool, not reviewed | Open |
| التيسير في التفسير (514) | Zaydi Library | See the library notes | Under the site-wide record above | Complete, checked | No | Linked by the tool, not reviewed | Open |
| شافي العليل في شرح الخمسمائة آية (737) | Zaydi Library | Not stated on the site | Under the site-wide record above | Complete, checked | No | No | Open |
| الناسخ والمنسوخ من القرآن الكريم (165) | Zaydi Library | See the library notes | Under the site-wide record above | Complete, checked | No | No | Open |
| التبيان في الناسخ والمنسوخ (276) | Zaydi Library | See the library notes | Under the site-wide record above | Complete, checked | No | Partly linked by the tool, not reviewed | Open |
| مسائل نافع بن الأزرق (440) | Zaydi Library | See the library notes | Under the site-wide record above | Complete, checked | No | Linked by the tool, not reviewed | Open |

The general tafsirs of PRD §8.8 are added here if the owner keeps them (O-06).

## Log

| Date | Change |
| --- | --- |
| 2026-10-07 | Ayah linking built for books 473 and 440 as well. Books 737 and 165 cannot be linked to ayat from what they print. No link has been reviewed. |
| 2026-10-07 | Ayah linking built for books 183, 514, 276 and 471 (`docs/content/ZIYDIA_LIBRARY.md`). No link has been reviewed. |
| 2026-10-07 | Register created with what is known. No permission paper has been read by the planning session; every permission-based record is open. |
