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
| Fetched | 2026-10-07, CI run 52 (`581fdf7`); again in run 59 (`e8f48f1`, after the review fixes) with the expected SHA-256 pinned |
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

Run 59 rebuilt the pack after the review fixes (values checked against their full
quoted source range, the notice checked for Tanzil and version 1.1): `text.sqlite`,
the manifest and all 114 surah digests came out byte-identical to run 52, and the
suite passed again.

So the M0.3 reader and `QuranText` carry the whole Hafs text unchanged, as far as
Linux layout and bytes can show. Shaping is judged on screen (below).

## Rendering (synthetic text, Linux)

Built in `spike/s1/render/` (commit `b5c1c08`). One paragraph per block holds the
whole pack values side by side and one U+FFFC per mark; ayah markers (the
design-system `AyahMarker`) and page marks are inline placeholders. No character is
added to the text: the gap on each side of a marker is part of the placeholder's
width, the advance of U+0020 in the Quran style measured at run time. Words are
sliced only at stored offsets. 44 tests on a 286-ayah, 4,872-word synthetic surah
read through the real data layer: every word's box centre hits that word; boxes are
one per line and inside their band; `topOf` is monotonic; no overflow at 320, 360
and 412 wide at 2.0x; an ayah sliced at its stored offsets with one word in another
colour has the same width and boxes as unsliced (`WQ-01` colouring).

Findings:

1. **SkParagraph reorders inline placeholders on right-to-left lines** (Flutter
   3.44.7): two markers on one line appear in reverse logical order, with their
   widths; Flutter's `Text.rich` with `WidgetSpan`s does the same, and bidi controls
   do not help. Workaround: every placeholder in a block has the same advance and
   height, and after layout each line's placeholders take its slots from the right
   in logical order. A test pins the engine behaviour so a fix is noticed.
   Consequence for D-071: **a page mark must fit within a marker's advance** (gap,
   marker, gap: 40.6 px at 1.0x).
2. **Glyph ink leaves its line band, downward only.** Amiri Quran's ascent plus
   descent is 2.45 em, above the 2.3 line height. Measured by drawing every third
   line in turn, so ink outside a band is counted against its own line (`bandInk`,
   `c4d9a7b`): on the full-size synthetic text at 360 wide, 2,790 of 22,175 lines
   (1.0x) and 3,552 of 50,161 (2.0x) leave their band, in 111 of 114 surahs, all
   downward (descenders into the line below), at most 7.5 px of a 58 px band (15 px
   of 115 at 2.0x); none upward. An earlier two-row count overstated this. So the
   last line cannot be centred, nor V2's hidden lines cut, by clipping a band: the
   descenders of the line above would be cut or moved. Instead the text from the cut
   on is drawn in transparent ink (colour does not change layout).
3. **Amiri Quran shapes a word differently after the word before it** (across the
   U+0020): a word-initial kaf (U+0643) is about 0.24 em narrower after a word than
   alone, and some words starting with U+062A, U+0629 or U+062B are 1 to 2 px
   narrower. So no line or block may be laid out without the text before it. The
   centred last line is drawn from a second copy of the whole paragraph with the
   text before the cut transparent (`134aad0`, which fixed a last line that wrapped
   when laid out alone), and each V2 block lays out one V1 line before its first
   shown line, hidden (`c4d9a7b`). With that, V2 reproduces V1's line breaks at 320,
   360 and 412 wide, 1.0x and 2.0x, and a word at a block start has V1's width within
   0.01 px (a test finds such a word: 100.33 px with the lead-in, 106.43 px without).
   Each block starts where V1's line holding its page mark starts, which may be
   mid-ayah at a stored word offset; cutting naively at page boundaries would add a
   line break at each one and break the flowing text of D-071. Restoring a saved
   position needs the plan up to that page (layout only).
4. **Page marks** sit inline before the ayah, so text flows past them (D-071).
   Margin marks (`RD-02`) can be placed with `topOf(ayah)`.
5. Marker vertical position: baseline minus half the x-height (OS/2 sxHeight
   433/1000) matches CSS `vertical-align: middle`; Flutter's `middle` is about 9 px
   higher. Highlight boxes are clamped to the line band, since CSS paints over the
   font's content area, taller than the line.
