# Plan: the local unapproved test copy

Written on 2026-11-04 by a read-only planning run in Actions (run 41829097792, `flutter-architect`
role, opus), kept here as it came. The owner's answers to its two questions are in D-162 (13)
and (14): Q1, build now with the provisional mark table; Q2, keep copy with a final marking
line and disable image sharing. So T1's `share_providers` part changes: the clipboard stays, the
copy composer appends the line, and only the share-card export is withdrawn. Decision numbers:
D-163 (T1), D-164 (T2), D-165 (T3). T2 waits until #71 is merged (both edit `app_ar.arb`).

I made the plan without editing anything. No commits, no file changes, and the only command I ran besides reading files was `flutter --version` (Flutter 3.47.9, stable). I ran no format, analyze or test commands because nothing changed.

# Plan: the local unapproved test copy (D-159 (5), D-162 (4))

## Findings that shape the plan

1. **The pipeline can't build a Hafs pack today.** `tools/packs/hqpack/build.py:49-55` refuses any profile with `needs_kfgqpc_comparison`. That covers `hafs` (`profiles.py:39-47`), until B0.2 adds the KFGQPC comparison. The build also needs the real mark table, which B0.4 delivers (`tokens.spans` stops on any letterless token not in the table). So the owner has nothing to bundle until he answers **Q1** below.
2. **The bundled base pack's signature is never enforced.** `LocalPackRepository._verify` maps `notChecked` to `signatureChecked: false`. `LocalPackIntegrityRepository`/`provideQuran` never read that flag; only the installer does (`pack_install_repository.dart:450`). D-108's rule ("once keys exist, its signature must be `valid` in release builds") is therefore not built. This doesn't block the test copy, which brings its own strict check (answer 3). B0.2 should close it, and it should be recorded.
3. **Copy and share already hide cleanly.** `mushaf_routes.dart:91-100` and `share_routes.dart` offer copy and share only when `ClipboardService` / `ShareService` are provided (D-138 (3)). Leaving them out of the composition root hides every copy and share entry, with no UI change.
4. **An asset directory entry in `pubspec.yaml` doesn't include subfolders.** A pack at `assets/packs/<id>/<version>/` would need its own `<id>/<version>/` line in pubspec. A committed static entry can't work, and Flutter fails the build when a listed directory is missing.
5. D-162 exists only on the lead's records branch (`origin/claude/quran-app-leadership-kcenv4`), not on `main`. D-163 is the next free number there.

## 1. The flag

**Mechanism.** Two defines, read in exactly one new file, `lib/config/test_copy.dart`:

```
--dart-define=HOLYQURAN_TEST_PACK=unapproved-hafs-tanzil/1
--dart-define=HOLYQURAN_TEST_PACK_KEY=<base64 of the 32-byte Ed25519 public key>
```

```dart
const _pack = String.fromEnvironment('HOLYQURAN_TEST_PACK');
const _key = String.fromEnvironment('HOLYQURAN_TEST_PACK_KEY');

/// The unapproved test copy (D-159 (5), D-163); null in every normal build.
final TestCopy? testCopy = TestCopy.parse(_pack, _key, release: kReleaseMode);

final class TestCopy {
  final ({String id, int version}) pack;
  final List<int> publicKey;
  /// Null when [pack] is empty. Throws a StateError when [release] and [pack]
  /// is not empty, or when [key] is one of [productionKeys], or when the id
  /// does not begin with `unapproved-`; a FormatException when [pack] is not
  /// `<id>/<version>` or [key] is not base64 of 32 bytes.
  static TestCopy? parse(String pack, String key,
      {required bool release, List<List<int>> productionKeys = manifestPublicKeys});
}
```

- `lib/config/base_pack.dart` keeps `bundledBasePack` as the const `null`: it stays the *approved* pack, added by B0.2. It gains:
  ```dart
  ({String id, int version})? get basePackInUse => testCopy?.pack ?? bundledBasePack;
  ```
- With no define, `testCopy` is null, so `quranProviders` behaves exactly as today. In release builds the const `_pack` is `''`, so the branch is tree-shaken.

