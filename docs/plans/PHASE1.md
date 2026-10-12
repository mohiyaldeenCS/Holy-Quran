# Phase 1 — plan as parallel agent tasks

Written by the lead on 2026-10-12, against `main` at `98f954e`. The owner opened
Phase 1 that day, after his device session of M0.4, before Gate 0's content items
are met (D-099, recorded by the lead). He asked for the fastest progress at the
highest accuracy: many agents in parallel that never block or disturb each other.

Scope is PRD §12.2 for Phase 1 as narrowed by the rows of PRD §8 and
`docs/IMPLEMENTATION_PLAN.md` ("Phase 1 — stream A"). This file decides how that
scope is cut into agent tasks for the workflow of D-092. It adds no feature.

Every Phase 1 requirement ID appears exactly once in this file: in §4 (buildable,
with its task) or in §5 (blocked or waiting, with its blocker). The task texts are
`docs/plans/tasks/P1-<nn>-<slug>.md`; each is self-contained and under 10,000
characters, and its base is `main`.

## 1. Waves at a glance

Caps are the run's `maxBudgetUsd`; a run usually spends 50 to 70% of its cap. Key
slots alternate so that the two API accounts carry about the same load. A task
starts when every task in its "Needs" column is merged into `main`, not when its
whole previous wave is.

| Wave | Task | What | Milestone | Agent | Key | Cap | Needs |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | P1-01 | Strings with given wording (Appendix A, and B once approved) | all | ui-builder | 1 | $8 | Step 0 |
| 0 | P1-02 | App seams: composition root, route table and seams, `Command` | M1.1 | ui-builder | 2 | $15 | Step 0 |
| 0 | P1-03 | Guard allow-lists as one file per entry | all | test-engineer | 1 | $8 | Step 0 |
| 1 | P1-04 | User database v1, settings store, app settings, reading position, level policy | M1.1, M1.2 | data-builder | 2 | $25 | P1-02, P1-03 |
| 1 | P1-05 | Base pack bootstrap, verification at run time, Ed25519 verifier, Quran indexes | M1.2, M1.3, M1.4 | data-builder | 1 | $25 | P1-02, P1-03 |
| 1 | P1-06 | Pack format v2: search forms, tafsir kind, recitation kind | M1.4, M1.7, M1.8, M1.9 | data-builder | 2 | $30 | P1-03 |
| 1 | P1-07 | Download queue and pack installer: resume, Wi-Fi only, verify then activate, rollback | M1.4 | data-builder | 1 | $30 | P1-02, P1-03 |
| 1 | P1-08 | Playback plan and its rules (pure Dart) | M1.9 | audio-builder | 2 | $20 | Step 0 |
| 1 | P1-09 | Surah-mode layout engine (S1 port) | M1.2 | ui-builder | 1 | $30 | P1-01, P1-03 |
| 1 | P1-10 | Address input: go-to and direct-jump parsing, surah-name lookup | M1.3, M1.8 | data-builder | 2 | $15 | P1-02, P1-03 |
| 1 | P1-11 | Proposals for the eight icons of D-051 (SVG for the owner) | M1.6, M1.9 | ui-builder | 1 | $12 | Step 0 |
| 1 | P1-12 | Copy and share-card machinery | M1.6 | ui-builder | 2 | $25 | P1-01, P1-02, P1-03 |
| 2 | P1-13 | Pack catalogue and recitation listing | M1.4, M1.9 | data-builder | 1 | $30 | P1-05, P1-06, P1-07 |
| 2 | P1-14 | Reader screen, surah mode | M1.2 | ui-builder | 2 | $30 | P1-04, P1-05, P1-09 |
| 2 | P1-15 | Settings, first-run setup, report sheet, More hub | M1.1 | ui-builder | 1 | $25 | P1-01, P1-04, P1-05, P1-07 |
| 2 | P1-16 | Home frame: header, greeting, continue-reading card, index door | M1.1, M1.2, M1.3 | ui-builder | 2 | $15 | P1-04, P1-05 |
| 2 | P1-17 | Index, go-to sheet, context sheet, ayah cards | M1.3 | ui-builder | 1 | $30 | P1-04, P1-05, P1-09, P1-10 |
| 2 | P1-18 | User data repositories: bookmarks, tags, notes, listening position, search history, integrity log, keep-awake | M1.6, M1.8, M1.9 | data-builder | 2 | $25 | P1-04, P1-05 |
| 2 | P1-19 | Audio engine and player state | M1.9 | audio-builder | 1 | $35 | P1-05, P1-06, P1-08 |
| 2 | P1-20 | Tafsir repository | M1.7 | data-builder | 2 | $20 | P1-04, P1-05, P1-06, P1-07 |
| 2 | P1-21 | Search engine, tafsir search included | M1.8 | data-builder | 1 | $30 | P1-06, P1-10 |
| 2 | P1-22 | Reader targets, tap resolver and highlights (S7 port) | M1.2, M1.6 | ui-builder | 2 | $25 | P1-09, D-097 recorded |
| 3 | P1-23 | Reader gestures, ayah toolbar, margin indicators | M1.2, M1.6 | ui-builder | 1 | $30 | P1-14, P1-18, P1-22 |
| 3 | P1-24 | Bookmarks and notes screens | M1.6 | ui-builder | 2 | $30 | P1-05, P1-17, P1-18 |
| 3 | P1-25 | Resource manager: tafsir and page packs, updates, storage | M1.4, M1.7 | ui-builder | 1 | $30 | P1-13, P1-20 |
| 3 | P1-26 | Start-up at last position, «أكمل الاستماع», bookmarks door, integrity alert | M1.1, M1.2, M1.9 | ui-builder | 2 | $20 | P1-14, P1-15, P1-16, P1-18, P1-19, P1-25 |
| 3 | P1-27 | Full player, mini player, recitation picker | M1.9 | ui-builder | 1 | $30 | P1-13, P1-19 |
| 3 | P1-28 | Player sheets: range, play options, repeat, silence, stop-after, sleep timer, queue | M1.9 | ui-builder | 2 | $30 | P1-19 |
| 3 | P1-29 | Search screen and history | M1.8 | ui-builder | 1 | $30 | P1-18, P1-21 |
| 3 | P1-30 | Tafsir reader and tafsir sheet | M1.7 | ui-builder | 2 | $30 | P1-12, P1-13, P1-20 |
| 3 | P1-40 | Sources and licences screen, link service | M1.1 | ui-builder | 1 | $20 | P1-05, P1-07, P1-15 |
| 4 | P1-31 | Word sheet (text and tafsir tabs) and mini ayah sheet | M1.6, M1.7, M1.9 | ui-builder | 1 | $30 | P1-23, P1-24, P1-28, P1-30 |
| 4 | P1-32 | Following the recitation in the reader | M1.10 | ui-builder | 2 | $30 | P1-23, P1-27 |
| 4 | P1-33 | Recitation downloads and quality | M1.9 | ui-builder | 1 | $25 | P1-25, P1-27 |
| 4 | P1-34 | Critical-path integration tests | M1.11 | test-engineer | 2 | $30 | waves 1 to 3 |
| 5 | P1-35 | Accessibility pass over every screen | M1.11 | ui-builder | 1 | $35 | wave 4 |
| 5 | P1-36 | Performance budgets: harness and device protocol | M1.11 | test-engineer | 2 | $25 | wave 4 |
| 5 | P1-37 | Release readiness: launcher icon, launch screen, privacy guard, compliance | M1.11 | ui-builder | 1 | $25 | wave 4 |
| any | P1-38 | Strings, second batch, after the owner answers (Appendix B, C) | all | ui-builder | 1 | $8 | owner's answers |
| any | P1-39 | Approved project icons into the generator | M1.6, M1.9 | content-engineer | 2 | $15 | owner's approval of P1-11 |

