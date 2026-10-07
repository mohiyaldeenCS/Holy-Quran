# Approved visual identity

This folder is the **design source of truth**. It is a copy of the two artifacts the
owner approved. The identity is not to be redesigned: no new colours, fonts, logo,
ornaments or component styles. Screens that the identity does not draw are built as
extensions from the same tokens and components (`docs/DESIGN_SYSTEM.md`).

| Folder | What it is | Original |
| --- | --- | --- |
| `design-system/` | «هوية القرآن الكريم»: tokens, 31 components, icons, fonts, usage rules | <https://claude.ai/artifact/HLcBx5kyT7DLrnZuyhwDpo> |
| `identity-boards/` | «الهوية البصرية — القرآن الكريم»: ten boards with the logo, colours, type, system, screens | <https://claude.ai/artifact/FVTTx77gMSAyvMQJQRUu6N> |
| `preview/` | A script that builds offline pages for viewing both | — |

The links open only for accounts the owner has shared them with. Everything needed to
build is in the files here; nothing in this folder is imported by the app.

On 2026-10-07 the implementing session compared this folder with the live artifacts
(design system version `1791056155-311f`, boards version `1791038005-b192`): the ten
boards, `canvas.json`, `tokens.json`, `tokens.css`, `manifest.json`,
`design-system.json`, `README.md`, `api/tokens.md`, `components/src/index.jsx`,
`components/bundle.css`, `components/bundle.js`, `components/index.d.ts` and the six
WOFF2 fonts are byte-identical.

## Viewing the identity

The files do not open usefully as they are: a component's `preview.html` is a
fragment that expects the tokens, React and the component bundle to be loaded
already, and each board asks for a script that is not part of the export and for
fonts from Google Fonts.

```
python3 design/preview/build.py          Windows: py design\preview\build.py
```

This writes `design/preview/out/` (ignored by Git) with an `index.html`, one page per
component preview (the 31 components and a cover) and one per board. Every page loads the tokens, the component bundle and
the identity's own font files from this folder, so it works offline and shows the
exact fonts. Python 3 with the standard library is enough. Nothing in `design/` is
changed.

## `design-system/` — read in this order

1. `README.md` (Arabic): principles, Quran-text rules, tone, colours, fonts, tajweed,
   mushaf elements, search, memorisation, spacing, icons, logo, accessibility. From
   "Consuming this system (generated)" downwards it is written for web tools: its
   paths carry a `project/` prefix that does not exist here, and its fetch
   instructions do not apply. Its index of cards is still a useful list.
2. `api/tokens.md`: every token with its value in the four themes.
3. `components/src/index.jsx` and `components/bundle.css`: the reference
   implementation, and the normative source for every component. Exact structure,
   sizes, states, the markup of every icon (`ICONS`) and the geometry of the mark
   (`Mark`, `StarOutline`) are here. Classes are `qk-*`.
4. `api/components/<Name>.md`: props, parts and examples for one component.
5. `components/<Name>/README.md`: long-form usage notes. `preview.html` beside it is
   the fragment the preview build wraps.

Machine-readable sources for generators: `tokens.json`, `tokens.css`, `manifest.json`,
`design-system.json`, `components/index.d.ts`.

`tokens.json` carries a `sample` field on type styles. It holds illustrative Quran
text; generators ignore it.

### Fonts

`fonts/*.woff2` are the files the identity was built with. Flutter needs TrueType, so
`fonts/ttf/` holds the official builds of the same versions, each with its OFL text.
They were compared with the identity's files on 2026-10-07: same version strings and
glyph counts; Amiri Quran and Reem Kufi match table for table (only the `head`
checksum table differs), and every glyph outline and advance of the four IBM Plex Sans
Arabic weights is identical.

| Family | Role | File in `fonts/ttf/` | Version | SHA-256 |
| --- | --- | --- | --- | --- |
| Amiri Quran | Quran text only (Tanzil Uthmani text) | `AmiriQuran-Regular.ttf` | 1.003 | `e2a47644762d16bdfb6d33e0d8db8c6ff30beae84150ef5a705316bbd829455c` |
| Reem Kufi | Surah names, large titles, app name | `ReemKufi-Variable.ttf` (wght 400–700) | 2.000 | `33ead1986cd48c138c4d906c9e5a6341877268461f97623409a2014de1cd4aa4` |
| IBM Plex Sans Arabic | Everything else | `IBMPlexSansArabic-Regular.ttf` | 1.101 | `6f611412270a132bbac838da9259d4c68569b4175f3b3b8fa3fa36a30b56dab9` |
| | | `IBMPlexSansArabic-Medium.ttf` | 1.101 | `b8363ab9f733dfa4f8e96b8b2102c24b5cf4110fb96d1d3d9a9412f6fb49cf74` |
| | | `IBMPlexSansArabic-SemiBold.ttf` | 1.101 | `597bd5502e5997be4414e4c9c88834b30ff3784250c84f20bce2b20e53ebd467` |
| | | `IBMPlexSansArabic-Bold.ttf` | 1.101 | `691e0c891a38637ae6bbdb69700f8042cb0724a137bee615068ffdb92244f61f` |

Source of the TTF files: <https://github.com/google/fonts> at
`7085eb89a950e85db5b166b7a58d414544b4140c` (`ofl/amiriquran`, `ofl/reemkufi`,
`ofl/ibmplexsansarabic`). All three are under the SIL Open Font License 1.1; the three
`OFL-*.txt` files must ship in the app's licences screen.

Amiri Quran 1.003 is pinned on purpose. The Quran text and its font are one pair: do
not upgrade or swap the font without re-running the full text rendering checks.