**How a release build is refused (three layers):**

1. **At start (primary).** `lib/main.dart` reads `testCopy` before `runApp`. In release with the define it throws a `StateError`, and the app crashes on launch, so it can never run by accident.
2. **The build script never builds release.** `tools/test_copy/test_copy.sh` hard-codes `flutter build apk --profile`. Profile is AOT and fast, and `kReleaseMode` is false there.
3. **At build time (optional, recommended).** `android/app/build.gradle.kts` decodes the `dart-defines` Gradle property (comma-separated base64, which is how the Flutter tool passes it; to be confirmed on 3.47.9). If it finds `HOLYQURAN_TEST_PACK=`, it makes every `assemble*Release` and `bundle*Release` task fail with a `GradleException` naming D-159 (5). It's checked once by hand: `flutter build apk --release --dart-define=HOLYQURAN_TEST_PACK=unapproved-x/1` must fail. This command contains no pack, so it doesn't break the owner's condition. A Dart compile-time assert isn't possible here: asserts are off in release, including const-constructor asserts.

**How tests prove it:**
- `test/config/test_copy_test.dart` checks each of these cases:
  - `parse('', '', release: true)` returns null.
  - `parse('unapproved-x/1', k, release: true)` throws a `StateError`.
  - Malformed `<id>/<version>`, a missing or short key, an id without `unapproved-`, or a key equal to one in `productionKeys` all throw.
  - A valid call with `release: false` returns the record.
- A guard test, `test/guards/test_copy_guard_test.dart`, checks that:
  - `HOLYQURAN_TEST_PACK` is read only in `lib/config/test_copy.dart`.
  - `lib/main.dart` reads `testCopy` before `runApp`.
  - `DevicePackBundle` is built only in `quran_providers.dart`.

## 2. The asset: recommend loading from the device's files, not the bundle

| Option | Verdict |
| --- | --- |
| A. A script edits `pubspec.yaml` (adds `assets/packs/<id>/<v>/`), builds, then restores it | Works, but the working tree carries a change that would break CI if committed. Restoring it relies on a `trap EXIT` that doesn't run if the Git Bash window is closed or killed, or if the IDE stages files. The resulting APK holds the unapproved text, and that file can be shared by mistake. Also rejected under "push after every commit": one `git commit -a` at the wrong moment pushes a broken pubspec. |
| B. A flavor or a second entry point with flavored assets | Needs Android `productFlavors` and iOS schemes (platform folders). The flavored directory still has to name `<id>/<version>` and still has to exist wherever pubspec is parsed, so CI breaks or a placeholder is needed under the ignored `assets/packs/`. Too heavy. |
| **C. Read the pack from the app's external files directory, pushed with `adb` (recommended)** | No committed or uncommitted change to pubspec, nothing ever under `assets/packs/`, and **the APK holds no Quran text at all**, so a shared APK is harmless. The pack exists only on the phone (and briefly on the machine). Everything already built is reused: `BasePackService` already takes an `AssetBundle?`, copies into `<support>/packs/<id>/<version>/`, verifies, and opens it immutable (D-061, D-107). |

**How C works.**
- New file `lib/data/services/device_pack_bundle.dart`:
  ```dart
  /// The packs a test copy reads from the device's files (D-163): the key
  /// `assets/packs/<id>/<version>/<name>` is the file `<root>/<id>/<version>/<name>`.
  /// A missing file, or any other key, throws a FlutterError as rootBundle does.
  final class DevicePackBundle extends AssetBundle {
    DevicePackBundle(this._root);           // Future<Directory?> Function()
    static Future<Directory?> testCopyRoot(); // getExternalStorageDirectory()/test_copy; null on iOS (UnsupportedError)
    @override Future<ByteData> load(String key);
  }
  ```
- On Android the folder is `/storage/emulated/0/Android/data/com.example.holyquran/files/test_copy/unapproved-hafs-tanzil/1/{manifest.json,manifest.json.sig,text.sqlite}`.
- `adb push` can write there without root, and the folder is removed when the app is uninstalled.
- A missing file reads as `IntegrityMissing`, the existing state, so no text is shown.
- Only `AssetBundle.load` is abstract (checked in the SDK), so the class is small.
- It only reads, so the pack-write guard is untouched.

