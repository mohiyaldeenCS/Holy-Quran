# tools/test_copy — the unapproved test copy on the owner's phone

Builds the Hafs text pack from Tanzil's files on the owner's own Windows machine, and
puts it, with a profile build of the app, on his own phone. Task B0.11; D-159 (5),
D-162 (13), D-165.

**What the copy is.** A pack whose text no proofreader has approved and which was not
compared with the KFGQPC text (B0.2, B0.3). Every other check of the pipeline ran. The
app marks it «نسخة تجريبية غير معتمدة». It exists on the owner's machine and phone
only: never in Git, never on GitHub, never in a release, never in an APK, never in
`assets/packs/`. The pipeline's own refusals are in `tools/packs/README.md` ("Test-copy
mode").

**What is in this folder** (none of it is Quran text):

| File | Is |
| --- | --- |
| `test_copy.sh` | `pack`: build, verify, run the app's integrity tests, sign with a throwaway key, delete the private key. `install`: build the profile APK, install it, push the pack to the phone, delete the APK |
| `build.template.json` | The build description: id `unapproved-hafs-tanzil`, version 1, the registry fields of rows 1 and 4 of `docs/SOURCES.md`, `reviews: []`, and placeholders (`FILL_IN…`) for what only the owner knows |
| `provisional_marks.json` | The mark table the build needs until B0.4 delivers the real one, see below |

The `install` step needs an app that reads the test copy (D-163, D-164: the two
`--dart-define`s and the banner). Until those are merged into the branch you are on, the
APK ignores them and shows no text.

## The owner's steps (Git Bash, Windows)

Everything below runs in Git Bash from the repository folder. The work folder is
outside the repository, so nothing can be committed by accident:

```
TC="$HOME/holyquran-test-copy"
```

1. **Update the repository and check the tools.**
   ```
   git switch main && git pull && git status
   py -3 --version && openssl version && adb devices && flutter --version
   ```
   `git status` must say the tree is clean. Python 3.9 or later with SQLite 3.37 or
   later, OpenSSL 3 (it ships with Git for Windows), `adb` with the phone listed.

2. **Fetch the two Tanzil files yourself** (rows 1 and 4 of `docs/SOURCES.md`; CC BY 3.0:
   verbatim only, credit Tanzil with a link, keep the notice). Read and accept Tanzil's
   terms on tanzil.net first.
   ```
   mkdir -p "$TC/raw"
   curl -fL -o "$TC/raw/quran-uthmani.xml" 'https://tanzil.net/pub/download/index.php?quranType=uthmani&outType=xml&marks=true&sajdah=true&agree=true'
   curl -fL -o "$TC/raw/quran-data.xml" 'https://tanzil.net/res/text/metadata/quran-data.xml'
   sha256sum "$TC"/raw/*
   ```
   The text address follows Tanzil's download form (D-079): a checkbox that is off is
   left out of the address, because the server reads whether a parameter is there, not
   its value, so `rub=false` would switch the rub-el-hizb sign **on**. `rub`, `tatweel`
   and `stanween` are therefore omitted; the pipeline refuses `=false` on any of the five
   boxes. The metadata address is the one on Tanzil's Quran Metadata page
   (tanzil.net/docs/Quran_Metadata, "Latest release: ver 1.0") and is already in the
   template. Do not edit, save again or re-encode either file: open nothing in an editor.

