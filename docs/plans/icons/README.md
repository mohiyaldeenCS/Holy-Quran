# Icon proposals for D-051 (P1-11)

Eight drawings for the Phase 1 needs the identity's 26 icons do not cover
(`docs/DESIGN_SYSTEM.md`, "Icons Phase 1 needs"; D-051, D-059). They are
proposals: none is used in the app until the owner approves it here, one by one.
Approved files are copied byte for byte to `tools/gen/project_icons/` and generated
after the identity's 26 (D-116, task P1-39). Nothing in `design/` changes.

Open `preview.html` in a browser to see the eight beside the identity's 26, at 24 and
48 px, on the `paper` and `night` grounds.

## The rules every drawing follows

From `design/design-system/README.md` and `Icon` and `ICONS` in
`design/design-system/components/src/index.jsx`:

| Rule | How the proposals meet it |
| --- | --- |
| 24 grid (`icon-size`) | `viewBox="0 0 24 24"`; every point lies inside the area the 26 already use (x 2.5 to 21.5, y 3 to 21) |
| Stroke `icon-stroke` 1.75, round ends | Each file opens with the attributes `Icon` sets: `stroke-width="1.75"`, `stroke-linecap="round"`, `stroke-linejoin="round"`, `stroke="currentColor"` |
| No fill except `play` and `pause` (`FILLED` in the reference) | All eight are line icons, as D-051 says; `stop` too (see the question under `stop`) |
| Colour from `currentColor` | No colour in any file; the app paints them like the 26 |
| Directional icons follow the reading direction | "Next" points left, as `next` does; the note's lines align right |
| What the generator reads | Only `path` (`d`), `rect` (`x`, `y`, `width`, `height`, `rx`) and `circle` (`cx`, `cy`, `r`), and only the path commands the 26 already use |

Corners reuse the identity's radius 1.5, as in `context` and `listen`. Dots are the
`h.01` stroke of `alert` and `index`.

`tools/gen/test/project_icon_proposals_test.dart` checks each file: it parses with
the generator's own reader, opens with `Icon`'s attributes, uses only the commands of
the 26, stays inside their area, and appears unchanged in `preview.html`.

## The eight

### `copy`

- **Need:** copy one or more ayat from the ayah toolbar, and a tafsir passage with
  its attribution (§7.4, `SH-01`, `TF-10`).
- **Drawing:** a sheet (rounded rectangle, radius 1.5) in front of a second sheet
  whose hidden part is left out. The gaps of 3 between the two keep them apart at 24
  px.
- **Echoes:** `context` (rounded rectangle, radius 1.5).
- **Owner's decision:** pending.

### `share`

- **Need:** share an ayah through the share card, and a tafsir passage with its
  attribution (§7.4, `SH-02`, `TF-10`).
- **Drawing:** `download` turned round: the same arrowhead, pointing up on a shaft of 10 (11 in `download`), out
  of an open tray with rounded corners.
- **Echoes:** `download`.
- **Owner's decision:** pending.

### `info`

- **Need:** the source badge and the sources row (`LX-11`, `TF-05`).
- **Drawing:** a circle of radius 8 with a short upright stroke and a dot above it.
- **Echoes:** `khatma` (the same circle) and `alert` (the stroke and the dot).
- **Owner's decision:** pending.

### `note`

- **Need:** add or open a note, and the note's margin indicator (`UD-04`, `UD-05`,
  `ST-01`).
- **Drawing:** a page with its corner folded and two lines of writing. Because the
  reading direction is right to left, the fold is on the top left and the lines align
  right, the short one ending where the long one ends.
- **Echoes:** `context` (lines of text) and its radius 1.5.
- **Owner's decision:** pending.

### `delete`

- **Need:** delete the user's saved items, with a grace period to undo (`UD-07`);
  undo stays the word «تراجع».
- **Drawing:** a bin: a lid line, a handle and a body with rounded lower corners,
  with two upright strokes inside, 4 apart like the lines of `context`
  so they stay two lines at 24 px.
- **Echoes:** `minus` (the lid line) and `context` (radius 1.5).
- **Owner's decision:** pending.

### `stop`

- **Need:** stop playback in the full player (`AU-05`).
- **Drawing:** the outline of a square of 12 with corners of radius 1.5, the rounded
  rectangle of `context`. It is a line icon because the identity fills only `play`
  and `pause` (`FILLED` in the reference) and D-051 asks for line icons. Beside the
  filled `play` and `pause` in the full player it will look lighter.
- **Question for the owner** (asked in the P1-11 report; the lead records the
  answer here): keep this line drawing, or allow a third filled icon, the same
  square filled (`<rect x="6" y="6" width="12" height="12" rx="1"/>` with
  `fill="currentColor"`, corners as in `pause`) as an exception to the fill rule.
- **Echoes:** `pause` (a rounded shape on the same centre) and `context` (radius
  1.5).
- **Owner's decision:** pending.

### `nextSurah`

- **Need:** go to the next surah in the full player (`AU-05`).
- **Drawing:** the chevron of `next`, unchanged in size and pointing left, with an
  upright bar just beyond its point: "past the end of this surah".
- **Echoes:** `next`.
- **Owner's decision:** pending.

### `previousSurah`

- **Need:** go to the previous surah in the full player (`AU-05`).
- **Drawing:** the mirror of `nextSurah`: the chevron of `previous`, pointing right,
  with the bar just beyond its point.
- **Echoes:** `previous`.
- **Owner's decision:** pending.