**Guards in the script (`tools/test_copy/test_copy.sh`, content-engineer):**
- It refuses to run unless `git status --porcelain` is empty.
- It runs the same check after `flutter build`. If the build rewrote anything (for example `pubspec.lock` on 3.47.9 against the CI pin), it stops and tells the owner to run `git checkout -- .`, never to commit.
- It refuses a pack, key or output path inside the Git working tree (`git -C <path> rev-parse --show-toplevel` succeeds).
- It deletes `build/app/outputs/flutter-apk/app-profile.apk*` after `adb install`.

## 3. The signature: recommend a define-given test key with a required `valid` signature

- `lib/data/services/manifest_signature.dart` gains:
  ```dart
  /// [SignatureCheck.notChecked] becomes [SignatureCheck.invalid]: a pack
  /// with no signature file is refused (D-163).
  final class SignatureRequired implements ManifestSignatureVerifier {
    const SignatureRequired(this._inner);
  }
  ```
- `quranProviders` uses, for the test copy only:
  `SignatureRequired(Ed25519ManifestVerifier([copy.publicKey]))`
- This makes the test copy *stricter* than today's base pack path: no signature, or a wrong one, gives `SignatureRejected`, the integrity alert, and no text. It also runs the exact signing path B0.2 will use.

**Why release stays strict:**
- `manifestPublicKeys` (`lib/config/signing_keys.dart`) is never touched.
- The define is refused in release (answer 1).
- The test key is accepted only for the base pack in the test copy, never by the installer, the catalogue or tafsir.

**Use a separate, throwaway key, never the production key of D-140 (8).** Signing an unapproved pack with the production key would give it a signature every future release accepts. `TestCopy.parse` refuses a test key that appears in `manifestPublicKeys`. I recommend a fresh test key per build, deleted after signing: it needs no safekeeping, and the matching public key travels in the define.

**Rejected:** the unchecked path of D-108 limited to the flag. It works, but it adds a second policy switch and tests nothing B0.2 needs.

## 4. The marking

- **Where.** One persistent strip above the whole navigator, built once in `QuranApp`'s `MaterialApp.router(builder:)` (`lib/ui/core/app.dart`). Every route, sheet and dialog sits inside that navigator, so the strip shows on the reader, search results, the context, word and tafsir sheets, the copy and share sheets, and every other screen. It also shows in every screenshot.
- **What.** The existing `IntegrityAlert(title: l10n.unapprovedTestCopy)`: the `alert` icon and the title in `error`, `bodyStrong`. That is the identity's warning pattern (PRD §7.7). New widget `lib/ui/core/widgets/unapproved_copy_banner.dart`:
  - background `colors.surface`;
  - `SafeArea(bottom: false)` so it sits under the status bar;
  - padding `AppSpacing.space4` horizontal and `space2` vertical;
  - separated from the content by the identity's existing 1 px `line` hairline, as a named constant citing its source;
  - `Semantics(container: true)`.
- **Layout.** `Column([UnapprovedCopyBanner(), Expanded(child: MediaQuery.removePadding(removeTop: true, child: child))])`, so the status-bar inset is used once.
- **Switch.** `QuranApp({required this.router, this.unapprovedCopy = false})`. `lib/main.dart` passes `unapprovedCopy: testCopy != null` through `AppStart`, so the UI doesn't import `lib/config`.
- **String.** `lib/l10n/app_ar.arb`: `"unapprovedTestCopy": "نسخة تجريبية غير معتمدة"`, approved in D-162 (4), with an English `@description`. Regenerate the localizations.
- **Copy and share: recommend hiding them in the test copy.** `share_providers.dart` returns without providing `ClipboardService` and `ShareService` when `testCopy != null`. Every copy and share entry then disappears through the existing seams (finding 3).
  - The share image can't carry the marking without changing the drawn share card (the identity is closed).
  - Adding a line to copied text would be a new copy format the owner hasn't approved (D-115).
  - Hiding both means the text can never leave the phone looking approved.
  - Cost: tafsir copy is hidden too, and the copy and share sheets can't be checked on this build (their goldens and flow tests still cover them).
  - **This is Q2 for the owner.** Build it only after he answers.

