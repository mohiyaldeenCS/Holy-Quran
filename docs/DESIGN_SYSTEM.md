# Design system in Flutter

The approved identity lives in `design/` and is the design source of truth. It is
applied as it is. This file explains how its tokens, components and rules map to
Flutter, and how to build a screen the identity does not draw. Start with
`design/README.md` for what each source file is and how to view it.

## Which source decides

The identity has several layers. They agree almost everywhere; where they differ, the
more concrete one wins.

| You are building | Normative source | Then |
| --- | --- | --- |
| One of the 31 components | Its reference implementation: `components/src/index.jsx` and the `qk-*` rules in `components/bundle.css`. Structure, sizes, paddings, radii, colours and states are copied from there. | Its card (`api/components/<Name>.md`) and notes (`components/<Name>/README.md`) for props and usage rules |
| A screen the identity draws | Its board in `design/identity-boards/`, for which components appear, in what order, and the layout between them | The components on it are built from the component reference, not re-measured from the board |
| Something a board draws that is not one of the 31 components (the home header with its app-icon tile, the doors, the «أكمل الاستماع» row, the reader's floating player bar, the share cards, the splash) | The board's markup | It becomes a widget in `lib/ui/core/widgets/` named after what it is, with the board as its cited source. It is not forced into the nearest component |
| A token value | `tokens.json` (readable form: `api/tokens.md`) | — |
| Rules, tone, what a colour or font is for | `design/design-system/README.md` and PRD §7.5 | — |
| A screen the identity does not draw | "Building a screen the identity does not draw" below | — |

What no layer defines is not invented. It is listed and put to the owner
(`ask-owner` skill).

The reference components were written before the rules were summarised, so a few
metrics inside them sit outside the token scales or below the stated minimums. They
are part of the approved identity and are reproduced, not "corrected":

| In the reference | Stated rule it differs from | What the app does |
| --- | --- | --- |
| Action button inside `ResourceRow`: 44 high, 15 px text, radius 14 (`.qk-btn-small`) | Buttons are 52 high with 17 px text | Reproduce it; the hit area is still 48 |
| Chips and sheet tabs 40 high (`Tag`, `ModeChips`, `WordSheet` tabs, tajweed chip, sort control) | Touch targets are 48 | Reproduce the 40 visual; the hit area is 48 (`AX-02`) |
| `SurahHeader` name 26 px, 30 px in the large size | `surah-header` style is 24 px | Component metric. The 24 px style is used where the README names it: player title, page header |
| Text at 11, 14, 16, 19, 23, 26 and 30 px inside components, and 12 px outside the tab bar | The named styles; 13 px is the smallest; `tab-label` 12 px is for the tab bar only | Component metrics, declared in the widget |
| Radii 10, 14, 18, 20 and 26 inside components | Radius scale 8, 12, 16, 24, 28, full | Component metrics |
| The selected word in `WordSheet` is drawn in `accent` | Quran text is `quran-ink` | See "Quran text colour" below |
| Context sheet text 23 px (`.qk-ctx`) | `quran-compact` is 22 px | Component metric of `ContextSheet` |
| `MiniPlayer` title (24 px) and `ContinueCard` title (32 px) set no weight, so they render at 400 | `surah-header` is 600 and `surah-card` is 700 | Component metrics: size and line height as the style, weight 400 |
| Labels in `WordSheet` rows are `ink-muted` on `surface-sunk` (`.qk-sheet-row span`, 5.31:1 on paper) | `ink-muted` is for `ground` and `surface` | Reproduce it in that component only |
| A few fixed brand colours: see "Colour" below | Semantic tokens only | Allowed inside the named components only |

## Ground rules

From the identity (`design/design-system/README.md`) and PRD §7.5. These are
acceptance items for every screen.

1. **Colour comes from tokens, everywhere.** Semantic tokens (`ground`, `surface`,
   `surface-sunk`, `line`, `ink`, `ink-muted`, `primary`, `on-primary`, `accent`,
   `ornament` and the rest). No literal colour in any file outside the generated
   token file.
2. **Quran text only inside `QuranText`**, in the Quran font. No bold, italic,
   letter-spacing, shadow, background image or ornament behind it.
3. **Tafsir** uses the `tafsir` style; linguistic data uses the UI font.
4. **Colour never carries meaning alone.** Every coloured state also has a word, a
   shape or a line: tajweed (line mark and label), recitation (filled marker,
   underline), selection (frame), search match (underline), status (icon and word),
   categories (shape).
5. **The bottom sheet is the container for depth:** word, ayah, context, source. Full
   screens are for the tafsir reader and the study hub only.
6. **Arabic-Indic digits everywhere in the UI** (٠١٢٣٤٥٦٧٨٩), middle dot « · » between
   data items, « ٫ » as decimal separator, « ٪ » for percent.
7. **Short sentences, verb first, calm tone.** No emoji, no exclamation marks, no
   praise or blame. Empty and error states use the identity's phrases
   («تعذّر الاتصال»، «لا توجد علامات بعد»).
8. **The only ornament is the quarter star.** No mosques, crescents or lanterns.
9. **Missing data is not dressed up.** See "When data is missing" below.

## Tokens

Generated, not typed. A generator in `tools/gen/` reads
`design/design-system/tokens.json` and writes two files in `lib/ui/core/theme/`:
`tokens.g.dart` (semantic colours, type, spacing, radius, shadow, size) and
`ramps.g.dart` (the raw colour ramps, imported only inside `lib/ui/core/`). The
generated files are committed, and CI fails if regenerating them changes them.
`design/design-system/api/tokens.md` is the readable reference with every value.

| Group | Tokens | Flutter form |
| --- | --- | --- |
| Colour, semantic | Surfaces, text, fills, lines, brand, player, highlights, status, focus, scrim, tajweed — each with a value per theme | A `ThemeExtension` with one field per token and four instances |
| Colour, ramps | `emerald-*`, `gold-*`, `paper-*`, `ink-*` | Constants in `ramps.g.dart`; a guard test stops feature code importing it |
| Type | 15 named styles in three families. A sixteenth, `quran-compact`, is defined by `QuranText` in `bundle.css` and is written by hand next to the generated ones | A `ThemeExtension` of `TextStyle`s |
| Spacing | `space-1` … `space-7` = 4, 8, 12, 16, 24, 32, 48 | Constants |
| Radius | `sm` 8, `md` 12, `button` 16, `card` 24, `sheet` 28, `full` | Constants |
| Shadow | `shadow-card`, `shadow-sheet`, per theme; none in high contrast | Theme extension |
| Size | `target-min` 48, `button-height` 52, `icon-size` 24, `icon-stroke` 1.75, `ayah-marker` 26 | Constants |
| Motion | fast 120 ms, normal 200 ms, slow 320 ms; ease-out, no bounce. Stated in the identity README and on the System board, not in `tokens.json` | Constants written by hand, once |

Rules for the generator:

- It reads names and values. It ignores the `sample` and `usage` fields: `sample`
  holds illustrative Quran text and must never reach generated code.
- Token aliases (`{paper-100}`) are resolved at generation time.
- CSS pixels map one to one to Flutter logical pixels.

### Colour

Feature code uses semantic tokens only. Inside `lib/ui/core/widgets/` the reference
uses a short list of fixed brand values, and the matching widgets use the same ones:

| Widget | Fixed value in the reference |
| --- | --- |
| `Mark` (emerald, dark variants) | Star `gold-400`; book `paper-100`, or in the dark variant the `ink` of the night theme |
| `Lockup` on emerald | Name in `paper-100` |
| `Button`, tonal variant | Background `gold-100`, text `gold-text-strong` |
| `AyahMarker` while its ayah plays | Number in `emerald-950` on `ornament` |
| `MiniPlayer` | Main button and repeat count in `emerald-950` on `player-accent`; track and speed chip are `paper-100` at 22% and 14% |
| `SessionBar` | Main button in `emerald-950` on `player-accent`; next button `paper-100` at 14% |
| `ContinueCard` | Decorative stars in `gold-400` at 28% |
| `RepeatDots`, `PlanStep` | Current step filled with `gold-100` |
| `Tag`, built-in categories | The category colour is passed in by the caller. The preview uses `emerald-700` for حفظ, `gold-600` for مراجعة, `info` for دراسة and `error` for آيات مهمة. Two of these are ramp steps that do not change with the theme; confirm the set with the owner (O-14) |

Board elements that keep fixed brand colours in every theme, because they are the
brand and not the reading surface:

| Element | Fixed value on the board |
| --- | --- |
| Share card, emerald design | Ground `emerald-700`; ayah `paper-100`; reference line `gold-400` |
| Share cards, paper and night designs | The `paper` and `night` themes' tokens, whatever theme the app is in |
| Splash | Ground `emerald-700` with the emerald lockup |
| App-icon tile in the home header | Tile `emerald-700`, star `gold-400`, book `paper-100` (the emerald `Mark` on a rounded tile) |
| Reader's floating player bar | Drawn on the paper board as `emerald-700` with a `gold-400` button and `emerald-950` glyph: these are `player`, `player-accent` and its fixed glyph colour, so it follows the theme like `MiniPlayer` |

Nothing else reaches a ramp. Any other colour on a board is mapped to its semantic
token by role (see the `apply-visual-identity` skill). Mapping a fixed brand surface
by role would be wrong: the splash as `primary` would turn gold at night.

A text colour is used only on the surfaces its token note names: `ink` on `ground`,
`surface` and `surface-sunk`; `ink-muted`, `primary`, `accent` and `success` on
`ground` and `surface`; `brand-ink` on `ground`. The one place the reference departs
from this is listed in the first table of this file. `warning` colours icons and marks;
warning text is `ink`, on `warning-soft` for a warning card. `ink-disabled` is for
disabled controls only, never for content.

### Themes

| Id | Name | Ground | Ink | Accent gold | When |
| --- | --- | --- | --- | --- | --- |
| `paper` | ورق (default) | `#F8F2E4` | `#1B2A28` | `#8A6212` | Day, most use |
| `night` | ليل | `#0A1413` | `#E8E2D0` | `#D9AE5A` | Darkness |
| `sepia` | سيبيا | `#F0E2C0` | `#3A2A12` | `#7A4E0E` | Long reading |
| `contrast` | تباين عالٍ | `#000000` | `#FFFFFF` | `#FFD54A` | Low vision; 7:1 text, white borders between surfaces |

The values above are for orientation; code takes them from the generated file. The
primary button is emerald on paper and sepia and gold in night: use `primary` and
`on-primary`, never a fixed colour.

`RD-08` asks for an option to follow the system's dark mode. The identity does not say
which theme that maps to. The reading taken here: when the option is on, the app
shows `night` while the system is dark and the user's chosen light theme otherwise.
The owner confirmed it on 2026-10-07 (D-050).

### Type

| Style | Size / line | Weight | Family | Use |
| --- | --- | --- | --- | --- |
| `quran-page` | 25 / 2.3 | 400 | Amiri Quran | Mushaf page and surah mode |
| `quran-ayah` | 34 / 2.3 | 400 | Amiri Quran | Ayah row, study, ayah in the player |
| `quran-focus` | 44 / 2.0 | 400 | Amiri Quran | Selected word, memorisation, share cards |
| `quran-compact` | 22 / 2.2 | 400 | Amiri Quran | Search results, context sheet |
| `display` | 64 / 1.3 | 700 | Reem Kufi | Welcome screens only |
| `surah-card` | 32 / 1.3 | 700 | Reem Kufi | Surah name on cards and widgets |
| `surah-header` | 24 / 1.4 | 600 | Reem Kufi | Player title, page header |
| `app-title` | 22 / 1.4 | 700 | Reem Kufi | App name beside the mark |
| `screen-title` | 28 / 1.4 | 700 | IBM Plex Sans Arabic | Screen title |
| `section-title` | 20 / 1.5 | 600 | IBM Plex Sans Arabic | Section title |
| `tafsir` | 18 / 2.0 | 400 | IBM Plex Sans Arabic | Tafsir and long text; line length about 70 characters at most |
| `body` | 17 / 1.7 | 400 | IBM Plex Sans Arabic | Body |
| `body-strong` | 17 / 1.6 | 600 | IBM Plex Sans Arabic | Buttons, row titles |
| `secondary` | 15 / 1.6 | 400 | IBM Plex Sans Arabic | Metadata, in `ink-muted` |
| `caption` | 13 / 1.5 | 600 | IBM Plex Sans Arabic | Small labels, in `accent` |
| `tab-label` | 12 / 1.4 | 600 | IBM Plex Sans Arabic | Tab bar only |

Rules for new screens: no tappable text below 17; nothing below 13 except the tab
label; Reem Kufi never below 20 and never for a paragraph or a button. All sizes
follow the system text scale up to 200%. In surah mode the text reflows; in page mode
the page is magnified as it is. In page text the last line of a block is centred
(`text-align-last: center` in the reference).

Fonts are the pinned files in `design/design-system/fonts/ttf/` (versions and hashes
in `design/README.md`). They are copied to `assets/fonts/`, and a test compares the
copies' SHA-256 with the pinned values. The app uses all four IBM Plex Sans Arabic
weights: 400, 500, 600 and 700.

Flutter differs from CSS in ways that change how the same numbers look. Settle each
in M0.2 and keep the result in the generated styles:

- **Line height.** CSS puts half of the extra leading above the line and half below.
  Flutter does that only with `TextLeadingDistribution.even`; its default splits the
  leading by the font's ascent and descent. Use `even` so that 25 / 2.3 sits as it
  does on the boards, and compare with the previews.
- **Reem Kufi is a variable font** (weight 400–700). Check on the Flutter version
  pinned in M0.1 that `fontWeight` drives the `wght` axis; if it does not, the
  generated styles set `fontVariations` as well.
- **Golden tests** draw every glyph as a box unless the real fonts are loaded in the
  test. Load them. Text rasterises differently on each system, so goldens belong to
  one platform. They carry the test tag `golden`. With CI enabled, the golden
  platform is the CI runner: a manually started workflow creates or updates the
  images and commits them to the branch, CI compares them on every push, and a
  developer on another system runs `flutter test --exclude-tags golden` before a
  commit. Without CI, the golden platform is the machine recorded in the status
  file, and a session on any other machine excludes the tag and says so.
- **No fallback font for Quran text.** A character missing from the font must fail a
  check in the pipeline, not be drawn from another font on the device.

## Metrics that are not tokens

Where a value equals a token, the code uses the token. The rest are named constants
with a source, in one of two places:

| Kind | Where it lives | Comment on the constant |
| --- | --- | --- |
| Component metric (from `bundle.css` or `index.jsx`), or the metric of a board element built as a widget | Private constants in the widget's file under `lib/ui/core/widgets/` | The selector, for example `.qk-surah-header-name`, or the board file |
| Screen metric (a gap, padding or size read from a board for the layout of a drawn screen) | `lib/ui/core/metrics/<screen>_metrics.dart`, one file per drawn screen | The board file and what was measured |

Rules:

- Under `lib/ui/features/` no colour, font family, font size, radius, duration or
  spacing number is written at all. Features import tokens, widgets and the metrics
  files of `lib/ui/core/`. A guard test enforces this.
- Metrics sit in `lib/ui/core/` and not beside the view because feature folders do
  not import each other, and an extension screen in one feature often follows a
  drawn screen in another.
- A screen the identity does not draw adds no new numbers: it uses tokens, and the
  metrics file of the drawn screen it follows.
- A metric with no source is a deviation. `identity-auditor` checks each constant
  against the file it cites.

## Components

The identity defines 31 components. Each becomes one widget in
`lib/ui/core/widgets/` with the same name, built from the reference implementation,
then its card and notes. Copy sizes and states from those files; do not estimate them
from a picture. To see a component rendered, build the previews
(`design/README.md`).

| Group | Component | Purpose | First needed |
| --- | --- | --- | --- |
| Identity | `Mark` | Quarter star holding an open book; the top dot is dropped under 32 px and the stroke thickens as it shrinks | Phase 0 |
| | `Lockup` | Mark with the name «القرآن الكريم» | Phase 0 |
| | `Icon` | 26 line icons on a 24 grid, stroke 1.75, round ends; only play and pause are filled | Phase 0 |
| Actions | `Button` | Height 52, radius 16, text 17 semibold; primary, outline, tonal and text variants | Phase 0 |
| | `IconButton` | Round, 48; a label is mandatory | Phase 0 |
| Controls | `LevelSwitch` | بسيط · متوسط · دراسة. The identity's only segmented control | Phase 0 |
| | `Tag` | Category tag with shape, colour and name | Phase 1 |
| | `Switch` | 56×32 inside a 48 row | Phase 0 |
| Mushaf | `QuranText` | The only container for Quran text; sizes page, ayah, focus, compact | Phase 0 |
| | `AyahMarker` | Thin `ornament` circle with the ayah number in `accent`; fills while its ayah is recited; the touch target for ayah tools | Phase 0 |
| | `SurahHeader` | Double frame, two quarter stars, name in Reem Kufi 600; information line below | Phase 0 |
| | `AyahRow` | Ayah as a card for lists, search and bookmarks | Phase 1 |
| | `SurahListItem` | Index row: number inside the quarter star, name, Makki/Madani and ayah count, start page | Phase 1 |
| | `TajweedKey` | Key of the eight rules, each with colour, line mark and name | Phase 2 |
| Audio and progress | `ProgressBar` | Fills from the right | Phase 1 |
| | `MiniPlayer` | Emerald player card with five buttons | Phase 1 |
| | `ContinueCard` | «أكمل القراءة» card on the home screen | Phase 1 |
| | `ResourceRow` | Row in the resource manager | Phase 1 |
| Navigation and study | `TabBar` | Five tabs; the active one has a soft emerald pill behind its icon | Phase 0 |
| | `WordSheet` | Bottom sheet for one word; tabs follow the installed packs | Phase 1 |
| Search | `SearchField`, `ModeChips`, `SearchSummary`, `SearchResult`, `ContextSheet` | Search field, search-type chips, summary line, result card, ayah-context sheet | Phase 1 |
| Memorisation | `RepeatDots`, `SessionStatus`, `ConcealedText`, `SessionBar`, `Stepper`, `PlanStep` | Session and plan. `Stepper` (minus, value, plus) is also what the range picker is built from | Phase 2; `Stepper` in Phase 1 |

Helpers defined beside the components and needed in Flutter too: `StarOutline`,
`Tajweed` and `TajweedLine`, `Match` (search highlight), `arabicDigits`, `ayahCount`,
`timesCount`.

Notes on porting:

- **Sample and explanatory text is not ported.** The previews, the boards and
  `TAJWEED_RULES[].desc` carry illustrative ayat and explanations. Text shown in the
  app comes from content packs; rule explanations and waqf-mark meanings come from
  the reviewed sources (`TJ-06`, `WQ-02`). Only UI labels are taken from the
  identity.
- **`ConcealedText`** in the reference splits its string on spaces to place the
  bars. The Flutter widget does not split text: it places the bars from the word
  offsets stored in the pack, and the string stays whole.
- **`WordSheet` tabs** appear in the identity's order: النص، التفسير، الإعراب،
  الصرف، التجويد. Only the tabs whose pack is installed are shown (`LX-01`).
- **Flutter's widget previewer** (the `flutter-add-widget-preview` skill) is a
  convenience while building one widget. The debug gallery screen of M0.2 is the
  shared, reviewed view of the whole set.

### Icons and logo

- The 26 icons are the entries of the `ICONS` map in `components/src/index.jsx`. Each
  entry is SVG markup made of `path`, `rect` and `circle` elements on a 24 grid.
  Generate the icon assets or painter data from that map; do not redraw them. They
  take the current text colour and follow the theme.
- Directional icons follow reading direction: "next" points left. Play does not flip.
- `Mark` and `StarOutline` geometry is in the same file. Stroke by size: 2.2 at 96 and
  above, 3 from 64, 3.6 from 48, 5 from 32, 6.5 below.
- Logo files (marks, lockups, app icons) are in
  `design/design-system/assets/Logos/`, with their hashes in `design/README.md`. The logo is never stretched, rotated, shadowed or placed on a
  colour close to its own. Clear space is half the star's width.

### Quran text colour

Quran text is drawn in `quran-ink`. The identity sets another colour in exactly these
places, and the app follows it there and nowhere else:

| Place | Colour | Source |
| --- | --- | --- |
| Letters under a tajweed rule, when tajweed colours are on (Phase 2) | The rule's `tj-*` token | `.qk-tj-*` |
| The selected word at the top of `WordSheet` | `accent` | `.qk-sheet-word .qk-quran` |
| Concealed words in memorisation | Transparent; the `conceal` bar takes their place | `.qk-conceal` |
| The ayah on a share card (`SH-02`) | Fixed per card design, whatever the app's theme: the emerald card is `paper-100` on `emerald-700`; the paper and night cards use `quran-ink` on `ground` of those two themes | `Share` board |

### Highlights inside Quran text

| State | Tokens | Non-colour signal |
| --- | --- | --- |
| Ayah being recited | `highlight-ayah` | Its marker fills |
| Word being spoken | `highlight-word`, `highlight-word-line` | 2 px underline |
| Selected ayah | `selection`, `selection-line` | Thin frame |
| Search match | `search-match`, `info` | Underline |
| Concealed (memorisation) | `conceal`, `line-strong` | Bar the length of each word; the text stays underneath |

Highlights are painted behind or under the glyphs. They never change the string.

### Tajweed (Phase 2)

Eight rules, each with a colour token, a line mark and a label: `tj-ghunna` dotted
under, `tj-idgham` solid under, `tj-ikhfa` dashed under, `tj-iqlab` double under,
`tj-qalqala` wavy under, `tj-madd-tabii` thin over, `tj-madd-wajib` thick over,
`tj-madd-lazim` two lines over. Colour only the letters the rule falls on. The key
shows only the rules present on the page. This colour assignment is the identity's
decision; do not replace it with the colours of printed tajweed mushafs.

## Contrast

`AX-03` asks for 4.5:1 for text in the four themes and 7:1 in high contrast. The
identity states the same for every text and background pair its token notes name, and
3:1 for marks, borders and rings. The automatic test in M0.2 computes WCAG contrast
from the generated tokens for a fixed list of pairs:

| Pairs | Threshold (`contrast` theme) |
| --- | --- |
| `ink` on `ground`, `surface` and `surface-sunk`; `ink-muted`, `quran-ink`, `primary`, `accent`, `success`, `error` and `info` on `ground` and `surface`; `brand-ink` on `ground` | 4.5 (7) |
| `on-primary` on `primary`; `on-primary-soft` on `primary-soft`; `on-player`, `on-player-muted` and `player-accent` on `player`; `player` on `on-player`; `emerald-950` on `player-accent`; `emerald-950` on `ornament`; `gold-text-strong` on `gold-100`; `ink` on `warning-soft`; `ink-muted` on `surface-sunk` | 4.5 (7) |
| The eight `tj-*` tokens on `ground` and on `surface` | 4.5 (7) |
| `warning`, `ornament`, `line-strong`, `selection-line` and `highlight-word-line` on `ground` and `surface`; `focus` on `ground`, `surface` and `surface-sunk` | 3 |

Computed from `tokens.json` on 2026-10-07, every pair passes except the ones below.
They are written into the test as expected exceptions with their values, so that the
test fails on any new shortfall and also when one of these changes:

| Pair | Ratio | Status |
| --- | --- | --- |
| `ornament` on `ground`, paper | 2.90 | The identity's stated exception: decorative, and the number inside the marker is `accent` |
| `player-accent` on `player`, paper and sepia: the 13 px label of `ContinueCard` (`.qk-continue-label`), and the gold reference line of the emerald share card | 3.90 | Small text below 4.5. Open with the owner (O-12); needed by M1.2 |
| `emerald-950` on `ornament`, sepia: the ayah number inside the filled marker while its ayah is recited (`.qk-ayah-no.is-playing`) | 3.10 | Small text below 4.5. Open with the owner (O-12); needed by M1.10 |
| `tj-ghunna` on `ground`: paper 4.43, sepia 3.85. `tj-iqlab` sepia 4.22. `tj-madd-wajib` sepia 3.99 | 3.85 to 4.43 | Below 4.5. Quran text is 25 px or larger, which WCAG counts as large text (3:1), but neither `AX-03` nor the identity makes that distinction. Open with the owner (O-12); needed before Phase 2 |
| `tj-*` on `surface`, in the tajweed key: sepia `tj-ghunna` 4.24, sepia `tj-madd-wajib` 4.39; every other theme passes (paper's lowest is `tj-ghunna` at 4.79) | 4.24 and 4.39 | Same question, Phase 2 |
| `line` on `ground` and `surface`: the off track of `Switch` (`.qk-switch`), a control boundary that WCAG 2.2 1.4.11 holds to 3:1. Paper 1.35 and 1.45, night 1.54 and 1.36, sepia 1.31 and 1.45 | 1.31 to 1.54 | Below 3:1. Found in M0.2; added to O-12. The widget reproduces the reference meanwhile |
| `surface` on `line`: the off knob of `Switch` (`.qk-switch-knob` on the off track). Paper 1.45, night 1.36, sepia 1.45 | 1.36 to 1.45 | Same as the off track; part of O-12 |

The list is a starting point. When a widget is built, every text colour it draws on
every background it sits on is added to the test (PRD §8.20 asks for an automatic
check of the colour pairs). The test is `test/guards/contrast_test.dart`; it prints
every pair with its ratio.

Pairs that pass with less than 0.1 to spare: paper `emerald-950` on `ornament` 4.52;
sepia `tj-madd-tabii` on `ground` 4.57; paper `tj-madd-wajib` on `ground` 4.59;
`gold-text-strong` on `gold-100` 7.50 against 7 in the contrast theme.

`warning` reaches only 4.22 on `ground` in sepia, which passes for an icon; this is
why warning text is `ink`. `ink-disabled` is not tested: it marks disabled controls,
which the guidelines exempt. Token values and thresholds are never changed in code to
make this test pass.

## Screens

| State (PRD §7.6) | Screens |
| --- | --- |
| Drawn in the identity | Home, reader in surah mode, word sheet, index, player, khatma, search, ayah context, memorisation session and plan, share and copy cards, home-screen widgets, splash |
| Described, not drawn | Page mode, ayah toolbar, waqf-mark card, resource manager |
| New extension | Onboarding, tafsir reader, recitation picker, range picker, queue and playlists, bookmarks, notes and collections, khatma and goal setup, history and statistics, settings, account and sync, sources and licences, pack-integrity alert, study hub, mutashabihat comparison, syntax tree, QR, export, two-page view |

Drawn screens are built to match the boards in `design/identity-boards/`
(`Screens.dc.html`, `Screens2.dc.html`, `Search.dc.html`, `Share.dc.html`,
`Mushaf.dc.html`). The boards are static HTML with inline styles: read sizes, colours,
radii and spacing from the markup. About half of the gaps and paddings on the boards
are off the spacing scale (6, 10, 14, 18, 20, 22, 28); those become screen metrics.

The home board shows khatma, memorisation and the daily goal, which belong to
Phase 2. Until Phase 2 ships, the home screen shows the header and greeting, the
continue-reading card, the «أكمل الاستماع» row and two doors, index and bookmarks
(PRD §7.1, §12.3).

A screen that is described but not drawn (page mode, ayah toolbar, waqf-mark card,
resource manager) is built from the identity's description of it
(`design/design-system/README.md`, the `Mushaf` board, PRD §7.7) with the same
procedure as an extension.

### Building a screen the identity does not draw

1. Find the nearest drawn screen and reuse its structure, spacing rhythm and
   components.
2. Compose only from existing components and tokens. PRD §7.7 lists the extension
   components and what each is built from (source badge, ayah toolbar, tafsir reader,
   recitation row, range picker, storage bar, note editor, history calendar,
   difference mark, two-page view, integrity alert).
3. If something truly cannot be composed, stop and ask the owner (`ask-owner` skill).
   Do not invent a new visual pattern.
4. Write its strings in the identity's tone and add them to the ARB file.
5. Check it in the four themes, at 200% text scale, right to left, with a screen
   reader.
6. Record the screen as an extension in the pull request description, naming the
   drawn screen it follows.

## When data is missing

Nothing is generated or filled in to make a screen look complete.

- A **field, row or section** that has no data for this ayah or word is not shown. In
  the design files unknown values appear in square brackets (`[اسم القارئ]`); in the
  app such a row is hidden (`LX-11`).
- Three cases show a fixed sentence instead, because the requirement or the identity
  says so:
  - A downloaded tafsir with no passage for the ayah shows
    «لا يوجد تفسير لهذه الآية في هذا الكتاب» (acceptance criteria of `TF`).
  - An empty list or a failure shows the identity's sentence
    («لا توجد علامات بعد»، «تعذّر الاتصال»).
  - In the study hub a section whose pack is not downloaded is one line offering the
    download (`ST-03`, Phase 3).
- These sentences are UI strings in the ARB file. They are never content.

## Acceptance checklist for any UI change

- [ ] Colours from semantic tokens; no literal colour, font family or inline number
      in feature code; every metric constant cites its source
- [ ] Built from the design-system widgets; nothing they provide is hand-made
- [ ] Quran text only through `QuranText`, string untouched, colour as specified above
- [ ] Correct in `paper`, `night`, `sepia` and `contrast`
- [ ] Right to left; progress fills from the right; directional icons correct
- [ ] Arabic-Indic digits; correct Arabic plural forms
- [ ] Every hit area at least 48, whatever the visual size
- [ ] Nothing clipped or overlapping at 200% system text scale
- [ ] Every colour-coded state has a word, shape or line
- [ ] Icon buttons labelled; focus ring visible with a keyboard
- [ ] Motion follows "reduce motion"
- [ ] No emoji, no exclamation marks, strings from the ARB file
- [ ] Missing data handled as in "When data is missing"
- [ ] Widget test, and a golden test for a new or changed component

## Open design points

PRD §7.8 lists points still awaiting the designer's confirmation (tabs of the word
sheet by installed pack; the «الوزن» row with no data source; hiding the microphone
until voice search exists; search chips that appear only when their data exists;
tajweed rules with no symbol in the identity; fonts for other riwayat; next and
previous surah living in the full player; the final hand-drawn wordmark). They are
settled during the build with the owner, case by case.

Found while preparing this repository, to be raised with the owner in one batch when
the first of them is needed:

| Point | Needed by |
| --- | --- |
| **Icons the identity does not have.** The set has 26. The ayah toolbar alone needs copy and share, and Phase 1 also needs icons such as note, delete, tag, timer, queue and information. Compile the full list from the Phase 1 requirements in M0.2 and ask who draws them: the designer, or this project following the identity's icon rules, each shown to the owner before use | M0.2 for the list; M1.6 for the first use |
| The category «تفسير» of `UD-01` has no shape or colour in the identity (`Tag` defines four: حفظ، مراجعة، دراسة، آيات مهمة); two of the four preview colours are raw ramp steps that do not follow the theme; and there is no palette for the colour of a user-made category | M1.6 |
| Which theme "follow system dark" switches to and from | M0.2 |
| The Mushaf board shows six waqf marks; `WQ-02` lists seven (it adds السكت). The list is checked against the mushaf's appendix in B0.8 | M1.6 |
| Contrast below 4.5:1 in the identity's own values: the gold label of the continue-reading card, the number inside the filled ayah marker in sepia, and four values of three tajweed colours (see "Contrast") | M1.2 for the card; M1.10 for the marker; Phase 2 for tajweed |
