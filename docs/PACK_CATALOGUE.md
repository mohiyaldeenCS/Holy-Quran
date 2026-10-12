# Pack catalogue — format 1

This file defines `catalogue.json`, the signed list of the content packs and
recitations the app can download (D-109). A pack or recitation is added, updated or
withdrawn by publishing a new catalogue, never by an app release (`NF-19`). The app
reads it in `lib/data/models/catalogue_json.dart`; the pipeline in `tools/packs/`
writes it. Written in P1-13.

Nothing in this file is Quran text, a tafsir, a reciter or a recitation. Every value
shown below is a placeholder.

## Files and address

```
catalogue.json        UTF-8 without BOM; its exact bytes are what is signed
catalogue.json.sig    detached signature over catalogue.json
```

- The app fetches `catalogue.json` from the one HTTPS address in
  `lib/config/catalogue_config.dart`, and `catalogue.json.sig` from the same address
  with `.sig` appended to its path. Until the address is set the catalogue is "not
  configured": the app offers no download.
- The test catalogue is a release asset of this repository's GitHub Releases (O-08),
  beside the test packs. Release download URLs redirect to GitHub's storage host; the
  app follows a redirect only when it keeps the scheme (`https`) and has a host, at
  most five times. Every URL inside the catalogue follows the same rule when it is
  downloaded.
- TLS 1.2 or later (`NF-15`). A response over 4 MiB is refused.

## Signature

The scheme of D-080 and D-108, the same as a pack manifest's: `catalogue.json.sig` is
the raw 64-byte Ed25519 signature (RFC 8032) of the exact bytes of `catalogue.json`,
made by the CI task that signs packs (O-03, `docs/plans/PHASE1.md` §3.1) once
`tools/packs` can verify a catalogue. The app accepts a signature made with any key
in `lib/config/signing_keys.dart`.

| Check | Release build | Debug and profile builds |
| --- | --- | --- |
| Valid | accepted | accepted |
| Invalid | refused | refused |
| Not checked: no key in the app, or no `catalogue.json.sig` (HTTP 404) | refused | accepted, for testing |

A refused catalogue changes nothing: the app keeps the last catalogue it accepted.

## Format

```json
{
  "format": "holyquran-catalogue",
  "format_version": 1,
  "date": "YYYY-MM-DD",
  "packs": [
    {
      "id": "<pack id>",
      "kind": "tafsir",
      "version": 1,
      "title": "<title as shown>",
      "manifest": {"url": "https://<host>/<path>/manifest.json", "bytes": 1, "sha256": "<hex>"},
      "signature": "https://<host>/<path>/manifest.json.sig",
      "files": [
        {"name": "tafsir.sqlite", "url": "https://<host>/<path>/tafsir.sqlite", "bytes": 1, "sha256": "<hex>"}
      ],
      "source": "<source summary for the badge>",
      "changes": "<what this version changes>",
      "role": "first-use-tafsir"
    }
  ],
  "recitations": [
    {
      "id": "<recitation id>",
      "reciter": "<reciter as shown>",
      "riwaya": "hafs",
      "style": "<style as shown>",
      "unit": "ayah",
      "qualities": [64, 128],
      "pack": "<id of its recitation pack>",
      "rights_complete": true,
      "word_timing": false
    }
  ]
}
```

Every field is required; `signature` and `role` may be `null`. Unknown fields are
refused at every level, so a field is added only with a new format version.

### Top level

- `format` is `holyquran-catalogue`. `format_version` is `1`; any other value makes
  the catalogue unsupported, and the app keeps the last one it accepted. A new format
  is published at a new address, so that apps already installed keep reading theirs.
- `date` is the day the catalogue was published, `YYYY-MM-DD`, a calendar date.
- `packs` and `recitations` are lists; either may be empty.

### Packs

- `id` is lower-case letters, digits and `-`, beginning with a letter or digit
  (`^[a-z0-9][a-z0-9-]*$`): it becomes a directory name (D-107). Each id appears
  once: the catalogue offers one version of each pack.
- `kind` is a pack kind of `docs/CONTENT_PACKS.md`: `text`, `tafsir` or
  `recitation`. `version` is the manifest's integer, at least 1.
- `manifest` is where `manifest.json` is, with its size and lowercase hex SHA-256.
  The installer refuses a manifest that differs from them (P1-07); the manifest holds
  the hash of every file, so this hash pins the whole pack.
- `signature` is where `manifest.json.sig` is, or `null` when the pack has none. A
  pack without one is installed only where the signature policy of D-108 allows it.
- `files` lists the data files, at least one, with bare names (no `/`, `\` or `..`)
  that are unique, each with its URL, size (at least 1) and SHA-256. They repeat what
  the manifest says, so that the size is known before anything is fetched; the
  installer checks every file against the manifest. The size shown for a pack is the
  sum of `files[].bytes`; it is not stored a second time.
- `title`, `source` and `changes` are non-empty strings, shown as the catalogue gives
  them: the pack's name in the resource manager (`OF-02`), the summary of its sources
  for the badge, and what this version changes, shown with an update (`OF-06`). The
  badge itself is built from the installed manifest's `sources`.
- `role` is `null`, or `first-use-tafsir` on the one short tafsir fetched the first
  time the user opens a tafsir (`TF-06`). At most one pack has a role, and it is a
  `tafsir` pack.
- Every URL is absolute, with a scheme and a host, and no user or fragment. The app
  refuses a catalogue with a URL its download policy refuses (`https` only).

### Recitations

- `id` has the form of a pack id and appears once.
- `reciter` and `style` are non-empty strings, shown as given. `riwaya` has the form
  of the riwaya of an address (`QuranAddress.riwayaPattern`). `unit` is `ayah` or
  `surah`.
- `qualities` lists the bit rates in kbit/s the recitation pack offers, at least one,
  each at least 1, rising, without repeats.
- `pack` is the id of a `recitation` pack in `packs`; no two recitations share one.
- `rights_complete` says whether the recitation's rights record is complete
  (`docs/content/RIGHTS_REGISTER.md`). **A recitation whose record is not complete is
  never listed and never played** (`AU-01`); it may stay in the catalogue while its
  record is being completed.
- `word_timing` says whether the recitation has word timing that passed measurement
  (`SY-02`).

## Joining with the installed packs

A pack's state in the resource manager (`OF-02`, `TF-01`) follows from the catalogue
and the installer:

| Installed version | Install job | State |
| --- | --- | --- |
| any | queued, waiting, downloading, paused, verifying or stopped for space | downloading, with a percent once the size is known |
| none | none, or failed | available |
| older than the catalogue's | none, or failed | update available, with `changes` |
| the catalogue's, or newer | none, or failed | downloaded |

A failed job is shown beside the state it leaves. A pack that is installed but no
longer in the catalogue is not offered for download.

## A recitation at playback

A recitation is played from its recitation pack (`docs/CONTENT_PACKS.md`,
"Recitation pack"), which must be installed. On the first use in a session the app
verifies the pack in full (signature, manifest, file hash), checks that its riwaya,
unit and qualities are the catalogue's, that its file count is `counts.files` and
that every row is well formed, and records the outcome with the integrity
repository. A pack that fails serves nothing for the rest of the session.

The audio file of a surah or ayah at a quality is taken from the device when it is
there with the size the pack states (`<application support>/recitations/<pack
id>/<path>`), and otherwise streamed from `base_url` + `path`.

## Offline

The app keeps the last catalogue it accepted, both files, under
`<application support>/catalogue/`, and checks the copy again, signature and format,
each time it reads it. When the catalogue cannot be fetched, or the fetched one is
refused, the app serves that copy.