## 5. The owner's local steps (Git Bash on Windows, Flutter 3.47.9 in `C:/SDK/flutter`)

Work folder: `TC="$HOME/holyquran-test-copy"`, **outside the repository**. Dart needs Windows paths, so every path passed to Flutter goes through `cygpath -m`.

1. **Update the repo.** `git switch main && git pull && git status`. The tree must be clean. Check the tools: `py -3 --version` (3.9 or later, with SQLite 3.37 or later), `openssl version` (3.x, shipped with Git for Windows), `adb devices`.
2. **Fetch the Tanzil sources** (row 1 and row 4 of `docs/SOURCES.md`, CC BY 3.0: verbatim only, credit Tanzil with a link, keep the notice).
   - Read and accept Tanzil's terms on tanzil.net yourself.
   - `mkdir -p "$TC/raw" && curl -fL -o "$TC/raw/quran-uthmani.xml" 'https://tanzil.net/pub/download/index.php?quranType=uthmani&outType=xml&marks=true&sajdah=true&rub=false&agree=true'` (`rub=false` per D-079).
   - Download the metadata `quran-data.xml` into `$TC/raw/` (content-engineer confirms the exact URL in the README).
   - `sha256sum "$TC"/raw/*`.
   - Output: `$TC/raw/`. Never committed.
3. **Write the build description.** `cp tools/test_copy/build.template.json "$TC/build.json"`, then fill in `fetched_on` and the two `file_sha256` values from step 2. `reviews` stays `[]`. Output: `$TC/build.json`.
4. **Build the pack.**
   `py -3 tools/packs/pack.py build --unapproved-test-copy --config "$TC/build.json" --font assets/fonts/AmiriQuran-Regular.ttf --out "$TC/packs"`
   Then: `py -3 tools/packs/pack.py verify "$TC/packs/unapproved-hafs-tanzil/1" --font assets/fonts/AmiriQuran-Regular.ttf --mark-table tools/test_copy/provisional_marks.json`.
   - Output: `$TC/packs/unapproved-hafs-tanzil/1/`. Never committed, never uploaded.
   - If the build stops on a `U+XXXX`, report the code point. Never edit the source.
5. **Run the integrity suite on the pack.**
   `P=$(cygpath -m "$TC/packs/unapproved-hafs-tanzil/1"); flutter test test/integrity test/flows/copy_text_flow_test.dart test/ui/core/share --dart-define=HOLYQURAN_PACK_DIR="$P"`
   Every test must pass. A failure means stop and report, never adjust.
6. **Generate a throwaway test key.** Not the production key of D-140 (8).
   `mkdir -p "$TC/keys" && openssl genpkey -algorithm ed25519 -out "$TC/keys/test-copy.pem" && openssl pkey -in "$TC/keys/test-copy.pem" -pubout -out "$TC/keys/test-copy.pub.pem"`
   `KEY=$(openssl pkey -in "$TC/keys/test-copy.pem" -pubout -outform DER | tail -c 32 | base64 -w0)`
7. **Sign.**
   `py -3 tools/packs/pack.py sign "$TC/packs/unapproved-hafs-tanzil/1" --key "$TC/keys/test-copy.pem" --font assets/fonts/AmiriQuran-Regular.ttf --mark-table tools/test_copy/provisional_marks.json`
   then `py -3 tools/packs/pack.py verify-signature "$TC/packs/unapproved-hafs-tanzil/1" --public-key "$TC/keys/test-copy.pub.pem"`.
   Then delete the private key: `rm "$TC/keys/test-copy.pem"`.
8. **Build the APK** (profile only; the script refuses anything else and checks `git status` before and after).
   `flutter build apk --profile --dart-define=HOLYQURAN_TEST_PACK=unapproved-hafs-tanzil/1 --dart-define=HOLYQURAN_TEST_PACK_KEY="$KEY"`
   Output: `build/app/outputs/flutter-apk/app-profile.apk` (git-ignored `/build/` and `*.apk`). It holds no Quran text.
