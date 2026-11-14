#!/bin/bash
# Builds "TB Drum Machine.app" (stand-alone, 64-bit Intel) for Mac OS X 10.8.5 and
# later, then verifies the binary really declares 10.8.5 as its minimum and only
# links libraries that exist on 10.8.5. Run on macOS (GitHub's Intel runner or any
# Mac with Xcode command line tools):
#
#   scripts/build_app_mac.sh   -> "build/TB Drum Machine.app", build/TB-Drum-Machine-mountain-lion-app.zip

set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build
NAME="TB Drum Machine"
EXE=TBDrumMachine
ZIP=TB-Drum-Machine-mountain-lion-app.zip
BUNDLE="$OUT/$NAME.app"
MIN_OS=10.8.5

rm -rf "$BUNDLE" "$OUT/$ZIP"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
printf 'APPLTBdm' > "$BUNDLE/Contents/PkgInfo"
if [ -f "$OUT/TBDrumMachine.icns" ]; then cp "$OUT/TBDrumMachine.icns" "$BUNDLE/Contents/Resources/"; fi

echo "== Toolchain"
xcrun clang++ --version | head -1
echo "SDK $(xcrun --show-sdk-version) at $(xcrun --show-sdk-path)"

echo "== Compiling (x86_64, minimum Mac OS X $MIN_OS)"
xcrun clang++ -arch x86_64 -mmacosx-version-min=$MIN_OS \
    -std=c++98 -stdlib=libc++ -O2 -Wall -Wextra -Wno-deprecated-declarations \
    -fno-objc-arc -Werror=unguarded-availability -Werror=unguarded-availability-new \
    -framework Cocoa -framework AudioUnit -framework AudioToolbox -framework CoreAudio -framework CoreMIDI \
    Source/Engine/Engine.cpp Source/Engine/Wav.cpp Source/Engine/Export.cpp \
    Source/App/MainView.mm Source/App/main.mm \
    -o "$BUNDLE/Contents/MacOS/$EXE"

BIN="$BUNDLE/Contents/MacOS/$EXE"

echo "== Verifying"
lipo -info "$BIN"
file "$BIN"

LOADCMDS=$(otool -l "$BIN")
MINOS=$(echo "$LOADCMDS" | awk '/LC_VERSION_MIN_MACOSX/{f=1} f&&/version/{print $2; exit}')
if [ -z "$MINOS" ]; then
    MINOS=$(echo "$LOADCMDS" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')
fi
echo "Declared minimum OS: ${MINOS:-unknown}"
if [ "$MINOS" != "$MIN_OS" ]; then
    echo "::error::Binary declares minimum OS '${MINOS:-unknown}', expected $MIN_OS"
    exit 1
fi
echo "::notice::$NAME.app declares minimum Mac OS X $MINOS"

# Only system libraries and frameworks that ship with 10.8.5 are allowed
# (-Werror=unguarded-availability above rejects any API newer than 10.8.5)
echo "Linked libraries:"
otool -L "$BIN" | tail -n +2
BAD=$(otool -L "$BIN" | tail -n +2 | awk '{print $1}' \
      | grep -v -E '^/usr/lib/(libc\+\+\.1|libSystem\.B|libobjc\.A)\.dylib$' \
      | grep -v -E '^/System/Library/Frameworks/(Cocoa|AppKit|Foundation|CoreFoundation|CoreGraphics|ApplicationServices|CoreServices|QuartzCore|CoreText|AudioUnit|AudioToolbox|CoreAudio|CoreMIDI)\.framework/' \
      || true)
if [ -n "$BAD" ]; then
    echo "::error::Unexpected library dependency: $BAD"
    exit 1
fi

echo "Imported symbols:"
nm -u "$BIN" | head -400

echo "== Packaging"
(cd "$OUT" && ditto -c -k --keepParent "$NAME.app" "$ZIP")
ls -la "$OUT"
echo "Built $BUNDLE"
