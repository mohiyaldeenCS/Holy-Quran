---
name: apply-visual-identity
description: How to build or change any screen, widget, theme, icon, text style or UI string in this app so that it follows the approved visual identity exactly. Use before writing or reviewing anything under lib/ui, when adding a screen the identity does not draw, and when unsure which colour, size, font or component applies.
---

# Applying the visual identity

The identity is approved and closed. It is not a starting point for taste: colours,
fonts, logo, ornaments, components and tone are reproduced as specified, and a screen
the identity does not draw is assembled from its existing parts. The owner made
conformance an acceptance condition for every screen.

`docs/DESIGN_SYSTEM.md` is the full reference. This skill is the procedure.

## Where the truth is

| You are building | Normative source |
| --- | --- |
| One of the 31 components | `design/design-system/components/src/index.jsx` and the `qk-*` rules in `components/bundle.css`; then its card `api/components/<Name>.md` and notes `components/<Name>/README.md` |
| A screen the identity draws | Its board in `design/identity-boards/`, for composition and layout. Components on it come from the component reference, not from measuring the board |
| Something on a board that is not one of the 31 components (home header, doors, reader's player bar, share cards, splash) | The board's markup. Build it as its own widget in `lib/ui/core/widgets/`; do not force it into the nearest component |
| A token value | `design/design-system/tokens.json`; readable form `api/tokens.md` |
| Rules, tone, what a colour or font is for | `design/design-system/README.md`, PRD §7.5 |
| Icon and mark shapes | `ICONS`, `Mark`, `StarOutline` in `components/src/index.jsx` |

Read the source for the thing you are building. A value you did not read is a guess.
To see it rendered, run `python3 design/preview/build.py` and open
`design/preview/out/index.html`.

## Procedure

1. **Identify** what you are building: a design-system component, a drawn screen, a
   described-but-not-drawn screen, or an extension (table in `docs/DESIGN_SYSTEM.md`).
2. **Read** its sources from the table above.
3. **Compose** from the existing design-system widgets. If the widget you need is
   missing from `lib/ui/core/widgets/`, build it there first, from its reference
   implementation, with a golden test; then use it.
4. **Colours** come from the generated theme, by semantic name (`surface`,
   `ink-muted`, `primary`). Never a literal.
5. **Sizes, gaps, radii and text sizes**: use the token when the value equals one.
   Otherwise declare a named constant with its source, in the place the next section
   says. Never a design number anywhere under `lib/ui/features/`.
6. **Write strings** in `lib/l10n/app_ar.arb`: short, verb first, calm; no emoji, no
   exclamation marks. Numbers go through the Arabic-Indic digit helper; counts use
   the Arabic plural forms.
7. **Check** in `paper`, `night`, `sepia` and `contrast`; at 200% text scale; right to
   left; with a screen reader. Go through the checklist in `docs/DESIGN_SYSTEM.md`.

## Values that are not tokens

The reference components and the boards use many values outside the token scales
(text at 14 or 16 px, radii of 14 or 20, gaps of 6, 10, 14, 20). They are part of the
identity. Reproduce them; do not round them to the nearest token.

| The value comes from | Declare it | Comment on it |
| --- | --- | --- |
| A component's CSS or JSX, or a board element built as a widget | As a private constant in that widget's file in `lib/ui/core/widgets/` | The selector, e.g. `.qk-surah-header-name`, or the board file |
| A board, for the layout of a drawn screen | In `lib/ui/core/metrics/<screen>_metrics.dart` | The board file and what was measured |
| Nowhere: you need it for a screen the identity does not draw | Do not add it. Use tokens and the metrics file of the drawn screen you follow | — |

The stated minimums (buttons 52 high, no tappable text under 17, nothing under 13
except the tab label, Reem Kufi from 20 up) are rules for composing new screens. A
reference component that goes below one of them is still reproduced as it is, and its
hit area is at least 48 whatever its visual size.

## Mapping a colour from a board to a token

Look the value up in `api/tokens.md`. Examples: `#F8F2E4` as a screen background is
`ground`; `#FFFBF2` as a card is `surface`; `#0E5A52` as a button is `primary`, as the
player surface is `player`; `#8A6212` as small gold text is `accent`; `#B8862B` as the
ayah-marker ring is `ornament`; `#DDD2B8` as a hairline is `line`. Choose by role, not
by matching the hex alone: the same value can belong to several roles that diverge in
other themes.

Raw ramp steps (`emerald-950`, `gold-100`, `paper-100`) are used only inside the
widgets listed under "Colour" in `docs/DESIGN_SYSTEM.md`. The same section lists the
brand surfaces that keep fixed colours in every theme (share cards, splash, the
app-icon tile); do not map those by role. If a colour on a board matches no token,
do not add a literal and do not invent a token. Report it to the lead.

## Quran text

Only inside `QuranText`, in the Quran font, as the exact string from the pack. No
weight, slant, spacing, shadow or background ornament. Its colour is `quran-ink`,
except in the four places the identity sets another one: tajweed letters, the
selected word in the word sheet (`accent`), concealed words in memorisation, and the
fixed designs of the share cards (`docs/DESIGN_SYSTEM.md`, "Quran text colour").
Highlights are painted behind or under the glyphs. See the `quran-text-integrity`
skill.

## What is not ported from `design/`

The previews and boards contain sample ayat, tafsir lines, meanings of waqf marks and
explanations of tajweed rules. They illustrate the layout. None of it is copied into
the app: text comes from content packs and reviewed sources. UI labels (tab names,
button names, the identity's empty and error sentences) are part of the identity and
are used.

## A screen the identity does not draw

1. Start from the nearest drawn screen: same header pattern, spacing rhythm, card and
   sheet usage.
2. Use only existing components and tokens. PRD §7.7 says what each extension
   component is built from.
3. Depth goes in a bottom sheet. Full screens are for the tafsir reader and the study
   hub.
4. If it cannot be composed from what exists, stop and ask the owner. Do not introduce
   a new colour, shape, ornament, icon, illustration or animation style. An icon the
   identity lacks is such a case (`docs/DESIGN_SYSTEM.md`, "Open design points").
5. Note in the pull request that the screen is an extension and which drawn screen it
   follows.

## When data is missing

A field, row or section without data is hidden; nothing stands in for it. Three cases
show a fixed UI sentence instead: a downloaded tafsir with no passage for the ayah,
the identity's empty and error states, and the study hub's one-line download offer
(`docs/DESIGN_SYSTEM.md`, "When data is missing").

## Things that are always wrong

- `Color(0xFF…)` or `Colors.…` anywhere outside the generated token file.
- A font family name, or a numeric font size, radius, gap or duration, anywhere
  under `lib/ui/features/`.
- A metric constant with no source in its comment.
- Material default looks left in place: default ripple colours, default `AppBar`,
  default buttons, Material icons where the identity has its own.
- A status shown by colour alone.
- A hit area under 48.
- A progress bar filling from the left; "next" pointing right.
- Western digits in the UI.
- Emoji, exclamation marks, praise or blame in a string.
- A placeholder value where data is missing.
- Sample text from `design/` used as content.