9. **Install and push the pack.**
   `adb install -r build/app/outputs/flutter-apk/app-profile.apk`
   `adb shell mkdir -p /sdcard/Android/data/com.example.holyquran/files/test_copy/unapproved-hafs-tanzil/1`
   `adb push "$TC/packs/unapproved-hafs-tanzil/1/." /sdcard/Android/data/com.example.holyquran/files/test_copy/unapproved-hafs-tanzil/1/`
   Then open the app. «نسخة تجريبية غير معتمدة» shows on every screen. Keep the pushed files while using the copy: the app re-reads the manifest at each start.
10. **Clean up.**
    `rm -rf "$TC/packs" "$TC/keys"` and `rm -f build/app/outputs/flutter-apk/app-profile.apk*`, then `git status`, which must be clean.
    The pack now exists only on the phone. To remove it there: `adb uninstall com.example.holyquran`. That also erases the test copy's bookmarks and settings.

Steps 4 to 10 are wrapped by `tools/test_copy/test_copy.sh pack` (steps 4 to 7) and `test_copy.sh install` (steps 8 to 10).

**Never committed or uploaded:** `$TC/**`, any `*.apk`, `assets/packs/**`, any key, and the pushed files. With option C, nothing ever enters the repository's tree.

## 6. Builder tasks, in order

The lead writes no code (D-159 (1)), so the lead's files (`lib/main.dart`, `lib/config/`, `android/`) go to `data-builder` with the files named in the task, as D-151 did. No two tasks own the same file.

**Wave 1 (parallel):**

- **T2 `ui-builder`: the marking (D-164).**
  - Files: `lib/ui/core/widgets/unapproved_copy_banner.dart` (new); `lib/ui/core/app.dart` (`unapprovedCopy` parameter, builder wrap); `lib/l10n/app_ar.arb` plus the regenerated `lib/l10n/app_localizations*.dart`; a gallery entry under `lib/ui/core/gallery/sections/`.
  - Tests:
    - `test/ui/core/widgets/unapproved_copy_banner_test.dart`: semantics, all four themes, text scale 200%, plus a `golden`-tagged test with no `.png` (CI makes it).
    - `test/ui/core/app_test.dart`: the banner shows above a route and above an open sheet when the flag is on, is absent when it's off, and the status-bar inset is used once.
    - The contrast check for `error` on `surface` in `test/guards/contrast_pairs.dart`, if that pair isn't already listed (coordinate with test-engineer; ui-builder only proposes the row).
- **T3 `content-engineer`: the pipeline's test-copy mode. Gated on Q1 (D-165).**
  - Files:
    - `tools/packs/hqpack/profiles.py`: `UNAPPROVED_ID_PREFIX = "unapproved-"`; `profile_for(riwaya, pack_id, unapproved=False)` allows `unapproved` only for `hafs` and exactly when the id has the prefix.
    - `tools/packs/hqpack/build.py`: `build_pack(..., unapproved=False)` skips only the KFGQPC refusal; with `unapproved` it requires `reviews == []` and refuses an `out_root` inside a Git working tree.
    - `tools/packs/hqpack/cli.py`: `build --unapproved-test-copy`.
    - `tools/test_copy/provisional_marks.json`: the Unicode Quranic annotation signs U+06D6–U+06ED without U+06DE, from the Unicode chart, not from the text; B0.4 replaces it.
    - `tools/test_copy/build.template.json`: id `unapproved-hafs-tanzil`, version 1, the registry fields of rows 1 and 4, the licence reference, `reviews: []`.
    - `tools/test_copy/test_copy.sh`: `pack` and `install`, with the guards of answer 2.
    - `tools/test_copy/README.md`: the steps of answer 5.
    - The `tools/packs/README.md` sections "Checks" and "Not done here".
  - Tests: `tools/packs/tests/test_profiles.py`, `test_build.py` and `test_cli.py`. The flag is refused without the prefix, the prefix without the flag, any riwaya other than hafs, a non-empty `reviews`, and an output inside a Git tree. `synthetic` is unchanged. A plain `hafs` build is still refused. Plus `bash -n tools/test_copy/test_copy.sh`.

