#!/bin/bash
# Package Developer ID signed Zhichu and generate its signed Sparkle feed.
# Default: notarize and staple using NOTARY_PROFILE. Explicit preview: NOTARIZE=0.
#   NOTARY_PROFILE=Zhichu scripts/release.sh
#   NOTARIZE=0 scripts/release.sh
# Private EdDSA key stays in Keychain account app.zhichu.mac.updates.
# Upload versioned archives + SHA256SUMS.txt to GitHub Releases FIRST, then publish
# updates/macos/appcast.xml on main. Never publish a feed that points at a draft.
set -euo pipefail
cd "$(dirname "$0")/.."
SIGN_ID="${SIGN_ID:-$( [[ -f .sign-id ]] && head -1 .sign-id || true )}"
: "${SIGN_ID:?set SIGN_ID to your Developer ID Application identity}"
[[ "$SIGN_ID" == 'Developer ID Application:'* ]] || { echo 'A Developer ID Application identity is required' >&2; exit 1; }
NOTARIZE="${NOTARIZE:-1}"
[[ "$NOTARIZE" == 0 || "$NOTARIZE" == 1 ]] || { echo 'NOTARIZE must be 0 or 1' >&2; exit 1; }
if [[ "$NOTARIZE" == 1 ]]; then
  : "${NOTARY_PROFILE:?set NOTARY_PROFILE; or explicitly use NOTARIZE=0 for an unnotarized preview}"
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' Resources/Info.plist)
APP=build.noindex/release-build/知处.app
OUT="build.noindex/release/$VERSION"
ACCOUNT="${SPARKLE_ACCOUNT:-app.zhichu.mac.updates}"
export SIGN_ID
mkdir -p "$OUT" work
APP_OUTPUT="$APP" RELEASE=1 ./build.sh
codesign --verify --strict --deep "$APP"
ZIP="$OUT/Zhichu-$VERSION-macos-arm64.zip"
DMG="$OUT/Zhichu-$VERSION-macos-arm64.dmg"
if [[ "$NOTARIZE" == 1 ]]; then
  ditto -c -k --keepParent "$APP" "$OUT/notary-submission.zip"
  xcrun notarytool submit "$OUT/notary-submission.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm "$OUT/notary-submission.zip"
fi
ditto -c -k --keepParent "$APP" "$ZIP"
STAGE=$(mktemp -d "$PWD/work/zhichu-dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/知处.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname 知处 -srcfolder "$STAGE" -fs HFS+ -format ULFO -ov "$DMG"
codesign --force --sign "$SIGN_ID" --timestamp "$DMG"
if [[ "$NOTARIZE" == 1 ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type execute --verbose=2 "$APP"
fi
codesign --verify --strict "$DMG"
hdiutil verify "$DMG" > "$OUT/dmg-verify.log"
ARGS=("$ZIP" "${APPCAST:-updates/macos/appcast.xml}" --app "$APP" --account "$ACCOUNT")
[[ -z "${NOTES:-}" ]] || ARGS+=(--notes "$NOTES")
python3 scripts/appcast.py "${ARGS[@]}"
(cd "$OUT" && shasum -a 256 "Zhichu-$VERSION-macos-arm64.dmg" "Zhichu-$VERSION-macos-arm64.zip" > SHA256SUMS.txt)
python3 - "$OUT" "$VERSION" "$BUILD" "$NOTARIZE" <<'PY'
import json, pathlib, sys
out, version, build, notarized = sys.argv[1:]
pathlib.Path(out, 'release-info.json').write_text(json.dumps({
    'version': version, 'build': build, 'notarized': notarized == '1',
    'feed': 'https://raw.githubusercontent.com/jiliangC/Zhichu/main/updates/macos/appcast.xml',
}, indent=2)+'\n')
PY
echo "Packaged $VERSION ($BUILD) in $OUT. Notarized: $NOTARIZE."
echo 'Publish archives to Releases, verify downloads, then commit and push the appcast.'
