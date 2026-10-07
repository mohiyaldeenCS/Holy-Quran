#!/bin/bash
# Installs the pinned Flutter SDK (D-040) in Claude Code cloud sessions, which start
# without one, so that format, analyze and test can run and the Dart MCP server finds
# `dart` on the PATH.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Pinned by D-040; also in .github/workflows/ci.yml.
FLUTTER_VERSION="3.44.7"
SDK_DIR="$HOME/sdk/flutter"
ARCHIVE="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

installed_version() {
  if [ -x "$SDK_DIR/bin/flutter" ] && [ -f "$SDK_DIR/.complete" ]; then
    git -C "$SDK_DIR" describe --tags --exact-match 2>/dev/null || true
  fi
}

git config --global --get-all safe.directory | grep -qx "$SDK_DIR" ||
  git config --global --add safe.directory "$SDK_DIR"

if [ "$(installed_version)" != "$FLUTTER_VERSION" ]; then
  mkdir -p "$(dirname "$SDK_DIR")"
  staging="$(mktemp -d "$(dirname "$SDK_DIR")/.flutter-XXXXXX")"
  curl -fsSL "$ARCHIVE" | tar -xJ -C "$staging"
  touch "$staging/flutter/.complete"
  rm -rf "$SDK_DIR"
  mv "$staging/flutter" "$SDK_DIR"
  rm -rf "$staging"
fi

ln -sf "$SDK_DIR/bin/flutter" /usr/local/bin/flutter 2>/dev/null || true
ln -sf "$SDK_DIR/bin/dart" /usr/local/bin/dart 2>/dev/null || true
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$SDK_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

export PATH="$SDK_DIR/bin:$PATH"
flutter --disable-analytics >/dev/null 2>&1 || true
flutter --version
cd "${CLAUDE_PROJECT_DIR:-.}"
flutter pub get
