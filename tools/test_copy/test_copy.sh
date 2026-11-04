#!/usr/bin/env bash
# The owner's local steps for the unapproved test copy (D-165, D-162 (13)).
#
#   tools/test_copy/test_copy.sh pack      build, verify, test and sign the pack
#   tools/test_copy/test_copy.sh install   build the profile APK, install it, push the pack
#
# Run it from Git Bash on the owner's machine, never in CI. Read
# tools/test_copy/README.md first. The pack, the keys and the APK stay outside
# Git; nothing here builds a release.
set -euo pipefail

WORK="${HQ_TEST_COPY_DIR:-$HOME/holyquran-test-copy}"
KEYS="$WORK/keys"
PACK_ID="unapproved-hafs-tanzil"
PACK_VERSION="1"
APP_ID="com.example.holyquran"
FONT="assets/fonts/AmiriQuran-Regular.ttf"
MARKS="tools/test_copy/provisional_marks.json"
APK="build/app/outputs/flutter-apk/app-profile.apk"
GRADLE_APK="build/app/outputs/apk/profile/app-profile.apk"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO"

die() {
  printf 'test_copy: %s\n' "$*" >&2
  exit 1
}

# Dart, Python and adb are Windows programs under Git Bash and need C:/ paths.
native() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}

python_command() {
  if [ -n "${PYTHON:-}" ]; then
    read -r -a PY <<<"$PYTHON"
  elif command -v py >/dev/null 2>&1; then
    PY=(py -3)
  elif command -v python3 >/dev/null 2>&1; then
    PY=(python3)
  else
    die "Python 3 was not found (py -3 or python3)"
  fi
}

require_clean_tree() {
  local when="$1" changes
  changes="$(git status --porcelain)"
  if [ -n "$changes" ]; then
    printf '%s\n' "$changes" >&2
    if [ "$when" = "before" ]; then
      die "the Git working tree is not clean (above). Commit or stash your own work first; the test copy is never built from a dirty tree."
    fi
    die "the build changed the Git working tree (above). Run 'git checkout -- .' and 'git clean -fd' only for the files listed, and never commit them. Then run this command again."
  fi
}

