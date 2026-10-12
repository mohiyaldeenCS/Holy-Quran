# S4 Home-screen widget, Android (M0.4 part 2)

Status: built on the milestone branch (tasks B, D, H; D-094 proposed); the fit
measured on the real text in CI; the device session is pending. Completed with the
device results and D-096.

## Fit on the real text (CI run 38183752515, `30a4295`)

Every one of the 6,236 ayat of the pinned spike pack fitted with `fitQuranSize` into
the face's ayah box (4x2: 364 x 170, box 333 x 117; 2x2: 170 x 170, box 139 x 117),
from 28 down to 22 (`QuranText.card`, line height 2.2). Invariants held (counts add
up; no ayah fits the 2x2 face better than the 4x2).

| Face | 28 | 27 | 26 | 25 | 24 | 23 | 22 | None |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4x2 | 1,933 | 74 | 2,077 | 136 | 147 | 155 | 152 | 1,562 |
| 2x2 | 256 | 41 | 1,295 | 90 | 84 | 89 | 81 | 4,300 |

- Both faces: 1,936 ayat; the 4x2 only: 2,738; neither: 1,562 (25%). WG-03 skips
  those; the reviewed list for Phase 2 is drawn from the 4,674 that fit the 4x2 face.
- Surah 2 alone has 159 ayat that fit neither face; the full per-surah table is in
  the run's `s4-results.json` artifact.
- At line height 2.0 (the board's) two lines would fit at 28 where 2.2 needs 26
  (M0.4-9).

## Device session (2026-10-12)

The owner ran the session with the APK of CI run 38190527706 (`7d12981`) and reported
every check done and ready; no measurements or logs were sent, so this page records no
device numbers. Decision: D-096. The spike code was deleted after
`25d684c`, the last commit that holds it.