**Wave 2 (after T2 is merged, so `QuranApp(unapprovedCopy:)` exists):**

- **T1 `data-builder`: flag, device bundle, signature, wiring (D-163).**
  - Files:
    - `lib/config/test_copy.dart` (new).
    - `lib/config/base_pack.dart` (`basePackInUse`).
    - `lib/data/services/device_pack_bundle.dart` (new).
    - `lib/data/services/manifest_signature.dart` (`SignatureRequired`).
    - `lib/config/providers/quran_providers.dart`: the test-copy branch first, then `bundledBasePack`.
    - `lib/config/providers/pack_install_providers.dart`: `packInstallProviders` passes `basePack: basePackInUse`, so the test id is reserved.
    - `lib/config/providers/share_providers.dart`: no clipboard or share service in the test copy. **Only after Q2.**
    - `lib/main.dart`: read `testCopy` before `runApp`, pass `unapprovedCopy` to `AppStart` and then `QuranApp`.
    - Optional: `android/app/build.gradle.kts`, the release refusal.
  - Tests:
    - `test/config/test_copy_test.dart`.
    - `test/data/services/device_pack_bundle_test.dart`: temporary directory, missing file gives `FlutterError`, a foreign key is refused, a null root (iOS) reads as missing.
    - `test/data/services/manifest_signature_test.dart`: `SignatureRequired` gives valid→valid, notChecked→invalid, invalid→invalid.
    - `test/config/providers/quran_providers_test.dart`: a synthetic pack signed with a test key generated in the test is served through `DevicePackBundle`; unsigned or wrong-key packs give `IntegrityFailed(SignatureRejected)` and no `QuranTextRepository`.
    - `test/config/providers/pack_install_providers_test.dart`: the test id is reserved.

**Wave 3 (after T1 and T2):**

- **T4 `test-engineer`: guards and the flow (no D-number of its own; it cites D-163 and D-164).**
  - Files:
    - `test/guards/test_copy_guard_test.dart`: the define is read only in `test_copy.dart`; `main.dart` reads `testCopy` before `runApp`; `getExternalStorageDirectory` appears only in `device_pack_bundle.dart`; `pubspec.yaml`'s `flutter.assets` never lists `assets/packs` other than `bundledBasePack`'s directory.
    - `test/flows/test_copy_flow_test.dart`: the app over a signed synthetic pack read through `DevicePackBundle` shows the banner on home, the reader, search results and the ayah sheet, with no copy or share entry. An unsigned pack shows the integrity alert and no text.
    - Shared helpers under `testing/` if needed (test key generation).

T3 doesn't depend on T1, T2 or T4. Without the Q1 answer, T1, T2 and T4 can still be built and merged: the flag is inert without a pack.

## 7. Risks

1. **The pack can't be built yet** (finding 1). Q1 decides whether the test copy skips the KFGQPC comparison and uses a provisional mark table, or waits for B0.2, B0.3 and B0.4.
2. **The provisional mark table could be wrong.** A wrong table can't silently change a word: a token with a letter is always a word. It can only make the build stop and name a `U+XXXX`, which the owner reports.
3. **Signing with the production key** would give an unapproved pack a signature every release accepts. Answer 3 prevents it: a separate throwaway key, and `parse` refuses a test key that is also a production key.
4. **The D-108 gap** (finding 2): a release build with keys would still accept an unsigned *bundled* base pack. B0.2 should wrap the base pack's verifier in `SignatureRequired` when `kReleaseMode && manifestPublicKeys.isNotEmpty`.
5. **`adb push` into `Android/data`** works from the adb shell on current Android versions, but some vendor builds restrict it. Fallback: a debug build plus `adb push` to `/data/local/tmp/` and `adb shell run-as com.example.holyquran cp -r …`. `DevicePackBundle` would then need the app's files directory as its root, so decide before T1 if the owner's phone refuses.
6. **Git Bash path conversion** of `/c/...` in defines. Always use `cygpath -m`.
7. **A local `flutter build` rewriting `pubspec.lock`** on 3.47.9. The script checks `git status` before and after and never commits.
8. **The test copy is Android only.** On iOS, `getExternalStorageDirectory` is unsupported, so the bundle root is null and the pack reads as missing.
9. **Leftover verified copy.** Installing an approved build over the test copy leaves the verified copy in `<support>/packs/unapproved-hafs-tanzil/1/`. It isn't read (different id) but stays on the phone. `adb uninstall` first removes it, and also the test user data.
10. **A screenshot cropped to remove the banner.** The banner is on every screen, but a crop can still drop it. That's a limit to tell the owner, not something the app can enforce.
11. **Hiding copy hides tafsir copy too** while the test copy is on.