require_outside_git() {
  local path="$1" what="$2" probe rest
  # The folder may not exist yet, and nothing is created before it is checked:
  # test the nearest folder that does exist.
  probe="$path"
  rest=""
  while [ ! -d "$probe" ]; do
    rest="/$(basename "$probe")$rest"
    probe="$(dirname "$probe")"
  done
  if git -C "$probe" rev-parse --show-toplevel >/dev/null 2>&1; then
    die "$what ($path) is inside a Git working tree. Use a folder outside every repository, for example \$HOME/holyquran-test-copy."
  fi
  case "$(cd "$probe" && pwd -P)$rest/" in
    "$(cd "$REPO" && pwd -P)"/*) die "$what ($path) is inside the repository." ;;
  esac
  mkdir -p "$path"
}

remove_apks() {
  rm -f "$REPO/$APK" "$REPO/$APK.sha1" "$REPO/$GRADLE_APK" "$REPO/$GRADLE_APK.sha1"
}

pack_dir() {
  printf '%s/packs/%s/%s' "$WORK" "$PACK_ID" "$PACK_VERSION"
}

pack_command() {
  local config="$WORK/build.json" pack
  require_clean_tree before
  require_outside_git "$WORK" "the work folder"
  python_command
  [ -f "$config" ] || die "$config is missing. Copy tools/test_copy/build.template.json there and fill it in (README, step 3)."
  if grep -q 'FILL_IN' "$config"; then
    die "$config still has FILL_IN placeholders (README, step 3)."
  fi
  if [ ! -f "$WORK/raw/quran-uthmani.xml" ] || [ ! -f "$WORK/raw/quran-data.xml" ]; then
    die "the two source files are not in $WORK/raw (README, step 2)."
  fi
  pack="$(pack_dir)"
  [ ! -e "$pack" ] || die "$pack exists. A pack version is never rebuilt in place: remove '$WORK/packs' and '$KEYS' and run again."

  cp -f "$MARKS" "$WORK/provisional_marks.json"
  local font_native marks_native pack_native
  font_native="$(native "$REPO/$FONT")"
  marks_native="$(native "$REPO/$MARKS")"

  "${PY[@]}" tools/packs/pack.py build --unapproved-test-copy \
    --config "$(native "$config")" --font "$font_native" --out "$(native "$WORK/packs")"
  pack_native="$(native "$pack")"
  "${PY[@]}" tools/packs/pack.py verify "$pack_native" --font "$font_native" --mark-table "$marks_native"

  flutter test --exclude-tags golden \
    test/integrity test/flows/copy_text_flow_test.dart test/ui/core/share \
    --dart-define="HOLYQURAN_PACK_DIR=$pack_native"

  sign_pack "$pack" "$pack_native" "$font_native" "$marks_native"
  require_clean_tree after
  printf '\nThe pack is ready and signed: %s\nNext: tools/test_copy/test_copy.sh install\n' "$pack"
}

sign_pack() {
  local pack="$1" pack_native="$2" font_native="$3" marks_native="$4"
  local keys="$KEYS"
  require_outside_git "$keys" "the key folder"
  trap 'rm -f "$KEYS/test-copy.pem"' EXIT
  openssl genpkey -algorithm ed25519 -out "$keys/test-copy.pem"
  openssl pkey -in "$keys/test-copy.pem" -pubout -out "$keys/test-copy.pub.pem"
  openssl pkey -in "$keys/test-copy.pem" -pubout -outform DER | tail -c 32 | base64 | tr -d '\n' >"$keys/test-copy.pub.b64"
  "${PY[@]}" tools/packs/pack.py sign "$pack_native" --key "$(native "$keys/test-copy.pem")" \
    --font "$font_native" --mark-table "$marks_native"
  "${PY[@]}" tools/packs/pack.py verify-signature "$pack_native" \
    --public-key "$(native "$keys/test-copy.pub.pem")"
  rm -f "$keys/test-copy.pem"
  [ ! -e "$keys/test-copy.pem" ] || die "the private key could not be deleted: $keys/test-copy.pem"
  [ -f "$pack/manifest.json.sig" ] || die "the pack has no signature"
}

install_command() {
  local pack key device
  require_clean_tree before
  require_outside_git "$WORK" "the work folder"
  pack="$(pack_dir)"
  [ -f "$pack/manifest.json.sig" ] || die "$pack is not a signed pack. Run 'test_copy.sh pack' first."
  [ -f "$KEYS/test-copy.pub.b64" ] || die "$KEYS/test-copy.pub.b64 is missing. Run 'test_copy.sh pack' first."
  key="$(cat "$KEYS/test-copy.pub.b64")"
  device="/sdcard/Android/data/$APP_ID/files/test_copy/$PACK_ID/$PACK_VERSION"
  command -v adb >/dev/null 2>&1 || die "adb was not found"

  trap remove_apks EXIT
  flutter build apk --profile \
    --dart-define="HOLYQURAN_TEST_PACK=$PACK_ID/$PACK_VERSION" \
    --dart-define="HOLYQURAN_TEST_PACK_KEY=$key"
  require_clean_tree after
  [ -f "$APK" ] || die "$APK was not built"

  # Git Bash would turn the device paths into Windows paths.
  export MSYS_NO_PATHCONV=1
  adb install -r "$(native "$REPO/$APK")"
  adb shell mkdir -p "$device"
  adb push "$(native "$pack")/." "$device/"
  remove_apks
  require_clean_tree after
  printf '\nInstalled. Open the app: the unapproved-copy banner shows on every screen.\nThe pack is now on the phone at %s.\nClean up: rm -rf "%s/packs" "%s/keys"\n' "$device" "$WORK" "$WORK"
}

case "${1:-}" in
  pack)
    [ $# -eq 1 ] || die "usage: test_copy.sh pack"
    pack_command
    ;;
  install)
    [ $# -eq 1 ] || die "usage: test_copy.sh install (the build is always a profile build)"
    install_command
    ;;
  *)
    die "usage: test_copy.sh pack | install"
    ;;
esac
