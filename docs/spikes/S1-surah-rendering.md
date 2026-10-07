# S1 Surah-mode rendering

Status: **in progress.** The text path is done and has passed on the real text; the
rendering, measurements and device runs are still to come. Question from
`docs/IMPLEMENTATION_PLAN.md`, M0.4: does Amiri Quran shape correctly in Flutter;
word hit-testing and highlight boxes; reflow at 200%; laying out and scrolling a long
surah; cold start to a saved position (`RD-02`, `SY-02`, `NF-01`, `NF-02`). Also the
last-line centring left partial by M0.2, and where the page mark of `RD-06` goes
(D-071: inside the line, the text keeps flowing).

Spike code: `spike/s1/`, removed before the merge (D-068); the last commit that holds
it is named here when the spike closes.

## The real text (D-072)

The Tanzil file (registry row 1) is fetched only on the CI runner (task
`spike-s1-text`) or on the device; it is never committed or logged.

| | |
| --- | --- |
| URL | `https://tanzil.net/pub/download/index.php?quranType=uthmani&outType=xml&marks=true&sajdah=true&rub=true&agree=true` |
| Options | Uthmani, XML, pause marks on, sajda signs on, rub-el-hizb signs on (as in the URL; whether these are the site's defaults is not checked) |
| Fetched | 2026-10-07, CI run 52 (`581fdf7`) |
| SHA-256 | `33f4113df84c1bab0ee2eb69616139fda619bdd56fc163a72532daaf0431bf57` |
| Read | 114 surahs, 6,236 ayat; 82,011 words as runs between U+0020 (spike rule only; B0.4 and D-038 decide the real one) |
| Spike pack | `text.sqlite` `efd4f7ed49a685cdb341cbecae385ade60d16d2506bbdd1dc43ff86385171fc5`; divisions synthetic (a juz every 200 ayat and so on), flagged as such |

The strict reader accepted the file as published: its closed set of elements and
attributes, one notice comment, no entities or CDATA. The planning session decides
which variant B0.2 uses; if it differs, the run is repeated with that URL.

The app's integrity suite ran on the spike pack through the production path:
79 tests passed (one skipped: no pack under `assets/packs/`). It covers:
- verification;
- the header and the exact schema;
- contiguous numbering and the counts against the manifest;
- every surah digest, both in production and independently;
- every name, basmala and ayah equal to its stored bytes;
- no leading BOM;
- word spans that rejoin to the ayah;
- division references;
- the pinned font;
- `QuranText` drawing the stored bytes of every ayah and basmala.

So the M0.3 reader and `QuranText` carry the whole Hafs text unchanged, as far as
Linux layout and bytes can show. Shaping is judged on screen (below).

## Rendering

Pending (task T4).

## Measurements

Pending (tasks T6 and the device run).

## Device protocol

Pending (task T7).