Totals: 40 tasks, caps $981. Waves 0 to 5 hold 3, 9, 10, 9, 4 and 3 tasks. P1-40 is numbered last because it was split from P1-15 in review.

P1-38 and P1-39 join the first wave that starts after their condition is met. Each
owns files no task of waves 1 to 4 owns (`lib/l10n/`; the icon generator and
`icon_paths.g.dart`), so they fit any of those waves. P1-38 never runs beside P1-01,
and P1-39 never beside P1-11 or in wave 5 (P1-35 and P1-37 own its files then). A task that needs a string or an icon they bring builds what it
can without it and names the gap in its report.

## 2. How the waves run

- **Runs at once.** Every task in a wave owns different files (§7), so all of a
  wave's tasks may be started together, on both keys. If the API accounts' rate
  limits throttle, start two at a time (one per key) in table order. `docs/WORKFLOW.md`
  says so since step 0 (D-100).
- **Order of merging.** Before each merge, update the branch from `main` and run the
  `check` task again: disjoint files do not rule out a broken build. Within wave 3,
  merge P1-28 before P1-23 (the toolbar opens P1-28's play options by path). A pull
  request is merged after its review and CI pass (the owner, or the lead where merges
  are delegated, D-093).
- **Between waves.** The lead reviews each pull request (`code-reviewer` on every
  task that touches Quran text, packs, user data or two layers), records what the
  report asks for in `docs/PROJECT_STATUS.md` and `docs/DECISIONS.md`, and starts the
  CI `goldens` task on `main` after a merge that adds golden tests (D-056).
- **Rules learned in M0.4 part 2.** While any run is out, nobody changes
  `.github/workflows/` on its base. The `apk` task is never started while an agent
  run's tests are running. Every task text ends by telling the agent to wait for its
  background tasks and to make its last message the whole report.
- **Generated files.** `dart run build_runner build` regenerates every drift file;
  each task commits only the generated files of the sources it owns.

## 3. Lead step 0 (before wave 0)

1. Merge the M0.4 milestone branch (`claude/great-hamilton-9n23mt`) into `main`, so
   that `main` carries D-093 to D-098, the S4 and S7 pages and the spike findings.
   Spike code stays readable at the SHA its pages cite.
2. Record D-099 (the owner's opening of Phase 1) and the proposals of §6.
3. Add the Phase 1 packages, one commit each, versions resolved together on
   Flutter 3.44.7, each with its decision: `provider`; `drift`, with `drift_dev` and
   `build_runner` as dev dependencies; `path_provider` 2.1.6; `just_audio` 0.10.6,
   `audio_service` 0.18.19, `audio_session` 0.2.4; `background_downloader` 9.5.9
   (9.6 needs Flutter 3.47); `connectivity_plus` (S5: the downloader reports no
   "waiting for Wi-Fi"); `wakelock_plus`; `share_plus`; `url_launcher` (the Tanzil
   credit links to tanzil.net); `cryptography` for Ed25519 (D-080). Free space
   (resource manager) needs either a maintained package or a small platform channel:
   choose and record it. Add `INTERNET` to the main Android manifest (S5 finding).
   Add `package:provider/` (and any other pure-Dart package that `lib/ui` or
   `lib/config` will import, such as `path`) to `_nonPlugins` in
   `test/guards/import_rules_test.dart` in the same commit, so that P1-02 passes the
   guards beside P1-03; add `fake_async` or `clock` as dev dependencies if the timer
   tests need them. Decide how the notification permission is asked on Android 13
   and later (recommended: a small method channel in `MainActivity.kt`, P1-19).
4. Amend the documents this plan relies on, so that no task contradicts them: step 4
   of "Building a screen the identity does not draw" in `docs/DESIGN_SYSTEM.md`
   (D-115); "Milestones run one at a time" and "two runs at once" in
   `docs/WORKFLOW.md` (D-100); the source layout and feature list of
   `docs/ARCHITECTURE.md` (`ui/core/reader`, `ui/core/share`, D-101); the M1.10 row of
   `docs/IMPLEMENTATION_PLAN.md` (D-112); and the agent files: `ui-builder.md` (no
   wording of its own; tasks commit) and `data-builder.md` (files under `lib/config/`
   and `testing/` handed over by a task). Freeze the decision numbers before the first
   run: the tasks cite them.
5. Put the owner questions of §9 to him in one batch (`ask-owner`).
6. Before P1-22 starts: D-097 (the tap rule chosen by S7's usability test) must be
   recorded from the owner's device session.
7. Add the CI task `sign-pack` (O-03, D-108), below, to `.github/workflows/ci.yml`
   at a moment when no agent run is out on `main` (workflow files stay still while a
   run is out). The owner first creates the key pair and the secret (steps below);
   then the lead commits the two public keys.

Items 2 to 4 and the text of item 7 landed with the step-0 pull request; the job
itself is the lead's, because no agent edits `.github/`.

### 3.1 The CI task `sign-pack`

A pack is built where its sources are (the pipeline of `tools/packs/`, unsigned) and
put, unsigned, on a GitHub Release of this repository (O-08): one release per pack
version, tagged `pack-<id>-<version>` (the version is the manifest's integer, as in
`pack-base-hafs-tanzil-1`), holding `manifest.json`, every file the
manifest's `files` names (`text.sqlite` in format v1) and, for a text pack, the mark
table it was built with as `marks.json`. Whoever builds the pack records the SHA-256 of
`manifest.json` and of `marks.json` where the pack's review is recorded (B0.2: the
proofreader's sign-off); the manifest holds the hash of every file and the digest of
every surah, so its hash pins the whole content. The job refuses to sign unless the
downloaded files have exactly the hashes typed into the run, prints them, verifies the
pack with its font and mark table, signs `manifest.json` with the secret key, checks the signature against
the committed public key, and adds `manifest.json.sig` to the same release. It never
re-signs: `pack.py sign` refuses a pack that has a signature, and `gh release upload`
without `--clobber` refuses an existing asset.

Inputs added to `workflow_dispatch` (seven in all with `task` and `scope`): `task`
gains the option `sign-pack`; `release` (the tag), `pack` (`<id>/<version>`),
`font` (the font paired with the pack's text, default
`assets/fonts/AmiriQuran-Regular.ttf`), `manifest_sha256` and `marks_sha256` (the
recorded hashes). The owner, as the environment's required reviewer, sees these
inputs before he approves the run. The `check` job's condition becomes
`github.event_name != 'workflow_dispatch' || (inputs.task != 'goldens' && inputs.task != 'sign-pack')`.

```yaml
  sign-pack:
    name: Sign a content pack
    if: github.event_name == 'workflow_dispatch' && inputs.task == 'sign-pack' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    # Holds PACK_SIGNING_KEY; the owner approves each run (required reviewer).
    environment: pack-signing
    permissions:
      contents: write
    concurrency:
      group: sign-pack
      cancel-in-progress: false
    env:
      RELEASE: ${{ inputs.release }}
      PACK: ${{ inputs.pack }}
      FONT: ${{ inputs.font }}
      MANIFEST_SHA256: ${{ inputs.manifest_sha256 }}
      MARKS_SHA256: ${{ inputs.marks_sha256 }}
      GH_TOKEN: ${{ github.token }}
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4
        with:
          persist-credentials: false

      - name: Check the inputs
        run: |
          [[ "$RELEASE" =~ ^pack-[a-z0-9-]+-[1-9][0-9]*$ ]]
          [[ "$PACK" =~ ^[a-z0-9]+(-[a-z0-9]+)*/[1-9][0-9]*$ ]]
          [[ "$RELEASE" == "pack-${PACK%/*}-${PACK#*/}" ]]
          [[ "$FONT" =~ ^assets/fonts/[A-Za-z0-9._-]+\.ttf$ ]]
          test -f "$FONT"
          [[ "$MANIFEST_SHA256" =~ ^[0-9a-f]{64}$ ]]
          [[ "$MARKS_SHA256" =~ ^[0-9a-f]{64}$ ]]

      - name: Download the unsigned pack and its mark table
        run: |
          dir="$RUNNER_TEMP/packs/$PACK"
          mkdir -p "$dir" "$RUNNER_TEMP/in"
          gh release download "$RELEASE" --pattern manifest.json --dir "$dir"
          gh release download "$RELEASE" --pattern marks.json --dir "$RUNNER_TEMP/in"
          echo "$MANIFEST_SHA256  $dir/manifest.json" | sha256sum --check
          echo "$MARKS_SHA256  $RUNNER_TEMP/in/marks.json" | sha256sum --check
          mapfile -t names < <(python3 -I -c 'import json,sys; [print(f["name"]) for f in json.load(open(sys.argv[1]))["files"]]' "$dir/manifest.json")
          (( ${#names[@]} > 0 ))
          for name in "${names[@]}"; do
            [[ "$name" =~ ^[a-z0-9_.-]+$ ]]
            gh release download "$RELEASE" --pattern "$name" --dir "$dir"
          done
          test ! -e "$dir/manifest.json.sig"
          (cd "$dir" && sha256sum manifest.json "${names[@]}")

      - name: Sign
        env:
          PACK_SIGNING_KEY: ${{ secrets.PACK_SIGNING_KEY }}
        run: |
          test -n "$PACK_SIGNING_KEY"
          umask 077
          key="$RUNNER_TEMP/signing-key.pem"
          trap 'rm -f "$key"' EXIT
          printf '%s\n' "$PACK_SIGNING_KEY" > "$key"
          python3 tools/packs/pack.py sign "$RUNNER_TEMP/packs/$PACK" --key "$key" \
            --font "$FONT" --mark-table "$RUNNER_TEMP/in/marks.json"

      - name: Check the signature with the committed public key
        run: |
          python3 tools/packs/pack.py verify-signature "$RUNNER_TEMP/packs/$PACK" \
            --public-key tools/packs/keys/pack-signing-1.pub.pem

      - name: Add the signature to the release
        run: gh release upload "$RELEASE" "$RUNNER_TEMP/packs/$PACK/manifest.json.sig"
```

Outputs: the asset `manifest.json.sig` on the release `pack-<id>-<version>`, and the
job log, which shows the files' hashes, the path `pack.py sign` wrote and any problem
it found by address and code point; OpenSSL's output is dropped and the key is never
echoed. Nothing is committed.

Limits, for later tasks: `pack.py sign` verifies text packs (format v1) only, so
tafsir and recitation packs (format v2, D-110) and the catalogue (`catalogue.json.sig`,
D-109) need a `tools/packs` command that verifies their kind before this job can sign
them; that is a `content-engineer` task after P1-06 and P1-13 have fixed the formats.
To move to the spare key, the job reads `PACK_SIGNING_KEY_SPARE` and checks against
`pack-signing-2.pub.pem`; a new spare then ships in the next app release.

### 3.2 The owner's key steps

Written in English; the lead gives them to the owner in Arabic.

1. On a computer with OpenSSL 3, in a new empty folder outside any Git repository.
   First run `openssl version`; go on only if it says `OpenSSL 3`. Linux and Git
   Bash on Windows usually have it; the `openssl` that macOS ships is LibreSSL,
   which cannot make these keys, so on a Mac install `openssl@3` with Homebrew and
   use its full path (`$(brew --prefix openssl@3)/bin/openssl`). Then run:
   `openssl genpkey -algorithm ed25519 -out pack-signing-1.pem`,
   `openssl genpkey -algorithm ed25519 -out pack-signing-2.pem`,
   `openssl pkey -in pack-signing-1.pem -pubout -out pack-signing-1.pub.pem` and
   `openssl pkey -in pack-signing-2.pem -pubout -out pack-signing-2.pub.pem`.
   Key 1 is the key in use; key 2 is the spare.
2. On GitHub, in this repository: Settings, Environments, New environment, named
   `pack-signing`. Under its protection rules, add yourself as a required reviewer
   and limit deployment branches to `main`. (If GitHub offers no environments here, as
   for a private repository on the Free plan, stop and tell the lead: without the
   approval gate any run started on `main`, an agent's included, could sign, so the
   job is not added until the owner settles it, for example by making the
   repository public, question 18 of §9.)
3. In that environment, Add environment secret: name `PACK_SIGNING_KEY`, value the
   whole content of `pack-signing-1.pem`, the `BEGIN` and `END` lines included. Add
   a second secret, `PACK_SIGNING_KEY_SPARE`, with the content of
   `pack-signing-2.pem`.
4. Send the lead the two `.pub.pem` files. They are public and are committed to
   `tools/packs/keys/` and built into the app. Never send or commit a file whose
   name does not end in `.pub.pem`.
5. Delete `pack-signing-1.pem` and `pack-signing-2.pem` and empty the trash. GitHub
   never shows a secret again: from now on the private keys exist only as the two
   secrets. (If you want the spare to survive the loss of the GitHub account, keep
   `pack-signing-2.pem` on a USB stick kept somewhere safe instead of deleting it.)

Then the lead commits `tools/packs/keys/pack-signing-1.pub.pem` and
`pack-signing-2.pub.pem`, and puts both keys, as their raw 32 bytes
(`openssl pkey -pubin -in pack-signing-1.pub.pem -outform DER | tail -c 32 | od -An -tx1`),
into `lib/config/signing_keys.dart` once P1-05 has created it.

## 4. Buildable scope, with its task

"Buildable now" means engineering that shows no content of its own: it is built and
tested on synthetic packs, and shows real content only when a verified pack from a
`Ready` row arrives. The base pack's real text arrives with B0.2 (the sign-off of
the licensed reciter the owner named, O-16) and is signed by the CI task `sign-pack`
(O-03, §3.1). A real tafsir is a Zaydi-library book (O-06) and needs B0.6, B0.7, the
reviewer's checks (D-082), O-07 and its rights record; a real recitation needs the
planning session's proposal approved by the owner (O-04), B0.5 and a complete rights
record. The owner's answers are recorded as D-119. Where a
requirement is partly blocked, the blocked part is named in the same row.

| ID | Task | Part built and its notes |
| --- | --- | --- |
| RD-01 | P1-14 | Read from the bundled base pack offline (bootstrap in P1-05) |
| RD-02 | P1-14 | Layout by P1-09; screen, header, basmala rule |
| RD-05 | P1-14 | Surah-mode position bar; the page-mode part waits for page mode (§5) |
| RD-06 | P1-14 | Page-boundary marks inside the line (D-071), laid out by P1-09 |
| RD-07 | P1-23 | Surah-mode size steps 80–200% and pinch (ladder in P1-09); page zoom waits (§5) |
| RD-08 | P1-15 | Theme and follow-system choice persisted and applied at start |
| RD-09 | P1-14 | Distraction-free mode; the margin tap that toggles it is P1-23's |
| RD-10 | P1-14 | Portrait and landscape in surah mode; two facing pages are Phase 2; audited by P1-35 |
| RD-11 | P1-14 | Continuous vertical scroll in surah mode; page swipe waits for page mode (§5) |
| RD-12 | P1-14 | First visible ayah saved on scroll end and on leaving (repository P1-04) |
| RD-13 | P1-26 | Open at the last position (setting in P1-15) |
| RD-14 | P1-17 | Ayah cards in lists and context (reused by P1-24, P1-29); the reading mode is Phase 3 |
| RD-15 | P1-14 | Sajda sign from the text and «سجدة» in the margin (P1-09) |
| RD-16 | P1-32 | Keep-awake service P1-18, setting P1-15, while reading P1-23, while reciting P1-32 |
| RD-17 | P1-14 | Info line from the base pack's surah facts; the sheet shows those basic facts only |
| NV-01 | P1-17 | Surah index with «آخر قراءة» |
| NV-02 | P1-17 | Juz, hizb and rub indexes |
| NV-03 | P1-17 | Go-to sheet; parsing and validation in P1-10 |
| NV-05 | P1-17 | Context sheet (the `ContextSheet` of D-088) |
| NV-06 | P1-14 | Inside the app: every address is a route; links from outside are Phase 2 |
| AU-01 | P1-27 | Recitation picker over P1-13; only complete rights records are listed |
| AU-02 | P1-28 | Range picker; plan in P1-08 |
| AU-03 | P1-28 | Play options sheet opened from the ayah toolbar (P1-23) |
| AU-04 | P1-08 | Continue into the next surah; executed by P1-19 |
| AU-05 | P1-27 | Controls; stop and next/previous surah icons wait for P1-39 |
| AU-06 | P1-19 | Speed with pitch kept; control on the full player (P1-27) |
| AU-07 | P1-28 | Sleep timer sheet; fade in P1-19, rule in P1-08 |
| AU-08 | P1-28 | Stop-after sheet; rule in P1-08 |
| AU-09 | P1-28 | Repeat counts 1–99 and unlimited; rule in P1-08 |
| AU-11 | P1-28 | Silence between ayat; plan in P1-08 |
| AU-12 | P1-19 | Streaming with the next segment preloaded |
| AU-13 | P1-33 | Download by surah, juz or whole, size first, resume, Wi-Fi only (queue P1-07) |
| AU-14 | P1-33 | Quality choice where the catalogue offers more than one |
| AU-15 | P1-19 | Background playback, lock screen, notification, headset |
| AU-16 | P1-26 | Last listening position saved and resumed (repository P1-18, state P1-19) |
| AU-17 | P1-28 | Queue sheet; queue operations in P1-19 |
| AU-22 | P1-19 | Calls and unplugging pause; resume by the system's policy |
| AU-23 | P1-08 | Rule priority: sleep timer, stop-after, repeat, continue |
| AU-24 | P1-08 | Basmala and isti'adha only as the reciter recorded them |
| SY-01 | P1-32 | Recited ayah highlighted from the plan's ayah events (D-112); for surah-file recitations the ayah timing waits for row 6 |
| SY-03 | P1-32 | Auto-scroll and «عُد إلى موضع التلاوة» |
| SY-04 | P1-32 | Highlight follows the playback speed |
| SY-05 | P1-32 | Stand mode: keep awake, follow, hide the interface |
| WQ-01 | P1-09 | Pause marks kept as in the text; a word keeps its marks on its line (S1 finding) |
| LX-01 | P1-31 | Text and tafsir tabs; other tabs are later phases |
| LX-11 | P1-31 | Fields without data hidden; source badge on sourced fields |
| TF-01 | P1-30 | Default tafsir chosen from downloaded and available |
| TF-02 | P1-30 | Sheet from the ayah tools and full reader in the study tab |
| TF-03 | P1-30 | Ayah by ayah with the ayah shown above |
| TF-04 | P1-30 | A passage over several ayat shown once with its range (data P1-20) |
| TF-05 | P1-30 | Source badge; its information icon waits for P1-39 |
| TF-06 | P1-25 | Download and delete; one short tafsir fetched at first use |
| TF-07 | P1-29 | Search in one or several downloaded tafsirs (engine P1-21) |
| TF-08 | P1-30 | Ayat quoted inside a passage stay source text in the UI font |
| TF-10 | P1-30 | Copy and share a passage with its attribution (P1-12); icons wait for P1-39 |
| SR-01 | P1-29 | Chips shown only where data exists: word, without diacritics, in tafsirs |
| SR-02 | P1-21 | Whole ayah, phrase, scattered words |
| SR-03 | P1-21 | Matching on the pack's stored search forms (D-037); real forms come with B0.2 and B0.4 |
| SR-04 | P1-29 | Summary line and result cards; expanded state held by the caller (M0.5 review) |
| SR-05 | P1-29 | Mushaf order, nearest, most frequent |
| SR-06 | P1-29 | Scope: whole Quran, surah, juz |
| SR-07 | P1-29 | Direct jump from the field (parser P1-10) |
| SR-08 | P1-24 | Search in bookmarks and notes (queries P1-18) |
| SR-10 | P1-29 | Local history that can be cleared (store P1-18) |
| UD-01 | P1-24 | The four categories of `Tag`; «تفسير» and user-made categories wait for O-14 (§5) |
| UD-02 | P1-24 | Free tags shared by bookmarks and notes |
| UD-03 | P1-24 | Newest or mushaf order, filter by category and tag, search |
| UD-04 | P1-24 | Notes on an ayah, several per ayah |
| UD-05 | P1-23 | Margin ribbon for a bookmark; the note indicator waits for P1-39 |
| UD-07 | P1-24 | Delete with «تراجع»; the delete icon waits for P1-39 |
| ST-01 | P1-31 | Ayah, tafsir, my notes, audio sections |
| SH-01 | P1-12 | Three copy forms from the pack by address; entry from the toolbar once P1-39 lands |
| SH-02 | P1-12 | Three designs and three sizes rendered to an image and shared |
| SH-03 | P1-12 | Size down to 22, then the tall size, then the fixed sentence |
| SH-05 | P1-12 | Every text that leaves the app is fetched by address |
| OF-01 | P1-25 | One manager, categories shown only when they hold packs |
| OF-02 | P1-25 | Name, size, state with percent, source and version, actions |
| OF-03 | P1-25 | Space per category and free space |
| OF-04 | P1-07 | Sequential resumable queue, Wi-Fi only, stop with an alert on low space |
| OF-05 | P1-07 | Hash and manifest signature before activation (verifier P1-05; packs signed in CI, O-03; the public keys wait for the owner's key steps, §3.2) |
| OF-06 | P1-07 | Atomic update and rollback; the notice with the change summary is P1-25's |
| OF-07 | P1-07 | Deleting a pack touches no user row (proven again end to end by P1-34) |
| AC-01 | P1-15 | Everything works without an account |
| AX-01 | P1-35 | Reading order and spoken names over every screen |
| AX-02 | P1-35 | Hit areas of 48 everywhere (reader targets built by P1-22; standalone markers here) |
| AX-03 | P1-35 | Contrast of every new pair; exceptions of O-12 stay listed |
| AX-04 | P1-35 | 200% text without clipping on every screen |
| AX-05 | P1-35 | A word, shape or line with every colour-coded state |
| AX-06 | P1-35 | Reduce motion everywhere |
| AX-07 | P1-19 | System media controls on headset and lock screen |
| AX-09 | P1-35 | Visible focus ring with a keyboard |
| LV-01 | P1-15 | One setting, default «بسيط»; asked in the first-run setup (O-17: the display-mode and recitation steps join it when page mode and a `Ready` recitation exist) |
| LV-02 | P1-15 | Instant change, no restart, no data lost |
| LV-03 | P1-23 | The matrix of PRD §7.3 (policy in P1-04) applied in the reader; every screen task applies it |
| LV-04 | P1-15 | A higher-level tool opened by link works; its "always show" line waits for wording (Appendix C) |
| NF-01 | P1-36 | Built by P1-26 and P1-04 (settings read before the first frame); measured on the device |
| NF-02 | P1-36 | Scroll harness and device protocol for surah mode |
| NF-03 | P1-21 | 300 ms budget test on the synthetic pack; device check in P1-36 |
| NF-04 | P1-19 | Audio start budgets |
| NF-05 | P1-36 | Word and ayah sheet open time |
| NF-06 | P1-37 | Base download size measured on the release APK (S6) |
| NF-08 | P1-04 | Migration test from schema v1, repeated with every schema change |
| NF-09 | P1-19 | Sixty minutes locked; device check pending |
| NF-10 | P1-37 | Android 8.0 set (D-070); the iOS target waits for iOS builds (D-042) |
| NF-11 | P1-35 | Phones and tablets, both orientations |
| NF-12 | P1-19 | Foreground media service and notification permission |
| NF-13 | P1-15 | Local by default; no account |
| NF-14 | P1-37 | Guard: no SDK or call sends reading history or notes anywhere |
| NF-15 | P1-07 | HTTPS only (TLS 1.2 or later) for catalogue and packs |
| NF-17 | P1-35 | WCAG 2.2 AA checklist, automatic where possible |
| NF-18 | P1-35 | Arabic only, right to left, Arabic-Indic digits on every screen |
| NF-19 | P1-13 | A signed catalogue adds a pack with no app release |
| NF-20 | P1-34 | Critical paths run with every change |

Not in Phase 1, listed so that none is built by mistake: RD-18, NV-04, AU-10, AU-18,
AU-19, AU-21, WQ-04, WQ-05, TF-09, UD-06, SH-04, AC-02 to AC-07, AX-08, LX-02 to
LX-10, ST-02 to ST-05, SR-09, SR-11, NF-16 (account deletion comes with accounts).

## 5. Blocked or waiting scope

| ID | Status | Blocker, and what unblocks it |
| --- | --- | --- |
| RD-03 | Waits | B0.3 (page fonts and 1421H layout), spike S2, and a `pages` pack kind. Rows 2 and 3 are `Ready`, so it is planned as soon as B0.3 lands and S2 has run |
| RD-04 | Waits | Needs page mode (as above) |
| RD-19 | Waits | B0.3 and B0.4: the KFGQPC Hafs text pack with its font and its word mapping. Row 2 is `Ready`. KFGQPC's permission for shipping its font is to be confirmed (`docs/SOURCES.md`) |
| WQ-02 | Blocked | Registry row 19 is `Verify` (B0.8: meanings transcribed from the appendix and reviewed). The six example sentences on the Mushaf board are illustration |
| WQ-03 | Blocked | Registry row 19, as above |
| SY-02 | Blocked | Registry row 6 is `Verify` (word timing, drift measured per recitation, B0.5) |
| AU-20 | Blocked | Registry row 6, as above |
| NF-07 | Blocked | O-18: no crash-free rate can be measured without the user-consented reporting he has not decided |
| NF-21 | Blocked | O-18, as above |

Also blocked, with no ID of their own: the category «تفسير» and user-made category
colours and shapes (O-14, within the bookmark row above); the display-mode and
recitation steps of the first-run setup (O-17, adopted; they wait for page mode and
for a `Ready` recitation); the send action of «أبلغ عن خطأ» and its entry points
(O-17, adopted; they wait for the owner's answers 15 and 16 of §9, while P1-15 builds
the sheet); every Zaydi-library book (O-07, the reviewer's checks of D-082); the seven
general tafsirs (deferred by O-06); the page-mode parts named in §4; the eight
icons until the owner approves them (D-051); every string of Appendix C.

## 6. Shared architecture: proposals for `docs/DECISIONS.md`

Recorded in `docs/DECISIONS.md` as D-100 to D-118 with these numbers, and amended
there for the owner's answers of D-119: D-101 (the `report` feature), D-102 (the
first-run setup and the report sheet's route), D-108 (signing in CI, a spare key),
D-109 (GitHub Releases hosting) and D-110 (Zaydi-library books only). The rows in
`docs/DECISIONS.md` decide; this list keeps the plan's reasoning.

- **D-100 Phase 1 by waves.** Phase 1 runs as the tasks of this file. Within a wave
  no two tasks own a file. Shared files are seams made in wave 0 (§7) or have one
  owner per wave. Amends "Milestones run one at a time" and "two runs at once" in
  `docs/WORKFLOW.md`: a wave's tasks may all run together.
- **D-101 Feature folders by screen group.** `lib/ui/features/` holds `onboarding`,
  `home`, `mushaf`, `index`, `listen`, `study` (hub), `search`, `tafsir`,
  `sheets` (the word and ayah sheets), `more` (hub), `bookmarks`, `resources`, `settings`, `sources`,
  and `report` (the «أبلغ عن خطأ» sheet, O-17).
  Features never import each other; a sheet one feature opens in another is a route.
  Amends the feature list of `docs/ARCHITECTURE.md`.
- **D-102 Routing.** P1-02 fixes every Phase 1 path and a typed location builder for
  each in `lib/routing/routes.dart` (an address route `/mushaf/read/<address>` for
  in-app links; the report sheet `/sheet/report/<address>`, O-17), and composes the router from one route file per feature in
  `lib/routing/routes/`, each owned by its feature's task. Sheets are modal
  routes on the root navigator, opened with `push` only, as a modal-sheet `Page`; a
  cold start at a sheet path redirects to the screen it belongs to. The shell holds a
  chrome-visibility seam (`lib/ui/core/shell_chrome.dart`) through which the reader
  hides the tab bar (distraction-free mode, simple level). An unknown location redirects to the home tab
  (closes the M0.1 note on go_router's English error page). Start-up decisions (the
  first-run setup of O-17, open at last position) live in `lib/routing/startup_redirect.dart`.
- **D-103 State and dependencies.** `provider` (confirms D-021). One composition root,
  `lib/config/dependencies.dart`, builds the providers of each area from one file per
  area in `lib/config/providers/` in a fixed order. App-wide state (settings, level,
  positions, player, downloads) lives in repositories exposed as `Listenable`; view
  models are `ChangeNotifier`s with commands (`lib/utils/command.dart`).
- **D-104 User database.** `drift` over its native backend on the bundled SQLite of
  `sqlite3` (D-061), one file `user.sqlite` in the application-support directory.
  Schema v1 (P1-04) holds every Phase 1 table: settings, reading position, listening
  position, bookmarks, categories, tags and their joins, notes, search history, the
  integrity log. Every synced kind of row has a random 128-bit id, `updated_at` and a
  deletion tombstone (PRD §10.6, Phase 2). Drift schema dumps and a migration test
  per version (PRD §11, user data kept across upgrades). DAOs live in their own files and are not listed in
  `@DriftDatabase(daos: …)`, so feature tasks add them without touching the database
  class. A schema change after v1 has one owner per wave.
- **D-105 Settings.** Typed key-value rows in the user database; each area owns its
  keys in its own repository. Theme, follow-system and level are read before the
  first frame (no theme flash; cold-start budget).
- **D-106 Positions.** One reading position and one listening position per device,
  addresses only (with the recitation id and the time offset for listening). Reading
  is saved on scroll end and on leaving the reader; listening on pause, on stop and
  every 10 s while playing.
- **D-107 Pack storage and installs.** `<application support>/packs/<id>/<version>/`;
  one `active.json` per pack id, replaced atomically by rename; the previous version
  kept for rollback; verify (hash, then signature) before activation; downloads by
  `background_downloader` with a connectivity signal of their own; no pack state in
  the user database, so deleting a pack cannot touch user rows. Writing services are
  named outside `lib/data/services/pack_*.dart` (pack-write guard, S5).
- **D-108 Signature verification.** Ed25519 as D-080 proposes, with `cryptography`,
  built now rather than after O-03 (replaces D-080's timing; D-065 stands: no pack is
  published until a real key exists). The bundled base pack is checked by hash at first
  run and, once keys exist, its signature must be `valid` in release builds.
  Packs are signed by the CI task `sign-pack` with the private key held as a GitHub
  Actions secret (O-03, §3.1). The accepted public keys, the key in use and a spare,
  live in `lib/config/`. Until the owner's key steps (§3.2) the list is empty, the
  verifier reports `notChecked`, and a release build refuses to activate a downloaded
  pack that is not `valid`; debug and profile builds accept `notChecked` for testing.
- **D-109 Catalogue.** One signed JSON file at an HTTPS address set in `lib/config/`
  (O-08: test packs and catalogue on this repository's GitHub Releases), listing packs by id, kind, version, size, files and hashes, and recitations
  with their rights state. Its format lives in `docs/PACK_CATALOGUE.md`. A pack or
  recitation is added by a catalogue update, never by an app release.
- **D-110 Pack format v2.** The text pack gains a table of the source's search forms,
  one row per word per form kind the source provides, linked to word numbers (only the
  query is folded); new kinds `tafsir` (passages with an ayah range, book,
  author, edition or editor, digitisation source, version) and `recitation` (files
  per surah or per ayah, per quality, with hashes and sizes). Timing and pages kinds
  wait for rows 6 and B0.3. `docs/CONTENT_PACKS.md` gains the v2 sections. In the
  first release the `tafsir` kind carries the Zaydi-library books only (O-06).
- **D-111 Audio boundaries.** `PlaybackPlan` and its rules are pure Dart in
  `lib/domain/models`, over one `QuranStructure` interface (P1-02) that the index
  repository implements; `AudioEngineService` is the only importer of `just_audio`,
  `audio_service` and `audio_session`; `PlayerRepository` holds the app-wide player
  state (plan, segment, position, speed, queue) as a `Listenable` that the mini
  player, full player and reader read. Android media settings return as S3 left them.
- **D-112 Following the recitation.** The recited ayah comes from the plan's ayah
  events, which need no timing data when a recitation is served one file per ayah
  (row 7). For recitations served as surah files, ayah and word timing come from
  row 6 and wait for it. Narrows the M1.10 row of `docs/IMPLEMENTATION_PLAN.md`.
- **D-113 Surah-mode engine.** `lib/ui/core/reader/` ports S1's V2 block layout and
  S7's target geometry, breaks lines itself at stored word boundaries so that a word
  keeps its pause marks without any character changed, centres the last line,
  keeps a word wider than the line whole, and resolves taps with the rule of D-097.
- **D-114 Allow-lists as entries.** The pack-text sinks, producers and carriers, and
  the import guard's `_nonPlugins` and `_rampImporters`, become one file per entry, each naming its decision, so
  that parallel tasks add entries without sharing a file; the same holds for the
  contrast pairs and the non-plugin packages. New pack-text producers (the tafsir and
  recitation readers) amend D-062 as well. New sinks in Phase 1: the
  reader paragraph, the clipboard composer, the share renderer, the surah-name lookup,
  the search-form index, the tafsir text, the media-session metadata.
- **D-115 Strings.** No task writes Arabic wording. Strings whose wording the PRD or
  the identity gives are added in wave 0; the rest wait for the owner (§8). Wording the
  lead proposes enters the ARB only after the owner approves it. Amends
  step 4 of "Building a screen the identity does not draw" in `docs/DESIGN_SYSTEM.md`.
- **D-116 Project icons.** Icons the owner approves under D-051 live in
  `tools/gen/project_icons/<name>.svg` (outside `design/`, which nobody changes) and
  are generated after the identity's 26 in `IconName`.
- **D-117 Launcher icon and launch screen.** Android adaptive icon and launch screen
  as vector drawables from the logo SVGs; no PNG is committed by an agent. iOS assets
  come with iOS builds (D-042).
- **D-118 Search index.** The query passes through one table-driven fold function;
  if the golden query set (B0.10) shows a folded index is needed, the app builds it
  from the pack's stored search forms in a cache file outside the pack with the same
  function. Results are shown from the pack by address.

## 7. Shared files and seams

Made in wave 0, then each owned by one task per wave:

| File or folder | Wave 0 | Wave 1 | Wave 2 | Wave 3 | Wave 4 | Wave 5 |
| --- | --- | --- | --- | --- | --- | --- |
| `pubspec.*`, `android/`, `ios/` | lead | — | P1-19 (`android/app/src/main/`) | — | — | P1-37 |
| `lib/l10n/` | P1-01 | P1-38 if due | P1-38 if due | P1-38 if due | P1-38 if due | P1-38 if due |
| `lib/main.dart`, `lib/config/dependencies.dart`, `lib/routing/router.dart`, `lib/routing/routes.dart` | P1-02 | — | — | — | — | — |
| `lib/config/providers/<area>_providers.dart` | P1-02 | the area's task | the area's task | P1-26 (`audio`) | — | — |
| `lib/routing/routes/<feature>_routes.dart` | P1-02 | — | the feature's task | the feature's task | the feature's task | P1-35 |
| `lib/routing/startup_redirect.dart` | P1-02 | — | P1-15 | P1-26 | — | — |
| `lib/ui/core/app.dart` | — | — | P1-15 | — | — | P1-35 |
| `lib/ui/core/tab_shell.dart`, `shell_chrome.dart` | P1-02 | — | — | P1-27 | — | P1-35 |
| `test/guards/*_test.dart` | P1-03 | — | — | — | — | P1-37 |
| `test/guards/contrast_test.dart` (pairs become entries) | P1-03 | — | — | — | — | — |
| `lib/ui/core/gallery/gallery_screen.dart` | — | — | — | P1-25 | — | — |
| Gallery sections and their tests | — | P1-12 (`home_share`) | P1-17 (`study_search`), P1-22 (`mushaf`) | P1-23 (`mushaf`), P1-24 (`controls`), P1-27 (`audio`), P1-30 (`study_search`), P1-25 (new `resources`) | P1-32 (`mushaf`) | P1-35 |
| `docs/CONTENT_PACKS.md` | — | P1-06 | — | — | — | — |
| `testing/packs/` | — | P1-06 | — | — | — | — |
| `lib/data/services/pack_database.dart` | — | P1-06 | — | — | — | — |
| `lib/data/services/user_database.dart` and the tables | — | P1-04 | — | — | — | — |
| `lib/ui/features/home/` | — | — | P1-16 | P1-26 | — | P1-35 |
| `lib/ui/features/mushaf/` | — | — | P1-14 | P1-23 | P1-32 | P1-35 |
| `lib/ui/core/reader/` | — | P1-09 | P1-22 (new files only) | P1-23 | — | P1-35 |
| `lib/ui/core/widgets/icon_paths.g.dart`, `tools/gen/` | — | P1-39 if due | P1-39 if due | P1-39 if due | P1-39 if due | P1-37 (`tools/gen/`) |
| `lib/ui/features/listen/` | — | — | — | P1-27 (screens), P1-28 (`controls/`) | P1-33 | P1-35 |
| `lib/ui/features/sheets/` | — | — | — | — | P1-31 | P1-35 |

Allow-list entries (`test/guards/allow/…`, P1-03) are one file per entry, named after
the task that adds it, so they never collide. Every task's own files are listed
exactly in its task text under "Files". In wave 5, P1-35 may touch any file under
`lib/ui/` and its tests; P1-36 and P1-37 own nothing there.

## 8. Strings

`lib/l10n/app_ar.arb` is edited only by P1-01 (wave 0) and P1-38 (after the owner
answers). No task invents Arabic wording. A task that needs a string not in the ARB
leaves that element out and lists the gap in its report.

**Appendix A — wording given by the PRD or the identity (P1-01 adds these).** Key
names are proposals; the wording is exact.

| Keys | Wording | Source |
| --- | --- | --- |
| homeGreeting; homeContinueHint | «السلام عليكم»; «أكمل من حيث توقفت» | Screens board |
| readingPositionLine | «الآية {ayah} · صفحة {page} · الجزء {juz}» | Screens board |
| indexTitle; indexSummary | «الفهرس»; «{surahs} سورة · {juz} جزءًا» | Screens2 board |
| indexTabSurahs; indexTabJuz; indexTabHizb | «السور»; «الأجزاء»; «الأحزاب» | Screens2 board |
| juzLabel; hizbLabel; rubLabel; pageLabel | «الجزء {number}»; «الحزب {number}»; «ربع»; «صفحة {number}» | Screens, Screens2, Mushaf boards |
| juzPageLine; juzHizbLine | «الجزء {juz} · صفحة {page}»; «الجزء {juz} · الحزب {hizb}» | Screens board (reader), Mushaf board |
| sajdaLabel | «سجدة» | PRD, Mushaf board |
| surahInfoLine; surahIntroTitle | «{revelation} · {count} · ترتيبها {order}»; «مقدمة السورة» | Mushaf board |
| goToTitle and its targets | «اذهب إلى»; «سورة»، «آية»، «صفحة»، «جزء»، «حزب»، «ربع» | PRD (go-to row) |
| ayahNotInSurah | «لا توجد آية {ayah} في {surah}» | PRD (index criteria) |
| contextSubtitle; contextAmountLabel; contextOneAyah; contextSurah | «ما قبلها وما بعدها»; «مقدار السياق»; «آية»; «السورة» | `ContextSheet`, Search board |
| toolbarBookmark; toolbarStudy; toolbarCopy; toolbarShare | «علامة»; «دراسة»; «نسخ»; «مشاركة» | PRD §7.4 |
| copySheetTitle; copyAyahOnly; copyWithSurah; copyWithSurahAndNumber; copyAction | «نسخ الآية»; «نص الآية فقط»; «الآية مع اسم السورة»; «الآية مع اسم السورة ورقمها»; «انسخ» | Share board |
| copyFormatFull | «﴿{ayah}﴾ [{surah}: {number}]» | PRD (copy row), Share board |
| shareDesignEmerald; shareDesignPaper; shareDesignNight; shareTooLong | «زمرد»; «ورق»; «ليل»; «الآية أطول من أن تتسع في بطاقة» | Share board; PRD |
| searchTitle; searchSortNearest; searchSortFrequent; searchScopeAll | «البحث»; «الأقرب»; «الأكثر ورودًا»; «القرآن كله» | Search board; PRD (search rows) |
| tafsirNoPassage | «لا يوجد تفسير لهذه الآية في هذا الكتاب» | PRD, `docs/DESIGN_SYSTEM.md` |
| connectionFailed; noBookmarksYet; undo; back | «تعذّر الاتصال»; «لا توجد علامات بعد»; «تراجع»; «رجوع» | PRD §7.5, D-052, boards |
| returnToRecitation | «عُد إلى موضع التلاوة» | PRD (sync rows) |
| wordTimingTag | «توقيت كلمات» | PRD (sync criteria) |
| resourceManagerTitle; the six categories | «مدير الموارد»; «التلاوات»، «التفاسير»، «مصحف الصفحات»، «الروايات»، «التجويد»، «الموارد اللغوية» | PRD §7.1 and resources rows |
| resourceAvailableMasculine; resourceStop; resourceRedownload | «متاح»; «إيقاف»; «إعادة التنزيل» | PRD (resources rows) |
| settingsTitle; themeLabel; textSettingsLabel; followSystemDark; sourcesTitle; bookmarksAndNotes | «الإعدادات»; «السمة»; «النص»; «اتباع وضع النظام الداكن»; «المصادر والتراخيص»; «العلامات والملاحظات» | PRD §7.1, §8 (themes row) |
| playerChange; playerAyahOfTotal; playerSilenceSeconds; queueLabel; recitationDownloadedLine | «تغيير»; «الآية {ayah} من {total}»; «صمت {seconds} ث»; «قائمة التشغيل»; «{riwaya} · محمّلة» | Screens2 board, `docs/DESIGN_SYSTEM.md` |
| playOnlyAyah; playToPageEnd; playToSurahEnd; playToJuzEnd; playUntilStopped | «الآية فقط»; «حتى نهاية الصفحة»; «حتى نهاية السورة»; «حتى نهاية الجزء»; «حتى أوقفه» | PRD (play from the ayah tools) |

**Appendix B — taken word for word from PRD requirement text, to be approved by the
owner as labels (question 1 of §9).** «فتح التطبيق على آخر موضع»؛ «منع إطفاء الشاشة
أثناء القراءة أو التلاوة»؛ «حجم النص»؛ «وضع بلا تشتيت»؛ «السرعة»؛ «نهاية الآية»؛
«نهاية السورة»؛ «التوقف بعد الآية»؛ «التوقف بعد الصفحة»؛ «التوقف بعد السورة»؛
«إيقاف»؛ «السورة التالية»؛ «السورة السابقة»؛ «الجودة»؛ «Wi-Fi فقط»؛ «الأحدث»؛
«ملاحظة»؛ «وسوم»؛ «سجل البحث»؛ «تحديث»؛ «جارٍ · {percent}»؛ «بلا نهاية»؛ «الصمت بين
الآيات»؛ «قارئ التفسير»؛ «اختيار التلاوة»؛ «محدد النطاق»؛ «التفسير الافتراضي»؛
«المنزَّل»؛ «المتاح»؛ «المؤلف»؛ «الطبعة أو المحقق»؛ «مصدر الرقمنة»؛ «الإصدار»؛ the
copy forms «﴿{ayah}﴾» and «﴿{ayah}﴾ [{surah}]». Added by the owner's answer O-17
(PRD §15, recommendations 3 and 4): «أبلغ عن خطأ»؛ and the step names of the first-run
setup «وضع العرض»؛ «المستوى»؛ «التلاوة».

**Appendix C — no wording anywhere (question 2 of §9).** The first-run setup's prompt
for each step and its continue button; the report sheet's lines other than its title
(what is reported, the send action, a note on what the report contains); the integrity alert for the base pack and for a downloaded
pack (title, body, action); go-to errors other than "no such ayah" (page, juz, hizb
or rub out of range, unknown surah, unreadable input); the level line of the levels
module ("always show this tool"); low space; the storage summary; the size shown
before a download; waiting for Wi-Fi; the update notice; deleting a pack; empty
states other than bookmarks (notes, search results, tafsirs, recitations, queue);
the plural forms of «موضع» in the search summary; sleep-timer minutes; the note
editor's labels; copying several ayat; the share sheet's title and "save the image"
(D-052); the add-to-queue words (D-052); the spoken repeat counter; the sources
screen's headings and each source's credit wording (`docs/SOURCES.md`, "Conditions
to confirm"); gallery titles for components that no existing key names; the bookmark's
category when it is created in two taps (question 14).

## 9. Questions for the owner

Put in one batch with `ask-owner`, recommended option first.

1. «في الخطة عبارات واجهة مأخوذة حرفيًا من نص الوثيقة (الملحق ب في `docs/plans/PHASE1.md`)، مثل «فتح التطبيق على آخر موضع» و«حجم النص» و«وضع بلا تشتيت». هل نعتمدها عناوين في الواجهة؟» — «اعتمدها كلها كما هي (موصى به)» / «سأراجعها واحدةً واحدة».
2. «عناصر لا نص لها في الوثيقة ولا في الهوية (الملحق ج): رسالة الإعداد الأول، تنبيه سلامة الحزمة، رسائل الخطأ في «اذهب إلى»، ضيق المساحة، الحالات الفارغة وغيرها. من يكتبها؟» — «يقترحها قائد العمل بنبرة الهوية وتعتمدها قبل إدخالها (موصى به)» / «أكتبها بنفسي».
3. «الوثيقة تسمّي قائمة الصوت التي تُبنى الآن «قائمة الانتظار» (والقوائم المحفوظة «قوائم التشغيل» في المرحلة 2)، ولوحة الهوية تكتب على زرها «قائمة التشغيل». أيّ اسم يظهر؟» وهل تظهر القائمة في المستوى البسيط؟ (جدول المستويات يخفي «قوائم التشغيل» فيه.) — ««قائمة الانتظار» في المرحلة 1، ظاهرة في كل المستويات، و«قوائم التشغيل» للمرحلة 2 (موصى به)» / ««قائمة التشغيل» كما في اللوحة، مخفية في المستوى البسيط».
4. «كم مهمة تعمل في وقت واحد؟ الخطة تسمح بتشغيل موجة كاملة (حتى عشر مهام على المفتاحين)، وسقف المرحلة كلها نحو 981 دولارًا، والإنفاق المتوقع أقل منه.» — «شغّل كل موجة كاملة على المفتاحين ما سمحت حدود الحساب (موصى به)» / «مهمتان في كل مرة».
5. Answered on 2026-10-12 (O-17, D-119): both adopted, the three-step first-run setup and «أبلغ عن خطأ». Questions 15 to 17 follow from it.
6. O-14: «تصنيف «تفسير» في العلامات بلا شكل ولا لون في الهوية، ولا لوحة ألوان للتصنيفات التي يضيفها المستخدم.» — «نبني التصنيفات الأربعة الموجودة الآن، ويرسم المصمم الخامس ولوحة الألوان (موصى به)» / «نستعمل لـ«تفسير» شكل «دراسة» بلون الذهب».
7. Answered on 2026-10-12 (O-04, D-119): the planning session proposes the recitations with their rights records and the owner approves. The plan asks it to prefer recitations served one file per ayah where they exist, which need no timing data to follow the recited ayah (D-112).
8. Answered on 2026-10-12 (O-06, D-119): the first release ships the Zaydi-library books only; the seven general tafsirs are deferred. Question 19 follows from it.
9. Answered on 2026-10-12 (O-03, D-119): packs are signed by a CI task with the private key held as a GitHub Actions secret; the app embeds the public key and a spare (§3.1, §3.2).
10. Answered on 2026-10-12 (O-08, D-119): test packs are hosted on this repository's GitHub Releases. Question 18 follows from it.
11. O-12: «مواضع في الهوية تباينها دون الحد المطلوب (منها مسار المفتاح وهو مطفأ، والتسمية الذهبية في بطاقة «أكمل القراءة»).» — «نقبلها مؤقتًا ونُدرجها استثناءات معلنة حتى يعدّلها المصمم (موصى به)» / «يعدّلها المصمم قبل استعمالها».
12. O-18: «هل نضيف تقارير أعطال مجهولة بموافقة المستخدم؟ بدونها لا يُقاس معدل الجلسات بلا انهيار.» — «لا في المرحلة 1، ويبقى القياس معلّقًا (موصى به)» / «نعم، وأختار الخدمة».
13. «نص الشكر الذي يطلبه كل مصدر في شاشة «المصادر والتراخيص» (تنزيل، المجمع، مركز تفسير، الخطوط).» — «نعرض لكل مصدر اسمه ورابطه ونص ترخيصه كما نشره، وتؤكد ما يلزم من أوراق الإذن (موصى به)» / «أرسل لك نص الشكر لكل مصدر».

14. «العلامة تُنشأ بلمستين من الآية، ولكل علامة تصنيف واحد. أي تصنيف تأخذ العلامة عند اللمسة الثانية؟» — «آخر تصنيف استعمله المستخدم، و«حفظ» أول مرة، ويغيّره من قائمة العلامات (موصى به)» / «تظهر حبّات التصنيفات الأربعة بعد اللمسة الثانية ليختار (لمسة ثالثة)».

15. O-17: «اعتمدتَ «أبلغ عن خطأ». إلى أين تذهب البلاغات؟ التطبيق لا يرسل شيئًا من تلقاء نفسه، ولا يجمع بيانات.» — «يفتح التطبيق بريد المستخدم برسالة جاهزة فيها موضع الآية واسم المصدر وإصداره، إلى عنوان بريد تحدده أنت، فيراها المستخدم قبل الإرسال (موصى به)» / «صفحة بلاغات في GitHub تُفتح في المتصفح».
16. O-17: «لا يرسم دليل الهوية مكانًا لـ«أبلغ عن خطأ» في شريط أدوات الآية ولا في ورقة الآية أو الكلمة ولا تحت مقطع التفسير. أين يظهر؟» — «سطر في أسفل ورقة الآية المصغّرة وفي ورقة تفاصيل المصدر، من مكوّنات الهوية الموجودة، وتراه قبل اعتماده (موصى به)» / «يرسم المصمم موضعه أولًا».
17. O-17: «في الإعداد الأولي ثلاث خطوات، لكن المرحلة 1 فيها وضع عرض واحد (السورة) حتى يصل مصحف الصفحات، ولا تلاوة جاهزة بعد. هل تُخفى الخطوة التي ليس فيها اختيار؟» — «تُخفى حتى يوجد اختيار، فيرى المستخدم الآن خطوة المستوى وحدها، وتظهر الأخريان تلقائيًا (موصى به)» / «تظهر الخطوات الثلاث دائمًا ولو بخيار واحد».
18. O-08: «الحزم التجريبية على إصدارات GitHub لهذا المستودع. إن كان المستودع خاصًا فلن يستطيع التطبيق تنزيلها دون مفتاح دخول، ولا يجوز وضع مفتاح في التطبيق.» — «إن كان خاصًا: مستودع عام للحزم وحدها تُرفع إليه الإصدارات، ويبقى الكود هنا (موصى به)» / «نجعل هذا المستودع عامًا».
19. O-06: «الوثيقة تطلب: «تفسير مختصر واحد يُنزَّل عند أول استخدام». بعد قصر الإصدار الأول على كتب المكتبة الزيدية، أيّ كتاب يكون؟» — «تقترحه جلسة التخطيط مع حزم التفاسير (B0.7) وتعتمده أنت (موصى به)» / «أحدده الآن».

Still open and unchanged by this plan: O-07 (honorific table, before any Zaydi-library
book), O-11 (store accounts, release). O-01 (application id) is deferred to M1.11 and
O-16 is answered: the licensed reciter the owner named proofreads the Hafs text (D-119).

## 10. Contradictions found while planning

- `docs/DESIGN_SYSTEM.md`, "Building a screen the identity does not draw", step 4 says
  to write strings "in the identity's tone"; this run's rules and D-115 forbid
  inventing wording. Amend step 4. (Amended in step 0.)
- `docs/WORKFLOW.md` says milestones run one at a time and two runs work at once;
  this plan runs several milestones' tasks in parallel (D-100). (Amended in step 0.)
- `docs/IMPLEMENTATION_PLAN.md` and `docs/PROJECT_STATUS.md` say Phase 1 does not open
  before Gate 0; the owner opened it (D-099). (`docs/IMPLEMENTATION_PLAN.md` amended
  in step 0; the status file is the lead's.)
- The PRD names the base pack's search forms (§10.7, §9) but format v1 has no table
  for them; format v2 adds it (D-110).
- Two agent files disagree with this plan: `ui-builder.md` writes strings "in the
  identity's tone" and does not commit; `data-builder.md` does not own `lib/config/` or
  `testing/` (step 0, item 4). (Amended in step 0.)
- D-062's sink list has no place for surah names used outside display (go-to,
  direct jump, the media notification); D-114 adds sinks.
- The Screens2 board and `docs/DESIGN_SYSTEM.md` label the queue «قائمة التشغيل»;
  the PRD calls it «قائمة الانتظار» (question 3).
- `docs/IMPLEMENTATION_PLAN.md` puts all of M1.10 behind row 6; following the
  recitation by ayah needs no timing when files are per ayah (D-112). (Amended in
  step 0.)
- `AyahRow` labels its third action «مركز الدراسة» (identity); in Phase 1 that action
  opens the mini ayah sheet, the study hub being Phase 3 (PRD §7.4). The label is the
  identity's and stays; noted for the owner's look at P1-31.
- Registry rows 9 and 10 are `Ready`, yet O-06 decides whether those tafsirs ship.
  Settled by O-06 (D-119): they are deferred; the first release ships the
  Zaydi-library books only.
