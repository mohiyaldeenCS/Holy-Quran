# Guard allow-lists

The guards in `test/guards/` read what they allow from this folder, one small text
file per entry, so that tasks running in parallel add entries without editing a
shared file (D-114).

**Adding, changing or removing an entry is a reviewed change.** Each entry weakens a
guard on purpose; the pull request that adds it says why, and the reviewer checks
that the decision it names allows it. An entry is never added to make a failing guard
pass without that decision.

## Folders

| Folder | Guard | What an entry allows |
| --- | --- | --- |
| `pack_text/sinks/` | `pack_text_guard_test.dart` | A file that may read `PackText.verbatim` (D-062, D-084). A sink also carries pack text. |
| `pack_text/producers/` | `pack_text_guard_test.dart` | A file that may create a `PackText` with `fromPack`. |
| `pack_text/verifiers/` | `pack_text_guard_test.dart` | A file that may construct a `VerifiedPack`. |
| `pack_text/carriers/` | `pack_text_guard_test.dart` | A file that carries pack text, and therefore may not trim, split, replace or change the case of a string. Listing a file here makes the guard stricter. |
| `imports/non_plugins/` | `import_rules_test.dart` | A package any layer may import; every other package counts as a plugin. |
| `imports/ramps/` | `import_rules_test.dart` | A file that may import `ramps.g.dart`. It must exist and import the ramps. |
| `contrast/` | `contrast_test.dart` | A colour pair the contrast test measures, with its known shortfalls and pinned ratios. |

## Entry format

The file is named `<task>-<what>.txt`, in lower-case letters, digits and hyphens:
`p1-07-reader-paragraph.txt`. Entries migrated from the old constants start with
`m0-`. Lines are UTF-8, end with a newline, and have no blank lines or surrounding
spaces.

Path and package entries:

1. The target: a path from the repository root (`lib/ui/core/widgets/quran_text.dart`),
   a folder ending in `/` that covers every file under it, or a file name pattern
   whose last segment holds `*`, standing for any characters but `/`
   (`lib/data/repositories/*quran_text*.dart`). Under `imports/non_plugins/`, a
   package prefix: `package:<name>/`.
2. `decision: D-xxx`, the decision that allows it.
3. Optional: one sentence saying why.

Contrast entries:

1. `text: <fg> on <bg>` or `non-text: <fg> on <bg>`, with ` over <base>` when the
   background is translucent and composited onto `<base>`. Token names are those of
   the test's colour table. Pairs measured once, as a fixed card design, start with
   `card ` (`card text: gold-400 on emerald-700`).
2. `decision: D-xxx`.
3. Zero or more ratio lines, each `exception: <theme> <ratio>` for a documented
   shortfall or `pinned: <theme> <ratio>` for a passing pair held at its ratio,
   with two decimals (`exception: paper 2.90`); the theme of a card pair is `card`.
4. Optional, last: one sentence saying why.

The threshold follows from the use (text 4.5:1, 7:1 in the `contrast` theme;
non-text 3:1) and is never set by an entry.

## Checks

`test/guards/allow_list.dart` and `test/guards/contrast_pairs.dart` load a folder and
fail, naming the file, on a malformed entry, a path that does not exist or a pattern
that matches no file, a package that does not resolve, and a target or pair listed
twice. A folder that does not exist holds no entries. `allow_list_test.dart` keeps
the `m0-` entries equal to the constants they replaced.