### Icons and logo files

- **Icons:** the 26 icon SVGs (`api/assets/Icons.md`) are not copied as files.
  Generate them from the `ICONS` map in `components/src/index.jsx`; do not redraw
  them.
- **Mark:** the geometry is in `Mark` and `StarOutline` in the same file.
- **Logo files:** the 13 files of `api/assets/Logos.md` are in
  `design-system/assets/Logos/`: five marks (`mark-*.svg`), three lockups
  (`lockup-*.svg`) and five app icons (`app-icon*.svg`). They were fetched unchanged
  from the design-system artifact's asset store on 2026-10-07; each SHA-256 below
  equals the one the asset store reports. They are needed for the launcher icon and
  the native launch screen (M1.11). Inside the app the mark is drawn by the `Mark`
  widget, not from these files.

| File | Asset id | SHA-256 |
| --- | --- | --- |
| `mark-paper.svg` | `6b1dd023714028303033eade5421c585` | `0273354ffa30090da03dff445542a31a5ce6381e37b80771f3137dcb12308711` |
| `mark-emerald.svg` | `6991cfbef1568e596f545ec366e17703` | `c26dcbb48dbed887b7c7f3595e86dab5821b68647fe038862c0798e745e7391c` |
| `mark-dark.svg` | `adbbc5f2345b418e1beda3ea106ca06d` | `d48a748ea857e06659bd9e4d71355ab4af316eaad3e05211535d1206b9e636e6` |
| `mark-mono.svg` | `ba06b08e8a989b140e0f1466ce8b781d` | `012b52a30fae1ec61681e390a8866da73b522e86e7d6676be04c1d37c17cf955` |
| `mark-24.svg` | `18790f0be8f1d49760999ae44ecb790b` | `8c1487a90498e46206c64391ec385c4733f9e3a618975689f04d93bcc22c84af` |
| `lockup-horizontal.svg` | `d140cbc7605bb1ee556aad963c9c9599` | `28a6b62164c689b722251e742a5de3bce750eda428742fa6bcff6d6bedc0f626` |
| `lockup-horizontal-emerald.svg` | `e1d8a676aa38c239f85b80e8f68411f4` | `cc5b75f6124cef80314fcaf05ccce81d87414c86f03f093bb015815c0e1d3e14` |
| `lockup-vertical.svg` | `2fc97c889662e10eab381d4b81b7f83a` | `d3ebab38baa116a49748a905dcebc2286d57fe11168c4ecf7bce216e6a354a08` |
| `app-icon.svg` | `5ae503f18e4b20ff795eff879acc02ed` | `ba564365a1ccb436d4e5a548a596af23beea24b6e8c568cf0b19b9297c722ed0` |
| `app-icon-light.svg` | `6de8cfc5d35198634e7cbcb32cc1937c` | `f6441e8d252a0ae90f7a6229908a0bc2fd19a6e0823b68dd208fc2ce473c68c6` |
| `app-icon-dark.svg` | `5ea18fe1d366be1f339bf3b8d606f80c` | `84bc8e7e7a3dd2a8585df38ddbce1ac29f8c7e58034bc1cf678bde62a1d22b3c` |
| `app-icon-mono.svg` | `5884a17db989a0ad3bcae360135be17d` | `182f26ec93f7bb75dc1c7b4412e67940555ae86b7ad527a5b077938d64f6ed74` |
| `app-icon-fullbleed.svg` | `5e92aea1d5b257d31cdd5d1dc106d1f6` | `1ca8495d481dc107b0fe0c86841fe4e390c48fa1ae74ce44edda00d8eec39b9c` |

## `identity-boards/`

Ten boards. Each `.dc.html` file is static HTML with inline styles and inline SVG, so
exact sizes, colours, radii and spacing can be read straight from the markup. To look
at a board, use the preview build above.

| File | Board | Contains |
| --- | --- | --- |
| `Main.dc.html` | الغلاف | Cover |
| `Logo.dc.html` | ١ · الشعار | Mark, full logo forms, app icon, clear space, minimum size, misuse |
| `Colors.dc.html` | ٢ · الألوان | Base colours, four reading themes, tajweed colours, semantic colours, usage ratio |
| `Type.dc.html` | ٣ · الخطوط | Three families, type scale, zoom in surah mode, digits, Quran text rules |
| `System.dc.html` | ٤ · نظام التصميم | Spacing, radius, elevation, motion, buttons, level switch, tags, switches, ayah row, icons, UI levels |
| `Screens.dc.html` | ٥ · الشاشات | Home (simple level), reader on paper with tajweed colours, study view at night |
| `Mushaf.dc.html` | ٦ · عناصر المصحف | Page anatomy, surah header, margin marks, waqf marks, highlights and tajweed inside the text |
| `Screens2.dc.html` | ٧ · شاشات أخرى | Surah index, player with range and repeat, khatma |
| `Share.dc.html` | ٨ · المشاركة والودجات | Share cards, home-screen widgets, splash screen |
| `Search.dc.html` | ٩ · البحث والحفظ | Root search results, ayah context, memorisation session and plan |

`canvas.json` records each board's title, size and position on the canvas.

## Sample text is not content

The Quran text, the tafsir lines, the meanings of waqf marks and the explanations of
tajweed rules shown on the boards and previews are illustrations. Never copy any of
them into code, tests, fixtures or packs. Quran text comes from the verified content
pack only, and explanatory text from its reviewed source (`docs/SOURCES.md`). UI
labels, such as button and tab names, are part of the identity and are used.
