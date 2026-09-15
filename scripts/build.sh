#!/bin/zsh
set -euo pipefail
CUE_SOURCE="${0:A:h:h}"
CUE_RELEASE="$CUE_SOURCE/../Releases/0.4.0 Alpha"
CUE_BUNDLE="$CUE_RELEASE/Cue.app"
cd "$CUE_SOURCE"
swift build -c release
swift scripts/make-icon.swift Resources/Cue.iconset
iconutil -c icns Resources/Cue.iconset -o Resources/Cue.icns
mkdir -p "$CUE_BUNDLE/Contents/MacOS" "$CUE_BUNDLE/Contents/Resources"
cp .build/release/Cue "$CUE_BUNDLE/Contents/MacOS/Cue"
cp Info.plist "$CUE_BUNDLE/Contents/Info.plist"
cp Resources/Cue.icns "$CUE_BUNDLE/Contents/Resources/Cue.icns"
codesign --force --sign - "$CUE_BUNDLE"
codesign --verify --deep --strict "$CUE_BUNDLE"
ditto -c -k --sequesterRsrc --keepParent "$CUE_BUNDLE" "$CUE_RELEASE/Cue-0.4.0-alpha-mac.zip"
print "Built $CUE_BUNDLE"
