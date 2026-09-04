#!/bin/bash
#
# Builds a distributable .dmg from an already-built release app.
#
# Deliberately plain `hdiutil`, with no dependency on create-dmg and no
# background image: the fewer moving parts between a green test run and a file
# someone can double-click, the more often this actually gets run.
#
#   flutter build macos --release
#   tool/make_dmg.sh
#
# Note on signing: this signs ad-hoc unless the project is configured with a
# "Developer ID Application" certificate. An ad-hoc DMG installs and runs, but
# Gatekeeper will call it an unidentified developer and the first launch needs
# a right-click → Open. For a link people can hand to strangers you need a
# Developer ID certificate plus `xcrun notarytool submit`, which is a paid
# Apple Developer account and a step this script deliberately does not fake.
set -euo pipefail

APP="${1:-build/macos/Build/Products/Release/SSHetu.app}"

if [ ! -d "$APP" ]; then
  echo "no app at $APP — run: flutter build macos --release" >&2
  exit 1
fi

NAME="$(basename "$APP" .app)"
PLIST="$APP/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
OUT="build/macos/${NAME}-${VERSION}+${BUILD}.dmg"

# Staged in a temp directory so the image contains exactly two things: the app,
# and the shortcut people expect to drag it onto.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$OUT"
hdiutil create \
  -volname "$NAME $VERSION" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$OUT" >/dev/null

# Says what it made, and what it did not: an ad-hoc signature is worth knowing
# about before the file is sent to anyone.
echo "$OUT"
codesign -dv "$APP" 2>&1 | grep -q 'Signature=adhoc' &&
  echo "note: ad-hoc signed — Gatekeeper will warn on first launch" >&2
exit 0
