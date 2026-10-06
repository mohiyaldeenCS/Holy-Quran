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

### Not in this folder yet

The 26 icon SVGs and 13 logo SVGs (`api/assets/Icons.md`, `api/assets/Logos.md`) live in
the artifact's asset store, which the planning session could not reach.

- **Icons:** not needed as files. Generate them from the `ICONS` map in
  `components/src/index.jsx`; do not redraw them.
- **Mark:** the geometry is in `Mark` and `StarOutline` in the same file.
- **Logo files:** five marks (`mark-*.svg`), three lockups (`lockup-*.svg`) and five
  app icons (`app-icon*.svg`). They are needed for the launcher icon and the native
  launch screen. If the Artifact tool is available in your session, fetch the 13
  files with the ids listed in `api/assets/Logos.md` and commit them to
  `design-system/assets/Logos/`. Otherwise ask the owner to export them from the
  design-system artifact. As a last resort the same drawings are inline SVG on the
  Logo board (`identity-boards/Logo.dc.html`): the mark and the four app-icon
  variants.

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
