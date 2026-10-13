#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD="$PWD/dist/mac-native-build"
DELIVERY="$PWD/dist/暗淡蓝点-Mac-轻量版-1.2.6"
APP="$DELIVERY/暗淡蓝点轻量版.app"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"
clang++ -std=c++17 -Wall -Wextra -Werror native-win/tests/logic_test.cpp -o "$BUILD/logic-test"
"$BUILD/logic-test"
for ARCH in arm64 x86_64; do
  xcrun clang++ -arch "$ARCH" -std=c++17 -fobjc-arc -Os -Wall -Wextra -Wno-unused-parameter \
    -mmacosx-version-min=12.0 native-mac/App.mm -framework AppKit -framework Foundation \
    -Wl,-dead_strip -o "$BUILD/DimBlueDotMac-$ARCH"
done
xcrun lipo -create "$BUILD/DimBlueDotMac-arm64" "$BUILD/DimBlueDotMac-x86_64" -output "$APP/Contents/MacOS/DimBlueDotMac"
xcrun strip -x "$APP/Contents/MacOS/DimBlueDotMac"
cp native-mac/Info.plist "$APP/Contents/Info.plist"
cp build/icon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"

TESTAPP="$BUILD/MacSmokeTests.app"
mkdir -p "$TESTAPP/Contents/MacOS" "$TESTAPP/Contents/Resources"
xcrun clang++ -std=c++17 -fobjc-arc -Os -Wall -Wextra -Wno-unused-parameter \
  -mmacosx-version-min=12.0 native-mac/Tests/AppTests.mm -framework AppKit -framework Foundation \
  -o "$TESTAPP/Contents/MacOS/MacSmokeTests"
cp native-mac/Info.plist "$TESTAPP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable MacSmokeTests' "$TESTAPP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.xuwu.dimblue.mac.smoketests' "$TESTAPP/Contents/Info.plist"
cp build/icon.icns "$TESTAPP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$TESTAPP"
VERIFY="$BUILD/verification-$(date +%s)"
mkdir -p "$VERIFY"
open -n -W --stdout "$VERIFY/stdout.log" --stderr "$VERIFY/stderr.log" "$TESTAPP" --args "$VERIFY"
if ! test -f "$VERIFY/ui-test-report.json"; then
  cat "$VERIFY/stdout.log" "$VERIFY/stderr.log"
  exit 1
fi
node native-mac/check-bundle.cjs "$APP" "$VERIFY"

STAGE="$(mktemp -d "$BUILD/dmg-stage.XXXXXX")"
PKGWORK="$(mktemp -d "$BUILD/pkg-stage.XXXXXX")"
MOUNT=""
cleanup() {
  if [ -n "$MOUNT" ]; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
    rmdir "$MOUNT" 2>/dev/null || true
  fi
  rm -rf "$STAGE"
  rm -rf "$PKGWORK"
}
trap cleanup EXIT
ditto "$APP" "$STAGE/暗淡蓝点轻量版.app"
ln -sfn /Applications "$STAGE/Applications"
cp native-mac/使用说明.txt "$STAGE/使用说明.txt"
DMG="$DELIVERY/暗淡蓝点-1.2.6-Mac-通用轻量版.dmg"
hdiutil create -ov -volname "暗淡蓝点轻量版" -srcfolder "$STAGE" -format UDZO -imagekey zlib-level=9 "$DMG"
hdiutil verify "$DMG"
cp native-mac/使用说明.txt "$DELIVERY/使用说明.txt"
MOUNT="$(mktemp -d "$BUILD/dmg-mount.XXXXXX")"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$DMG"
codesign --verify --deep --strict "$MOUNT/暗淡蓝点轻量版.app"
node native-mac/check-bundle.cjs "$APP" "$VERIFY" "$DMG" "$MOUNT/暗淡蓝点轻量版.app"

mkdir -p "$PKGWORK/root"
ditto "$APP" "$PKGWORK/root/暗淡蓝点轻量版.app"
pkgbuild --analyze --root "$PKGWORK/root" "$PKGWORK/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$PKGWORK/components.plist"
PKG="$DELIVERY/暗淡蓝点-1.2.6-Mac-安装包.pkg"
pkgbuild --root "$PKGWORK/root" --component-plist "$PKGWORK/components.plist" \
  --identifier com.xuwu.dimblue.mac.native.pkg --version 1.2.6 \
  --install-location /Applications --ownership recommended --compression latest \
  --min-os-version 12.0 "$PKG"
pkgutil --expand-full "$PKG" "$PKGWORK/expanded"
codesign --verify --deep --strict "$PKGWORK/expanded/Payload/暗淡蓝点轻量版.app"
node native-mac/check-bundle.cjs "$APP" "$VERIFY" "$DMG" "$MOUNT/暗淡蓝点轻量版.app" "$PKG" "$PKGWORK/expanded"