6. Layout cost: walking line starts through `TextPainter` was quadratic; building the
   paragraph directly and binary-searching line numbers fixed it.

Debug figures on Linux at 360 wide, informative only (runs vary 2 to 5 times):

Figures from before `134aad0`; centring now lays a block out two or three times, and
a reviewer measured about 300 ms for V1 at both scales afterwards.

| | 1.0x | 2.0x |
| --- | --- | --- |
| V1 layout, 1,318 / 3,011 lines | 22 to 183 ms | 50 to 125 ms |
| V2 plan, 29 blocks | about 140 ms | about 200 ms |
| V2 block layout, median / max | 5 / 16 ms | 7 / 13 ms |

Choices made by the lead:

- A marker at a line edge keeps its space-wide gap (about 7.3 px at 1.0x), because
  making the gap hang like a space would mean adding a U+0020 of the app's own to
  the paragraph. Shown to the owner with the device APK.
- A page that begins at a surah's first ayah gets no inline mark: there is no
  boundary inside the text (the surah header precedes it).
- M1.2 keeps recolouring, not clipping (finding 2), unless the real text shows no
  line leaving its band.

## Measurements

Pending (tasks T6 and the device run).

## Device protocol (owner, Android, profile APK of D-069)

The APK's launcher (`spike/main.dart`) opens the app, the component gallery and the
three spike screens. Preparation: battery above 50%, battery saver off (note it if
on), Wi-Fi on. Record the phone model, Android version, memory, the refresh-rate
setting and the system font size. Run S1 before S5: S5's "Clear storage" step also
deletes the S1 pack.

1. **Prepare the text.** S1, "Prepare text". Wait for "Verified pack
   spike-tanzil-uthmani v1: 114 surahs, 6236 ayat, text.sqlite efd4f7ed...". A red
   message names only a step, a digest or an HTTP status: copy its words.
2. **Integrity.** "Run integrity" (several minutes). Every problem count should be
   0. "Copy JSON" and send it. Its fingerprints at 360 and 412 wide compare with CI.
3. **Shaping by eye (Read).** Open surahs 1, 2 (top and bottom), 18 and 112 at 1.0x,
   V1, and compare a few lines with a printed mushaf or tanzil.net: marks on the
   right letters and not colliding; no empty boxes; ayah markers in order, right to
   left, each after its ayah; the last line centred. Tap three or four words: the
   highlight covers exactly the word and the address matches. At 2.0x the text
   reflows with nothing cut off. In V2 the line breaks are those of V1 and the
   outlined page-mark slots sit in the flow. Then set the phone's font size to the
   largest: the "System" chip gives the scale at 25 px (the Quran size) and at 14 px;
   Android 14 and later scale large text less than small text, so the two differ.
   Record both, and check that the text reflows. Screenshot anything
   wrong, with the surah number, and no more text than the problem needs.
4. **Text-size change.** Reader, surah 2, "Measure 1.0x to 2.0x", in V1 and in V2.
   Copy the JSON each time.
5. **Scroll test** (`NF-02`). Font size back to default. "Run scroll test" (the
   longest surah, V1 then V2, three runs each at 1500 px/s); do not touch the screen.
   Copy the JSON; each run gives fps and whether its frames could be limited to the
   scroll window (`windowFiltered`).
6. **Cold start** (`NF-01`), ten runs. "Arm and exit" (the longest surah, its middle
   ayah by default). Then Settings, Apps, holyquran, Force stop (needed: the audio
   service can keep the process alive), and open the app from its icon. It opens on
   "S1 cold start" with the steps in ms ending with `savedAyahShown`; check that the
   armed ayah is at the top. Repeat ten times ("Exit for the next run", Force stop,
   launch), then "Copy runs JSON" and "Disarm". Note whether the first run followed
   an install or a reboot.

Send: the JSON of steps 2, 4, 5 and 6; the screenshots and notes of step 3; the
phone details above. Cold start restores in V1 only; a V2 restore needs the plan up
to the saved page (finding 3) and is left to M1.2.
