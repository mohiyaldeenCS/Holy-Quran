# S7 Gestures (M0.4 part 2)

Status: built on the milestone branch (tasks C, E, G; D-095 proposed); measured on the
real text in CI; the device session and the usability test are pending. This page is
completed with the device results and D-097.

## Measurements on the real text (CI run 38183752515, `30a4295`)

The D-079 file, the pinned spike pack (`text.sqlite` `ff566f8f…3e24a`), every ayah
laid out by the S1 block at 360 and 412 wide, 1.0x and 2.0x (debug, Linux). Numbers
and addresses only; the full results are the run's `s7-results.json` artifact. All
invariants held: every surah lays out, the targets account for every ayah, word and
mark, every word rect's centre resolves to its word, and every mark box and marker
resolves to itself.

| | 360/1.0x | 360/2.0x | 412/1.0x | 412/2.0x |
| --- | --- | --- | --- | --- |
| Lines | 11,155 | 23,460 | 9,688 | 20,260 |
| Words with no positive rect | 13 | 40 | 17 | 27 |
| Marks without a box (all at a line start) | 82 | 163 | 92 | 145 |
| Words under 48 px wide | 74.4% | 17.3% | 74.3% | (in the artifact) |
| Marks under 48 px wide | 100% | 93.4% | 100% | (in the artifact) |
| Marker size | 26 px | 52 px | 26 px | 52 px |

- No mark that opens an ayah lacks a box on the real text (the synthetic pack's
  ayah-opening case does not occur), and no mark loses its box on the line above a
  line-start mark.
- Word heights are the line band (57.5 px at 1.0x, 115 at 2.0x), so only widths fall
  under 48 (AX-02, M0.4-5).
- Taps at the target centre and 6, 12 and 18 px away (8 directions), 360/1.0x, share
  resolving to the intended target:

  | Rule | Word | Mark | Marker |
  | --- | --- | --- | --- |
  | exact | 100 / 99.98 / 93.7 / 75.9 | 100 / 71.4 / 26.5 / 25.1 | 100 / 100 / 100 / 50 |
  | nearestOnLine | 100 / 100 / 99.7 / 94.0 | 100 / 85.7 / 51.9 / 35.3 | 100 / 100 / 100 / 79.0 |
  | priorityZones | 97.5 / 97.0 / 95.6 / 89.2 | 100 / 99.98 / 99.98 / 99.1 | 100 / 100 / 100 / 99.4 |
  | priorityZonesWithSlop | 99.0 / 98.1 / 96.6 / 90.0 | 100 / 99.98 / 99.98 / 91.4 | 100 / 100 / 100 / 99.4 |

  At 2.0x every rule but `exact` keeps words at 99.8% or more out to 18 px.
- Zones (marks and markers grown to 48 px): at 360/1.0x 1,340 of 10,732 overlap
  (685 mark with marker) and 1,946 word centres fall inside a zone; at 2.0x 2 overlap.
- Resolution time per tap (geometry within 48 px plus the rule), median 37 to 92 µs,
  p95 under 0.2 ms, worst 1.1 ms (debug).

The rule is chosen after the usability test (D-097); the zone rules trade word
accuracy at 1.0x for mark and marker accuracy.

## Device session (2026-10-12)

The owner ran the session with the APK of CI run 38190527706 (`7d12981`) and reported
every check done and ready; no measurements or logs were sent, so this page records no
device numbers. Decision: D-097. The spike code was deleted after
`25d684c`, the last commit that holds it.
