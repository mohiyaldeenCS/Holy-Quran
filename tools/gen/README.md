# Design-token and icon generator

Turns the approved identity into committed Dart, so no token or icon is typed by
hand (D-025). The output is read by the theme and the core widgets.

## Run

From the repository root:

```
dart run tools/gen/bin/generate.dart           write the outputs that changed
dart run tools/gen/bin/generate.dart --check   write nothing; exit 1 and list stale outputs
dart run tools/gen/bin/generate.dart --help
```

Exit codes: `0` done or current, `1` `--check` found stale outputs (listed on
stdout), `64` unknown argument, `65` a source the generator cannot convert (the
reason is on stderr; nothing is written). The script finds the repository root from
its own path, so the working directory does not matter. It needs `dart` (the one
running it, or the one on the PATH under `flutter test`) to format the output.

## Inputs

Read only, from `design/design-system/`:

| File | What is read |
| --- | --- |
| `tokens.json` | Colour themes (`id`), colour tokens (`name`, `value`), type `fonts` (`family`, `weight`), `families`, styles (`name`, `fontSize`, `lineHeight`, `fontWeight`), `spacing`, `radius`, `shadow`, `size` (`name`, `value`) |
| `components/src/index.jsx` | The `ICONS` map, the `FILLED` set and the `BOOK` path of `Mark` |
| `components/index.d.ts` | The `IconName` type, checked against the keys of `ICONS` |
| `tools/gen/project_icons/*.svg` | The eight owner-approved project icons (D-051, D-128), copied byte for byte from `docs/plans/icons/` |

`sample` and `usage` in `tokens.json` are accepted as known fields and never read:
`sample` holds illustrative Quran text. Theme names and group names (Arabic) are not
read either. Every output must be ASCII, so nothing Arabic can reach it.

## Outputs

| File | Holds |
| --- | --- |
| `lib/ui/core/theme/tokens.g.dart` | `AppColors` and `AppShadows` (theme extensions: one instance per theme, `byId`, `copyWith`, `lerp`), `AppFonts`, `AppTextStyles`, `AppSpacing`, `AppRadius`, `AppSizes` |
| `lib/ui/core/theme/ramps.g.dart` | `Ramps`: every colour token whose value is a literal, not a theme map or an alias |
| `lib/ui/core/widgets/icon_paths.g.dart` | `enum IconName` in `ICONS` order and then the project icons, `isIconFilled`, `buildIconPath` (24 grid), `buildMarkBookPath` (120 grid) |

Each file starts with a header naming its sources and this command. Never edit them;
change the source in `design/` (only with the owner's approval) and re-run.

## Conversions

Each one is fixed and tested; anything that does not fit stops the generator.

- **Names:** token names in camelCase (`surface-sunk` → `surfaceSunk`,
  `space-1` → `space1`). An icon named after a member every Dart enum has gets the
  suffix `Icon`: `index` → `IconName.indexIcon`.
- **Aliases** (`{paper-100}`) are resolved per theme, through other aliases. An unknown
  alias, a cycle, a theme map without one of the themes or with an unknown theme id
  stops the generator.
- **Colours:** `#RRGGBB` → `Color(0xFFRRGGBB)`; `rgba(r,g,b,a)` →
  `Color.from(alpha: a, red: r / 255, …)`, so the alpha is exact and not rounded to
  eight bits. Other forms stop the generator.
- **Shadows:** CSS `x y blur colour` → `BoxShadow`, with
  `blurRadius = (blur / 2 - 0.5) / 0.57735` so Flutter's Gaussian (sigma
  `r * 0.57735 + 0.5`) equals the CSS one (sigma `blur / 2`). `none` → no shadow.
  Spread, inset or several shadows stop the generator.
- **Fonts:** a family's Flutter name is the first quoted name of its stack in
  `families`, which must have a font in `fonts`. Later quoted names that are other
  families become `fontFamilyFallback`; the generic keywords `serif`, `sans-serif` and
  `system-ui` are dropped. The `quran` family may have no fallback.
- **Type:** px → logical pixels, `lineHeight` → `height`, `letterSpacing: 0`,
  `TextLeadingDistribution.even` (the CSS half-leading). A weight the family's font
  files do not cover stops the generator. No colour is set.
- **Icons:** each `ICONS` entry is self-closing `path` (`d`), `rect` (`x`, `y`,
  `width`, `height`, `rx`) and `circle` (`cx`, `cy`, `r`) elements; any other element
  or attribute stops the generator. Path data is converted with `package:path_parsing`
  (arcs and short forms become cubics), rects become `addRRect` and circles
  `addOval`. All elements of an icon go into one `Path`. Coordinates are rounded to
  four decimals: `path_parsing` computes arcs in single precision with `sin`/`cos`,
  whose last digits differ between platforms, and the output must be the same bytes
  everywhere.
- **Project icons:** the files of `tools/gen/project_icons/` are appended to `IconName` after the identity's 26, in the fixed order of `projectIconNames` (copy, delete, info, nextSurah, note, previousSurah, share, stop). Each must have the frame the `Icon` component gives a line icon and the same shapes as above; all are line icons. A missing file, a file not in the list (not approved) or another frame stops the generator.
- **Formatting:** every output goes through `dart format` as if it were at its target
  path, so the package's language version applies.

## Freshness in CI

`--check` regenerates in memory and compares bytes with the committed files. CI runs
the tests in `tools/gen/test`, whose `generator_test.dart` runs `--check` on the
repository and fails when an output is stale; a step running
`dart run tools/gen/bin/generate.dart --check` does the same on its own.

## Tests

```
flutter test tools/gen/test
```

Unit tests on synthetic sources (`test/synthetic_sources.dart`) for colours, shadows,
alias resolution and its errors, ignored fields, fonts, icon extraction and its errors,
`--check` and the exit codes; tests on the real sources for the 26 icons, the filled
pair, determinism and the absence of Arabic text; and a compile check that imports the
three outputs and uses them.