3. **Write the build description.**
   ```
   cp tools/test_copy/build.template.json "$TC/build.json"
   head -c 400 "$TC/raw/quran-data.xml"
   ```
   The second command shows the head of the metadata file: it has no notice comment, and
   its root element `<quran type="metadata" version="1.0" ...>` names the metadata
   `version` (`1.0` for the current file). Open `$TC/build.json` and replace every
   `FILL_IN…`: `fetched_on` of both sources (the date of step 2, `YYYY-MM-DD`),
   `file_sha256` of each (the two hashes printed by `sha256sum`), and the metadata
   `version` (the root element's `version` attribute, `1.0`). Leave `reviews` as `[]`, and
   everything else as it is. The build stops if a hash or a version does not match, or if
   the metadata file has no `version` attribute.

4. **Build, verify, test and sign the pack.**
   ```
   tools/test_copy/test_copy.sh pack
   ```
   What it does, in this order: refuses a dirty Git tree; refuses a work folder inside
   any Git tree; builds with `pack.py build --unapproved-test-copy`; runs `pack.py
   verify` with the font and the provisional mark table; runs `flutter test
   --exclude-tags golden test/integrity test/flows/copy_text_flow_test.dart
   test/ui/core/share` against the pack through `--dart-define=HOLYQURAN_PACK_DIR`;
   makes a throwaway Ed25519 key in `$TC/keys`, signs, checks the signature with the
   public key, and deletes the private key (also when a step fails); checks the Git tree is still clean. If a killed run left `$TC/keys/test-copy.pem`, both `pack` and `install` refuse to run until you delete it.
   Output: `$TC/packs/unapproved-hafs-tanzil/1/` and `$TC/keys/test-copy.pub.b64`.
   - If it stops on a `U+XXXX`, a count or a hash: **report the message to the lead,
     with the code point or number, and stop.** Never edit a source file, the mark
     table or a test to get past it.
   - The pack is built once per version. To build again: `rm -rf "$TC/packs" "$TC/keys"`.

5. **Install on the phone.**
   ```
   tools/test_copy/test_copy.sh install
   ```
   It checks the tree is clean, runs `flutter build apk --profile` (never release) with
   `--dart-define=HOLYQURAN_TEST_PACK=unapproved-hafs-tanzil/1` and
   `--dart-define=HOLYQURAN_TEST_PACK_KEY=<the public key>`, checks the tree is still
   clean (if the build changed a file it stops and prints one exact command per file, `git checkout -- <file>` for a
   modified tracked file or `git clean -f -- <file>` for a new one; run only those, and never commit the files), installs the APK with `adb install -r`, pushes the
   pack to
   `/sdcard/Android/data/com.example.holyquran/files/test_copy/unapproved-hafs-tanzil/1/`,
   and deletes the APK, including Gradle's own copy under
   `build/app/outputs/apk/profile/`. Open the app: once D-163 and D-164 are merged into the branch you are on, «نسخة تجريبية غير معتمدة» shows on every screen.
   Keep the pushed files while you use the copy; the app reads them at every start.

   What this does to the phone: USB debugging must be on and the phone authorised for
   this computer. `adb install -r` **replaces** any installed `com.example.holyquran`,
   keeping its data. If the installed app was signed on another machine (for example an
   APK from CI), the install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. The only
   way out is `adb uninstall com.example.holyquran`, which **erases the app's data**
   (bookmarks, notes, settings). Decide that yourself; the script never does it.

6. **Clean up the computer.**
   ```
   rm -rf "$TC/packs" "$TC/keys"
   git status
   ```
   `git status` must still be clean. The pack now exists only on the phone. To remove
   it there without touching the app's data:
   `adb shell rm -r /sdcard/Android/data/com.example.holyquran/files/test_copy`.
   `adb uninstall com.example.holyquran` removes the pack too, but also erases the
   app's bookmarks, notes and settings. Keep `$TC/raw` and `$TC/build.json` if you want to build
   again; they are outside the repository.

`HQ_TEST_COPY_DIR` replaces `$HOME/holyquran-test-copy` as the work folder; it must be
outside every Git working tree, and the script refuses one that is not. `PYTHON`
replaces the Python command (`py -3` on Windows, else `python3`). `ANDROID_SERIAL`
picks the phone when more than one is connected.

## Never committed, never uploaded

- Anything under `$TC` (the two Tanzil files, `build.json`, the pack, the keys).
- Any `*.apk` and `build/`; any file under `assets/packs/`.
- Any signing key, public or private; the pack files pushed to the phone.
- The output of any command that printed Quran text. The tools print paths, counts,
  hashes and `U+XXXX` only; do not paste the source files anywhere.

The signing key is made new for each build and the private half is deleted at once.
It is never the production key of D-140 (8): a pack signed with that key would be
accepted by every future release.

## The provisional mark table

`provisional_marks.json` lists the code points of the Arabic block's Quranic annotation
signs, U+06D6 to U+06ED, from the Unicode chart, in the format `mark_table.py` reads.
These are the 21 code points, with their Unicode names (from Python's `unicodedata`):

| Code point | Unicode name |
| --- | --- |
| `U+06D6` | ARABIC SMALL HIGH LIGATURE SAD WITH LAM WITH ALEF MAKSURA |
| `U+06D7` | ARABIC SMALL HIGH LIGATURE QAF WITH LAM WITH ALEF MAKSURA |
| `U+06D8` | ARABIC SMALL HIGH MEEM INITIAL FORM |
| `U+06D9` | ARABIC SMALL HIGH LAM ALEF |
| `U+06DA` | ARABIC SMALL HIGH JEEM |
| `U+06DB` | ARABIC SMALL HIGH THREE DOTS |
| `U+06DC` | ARABIC SMALL HIGH SEEN |
| `U+06DD` | ARABIC END OF AYAH |
| `U+06DF` | ARABIC SMALL HIGH ROUNDED ZERO |
| `U+06E0` | ARABIC SMALL HIGH UPRIGHT RECTANGULAR ZERO |
| `U+06E1` | ARABIC SMALL HIGH DOTLESS HEAD OF KHAH |
| `U+06E2` | ARABIC SMALL HIGH MEEM ISOLATED FORM |
| `U+06E3` | ARABIC SMALL LOW SEEN |
| `U+06E4` | ARABIC SMALL HIGH MADDA |
| `U+06E7` | ARABIC SMALL HIGH YEH |
| `U+06E8` | ARABIC SMALL HIGH NOON |
| `U+06E9` | ARABIC PLACE OF SAJDAH |
| `U+06EA` | ARABIC EMPTY CENTRE LOW STOP |
| `U+06EB` | ARABIC EMPTY CENTRE HIGH STOP |
| `U+06EC` | ARABIC ROUNDED HIGH STOP WITH FILLED CENTRE |
| `U+06ED` | ARABIC SMALL LOW MEEM |

It leaves out:

- U+06DE (ARABIC START OF RUB EL HIZB), which D-079 keeps out of the text, and
- U+06E5 and U+06E6 (ARABIC SMALL WAW, ARABIC SMALL YEH), which Unicode classifies as letters
  (category Lm). The pipeline never takes a letter for a mark (D-083), and
  `mark_table.py` refuses a table that lists one, so such a token is a word and needs no
  entry.

`tests/test_test_copy.py` pins the file to exactly that set. B0.4 delivers the real
table from the KFGQPC text with the proofreader, and replaces this file; this one is for
the test copy only. The pipeline stops, naming the code point, on any letterless token
outside the table: that is a report to the lead, never a reason to add a code point by
hand.