## Questions for the owner (in Arabic, recommended option first)

**س١ — بناء النسخة التجريبية قبل اكتمال الفحوص الآلية:** أداة بناء الحزم ترفض اليوم بناء حزمة حفص لأن المقارنة الآلية حرفًا بحرف مع نص مجمع الملك فهد (B0.2/B0.3) وجدول رموز العلامات (B0.4) لم يُنجزا بعد. ماذا تختار؟
- (موصى به) تُبنى النسخة التجريبية دون المقارنة الآلية وبجدول علامات مؤقت مأخوذ من جدول يونيكود، مع بقاء كل فحوص السلامة الأخرى، وتبقى موسومة «نسخة تجريبية غير معتمدة» على هاتفك وحده.
- لا تُبنى النسخة التجريبية حتى تكتمل المقارنة الآلية وجدول العلامات.

**س٢ — النسخ والمشاركة في النسخة التجريبية:**
- (موصى به) يُخفى النسخ والمشاركة تمامًا في النسخة التجريبية، فلا يخرج نصها من الهاتف أبدًا (ولا يمكن فحص صفحتي النسخ والمشاركة على هذه النسخة).
- يبقى النسخ ويُضاف إلى النص المنسوخ سطر «نسخة تجريبية غير معتمدة»، وتُعطَّل مشاركة الصورة لأن بطاقتها لا تحمل الوسم دون تغيير تصميمها (يحتاج موافقتك على صيغة النص المنسوخ).

## What `docs/PROJECT_STATUS.md` should record

- The test-copy plan exists. Tasks T2 and T3 run first in parallel (T3 only once Q1 is answered), then T1, then T4. The `share_providers` part of T1 waits for Q2.
- Q1 and Q2 are open, with the wording above.
- Follow-up for B0.2: enforce the bundled base pack's signature in release (finding 2 and risk 4).
- The first device session (D-162 (9)) follows `tools/test_copy/README.md` once T1 to T4 are merged and Q1 is answered.

## What `docs/DECISIONS.md` should record

- **D-163.** The unapproved test copy (D-159 (5)):
  - the defines `HOLYQURAN_TEST_PACK=<id>/<version>` (id begins `unapproved-`) and `HOLYQURAN_TEST_PACK_KEY`, read only in `lib/config/test_copy.dart`;
  - refused at start in release builds, built only as a profile APK by `tools/test_copy/test_copy.sh`, with an optional Gradle refusal of release tasks;
  - the pack is read from the app's external files directory through `DevicePackBundle` and pushed with `adb`, never bundled, so no APK holds it and `pubspec.yaml` is never edited;
  - its signature must be `valid` against a throwaway test key that is never a production key (`SignatureRequired`), and `manifestPublicKeys` is unchanged;
  - its id is reserved from the installer.
- **D-164.** The marking: `IntegrityAlert` with «نسخة تجريبية غير معتمدة» (D-162 (4)) in one strip above the navigator, on every screen and sheet. Copy and share are hidden in the test copy (subject to Q2).
- **D-165** (once Q1 is answered). `pack.py build --unapproved-test-copy`: `hafs` only, id prefix `unapproved-`, `reviews` empty, output outside the Git tree; it skips only the KFGQPC comparison. It uses the provisional mark table `tools/test_copy/provisional_marks.json` until B0.4.
- **A note under D-108.** The bundled base pack's `valid`-in-release rule isn't built yet; B0.2 builds it.
