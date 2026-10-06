---
name: quran-text-integrity
description: The rules and checks that keep the Quran text byte-exact and all religious content sourced. Use before writing or reviewing any code, test, fixture, tool or document that reads, displays, searches, copies, shares, exports, highlights, packages or downloads Quran text, tafsir, tajweed, linguistic or audio content.
---

# Quran text integrity

An error in the Quran text is the worst defect this app can ship. The text is
therefore treated as verified read-only data: it enters through a signed content
pack, is checked by SHA-256, and travels to the screen by address without being
touched. These rules come from PRD §9 and from the identity
(`design/design-system/README.md`, "سلامة النص القرآني في التصميم"). They override
convenience, brevity and performance.

## The eight fixed rules (PRD §9.1)

1. **Read-only.** Text files are opened without write access, in a file separate from
   user data.
2. **Byte for byte.** No Unicode normalisation, no cleaning, no re-encoding, anywhere.
3. **Text and font are one pair.** Each text pack names its font. Tanzil Uthmani text
   is drawn with Amiri Quran 1.003; KFGQPC text with KFGQPC's own fonts. Never the
   other way round, never a fallback font.
4. **One source for display.** Reader, search, copy, share card, widget and export all
   fetch the text from the pack by address. None copies it from a widget or cache of
   another.
5. **No remote update of the base text.** The bundled Hafs text changes only with a
   new app release.
6. **No Quran text in sync.** The server schema has no field for it.
7. **No generation.** No religious content passes through a generative model at any
   stage of production or at run time.
8. **No pack without a record.** A pack with no complete entry in the source registry
   is not built.

## What this means when you write code

Never, on a Quran text value:

- call a normaliser (`unorm`, NFC, NFD, NFKC, NFKD) or any package that normalises
  internally;
- `trim`, `replaceAll`, `toLowerCase`, `toUpperCase`, strip diacritics, collapse
  white space, or remove "invisible" characters;
- split it on spaces or into characters with your own logic, or rebuild it from
  words with your own separator;
- decode and re-encode it through another charset;
- attach the basmala to an ayah or cut it off by string operations;
- store a modified copy "for display".

Allowed, and nothing else (`docs/ARCHITECTURE.md`, "Keeping pack text untouched"):

- **Passing the whole value** to `QuranText`.
- **Placing whole values side by side**: consecutive ayat with their markers between
  them; several copied ayat, each with its number.
- **Wrapping a whole value in the fixed copy format** `﴿…﴾ [السورة: الرقم]`. The three
  copy formats of `SH-01` differ only in the reference that follows the text.
- **Slicing at the word offsets stored in the pack**, for per-word hit testing and
  highlights. The slices of an ayah, joined with nothing added, equal the ayah.

Also:

- For highlights, paint behind or under the glyphs using text geometry.
- For copy, share and export, fetch by address; never read the text back from a
  widget (`SH-05`).
- Basmala: shown as its own line after the surah header, except al-Tawba; in
  al-Fatiha it is ayah 1. Tanzil's plain-text download prefixes the basmala to the
  first ayah of each surah, while its XML form carries it as a separate field. The
  pipeline builds the pack from the form with the separate field, so the app receives
  basmala and ayah as two stored values and never separates or joins them itself.

### Search

Display text is never folded. Search matches source-provided search forms stored in
the pack; only the query, and at most a rebuildable app-side index built from those
forms, pass through the one fold function (`docs/ARCHITECTURE.md`, "Search"). Results
are shown from the pack by address.

## Never type Quran text

Not in Dart code, tests, fixtures, golden files' source, ARB files, documentation,
comments, commit messages or pull requests. A typed ayah is unverified text, and
editors, formatters and tools silently change combining marks.

- Tests read text from the pack at test time, or use an obviously synthetic string
  («نص تجريبي للاختبار»).
- Documentation refers to an ayah by address (`hafs:2:255`), not by quoting it.
- The design files in `design/` and the PRD contain sample text for illustration. Do
  not copy from them.
- Before the base pack exists, an experiment that needs real text (spike S1) uses the
  Tanzil file downloaded into the ignored `data/raw/` folder. It is never committed,
  and its SHA-256 is recorded with the result.

## Content other than the Quran text

- Tafsir, word meanings, i'rab, morphology, tajweed positions and explanations, asbab
  al-nuzul, waqf-mark meanings, surah introductions: each comes from a source that is
  `Ready` in `docs/SOURCES.md`, is shown with its source badge (`TF-05`, `LX-11`), and
  is never written, summarised, paraphrased, translated, completed or "improved" by a
  model or by you.
- Their **wording** is never edited. Their **format** may have to be converted by the
  pipeline (HTML to passages, a site font's honorific codes to the phrases they
  draw). Every such step is documented, table-driven and tested, and none guesses.
- A missing value is absent. The field, row or section is hidden. No default, no
  estimate, no "coming soon" text standing in for content. The only sentences shown
  in place of content are the three fixed UI strings of `docs/DESIGN_SYSTEM.md`,
  "When data is missing".
- Explanatory text on the identity boards and in the component previews is
  illustration, not content (`TJ-06`).
- Quran quotations inside a tafsir are part of that book's text, shown in the UI font,
  and are not the reference text (`TF-08`).
- Computed results (repeated phrases, differences between similar ayat) are allowed
  only where PRD §9.6 allows them, and are labelled as computed.

| Algorithms may | Algorithms may not |
| --- | --- |
| Search over a source-provided orthographic form | Correct, format or complete the text |
| Compare two passages and mark the difference, labelled as computed | Generate a tafsir, meaning, i'rab or summary |
| Align audio timing to words, after measuring drift | Order stories or infer relations between concepts |
| Compute a daily portion and statistics | Fill a missing field with an estimated value |

## Checks

The integrity suite (PRD §9.4) is the proof, and it must pass:

- counts and hashes of every text pack;
- displayed, copied, shared and exported text equal to the pack text for every ayah
  (copy: every ayah; share card: the 50 shortest and the 50 longest ayat);
- word slices rejoin to the ayah;
- pack text is unwrapped only by the listed sinks, and no normalisation API is
  imported (the mechanism is decided in M0.3; D-036).

Before proposing a change that touches text, also look for yourself:

```
grep -rnE "normalize|unorm|NFC|NFKC|NFD|NFKD" lib/ tools/
grep -rnE "\.trim\(|replaceAll\(|toLowerCase\(|toUpperCase\(|\.split\(" lib/ | grep -i -E "ayah|quran|text"
```

Each hit must be shown not to touch pack text. This search helps the author; it does
not replace the suite.

## If something does not match

A hash mismatch, a count that differs from the source, an undocumented difference
between the Tanzil and KFGQPC texts, a word with no mapping: **stop**. Do not adjust
the data, the expected value or the test. Report exactly what differs and where. A
confirmed error is corrected at the source and a new pack version is issued; nothing
is patched inside the app (PRD §9.7).
