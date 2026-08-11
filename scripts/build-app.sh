#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP="$DIST_DIR/Miore.app"
ICON_SOURCE="$DIST_DIR/AppIcon-1024.png"
ICONSET="$DIST_DIR/AppIcon.iconset"

# SwiftPM may leave deleted resources in an incremental bundle; clear only Miore's
# generated resource bundles so removed assets cannot leak into a release.
rm -rf \
  "$PROJECT_DIR/.build/x86_64-apple-macosx/release/Miore_Miore.bundle" \
  "$PROJECT_DIR/.build/arm64-apple-macosx/release/Miore_Miore.bundle"

swift build --package-path "$PROJECT_DIR" -c release --triple x86_64-apple-macosx12.0
swift build --package-path "$PROJECT_DIR" -c release --triple arm64-apple-macosx12.0
X86_BINARY="$PROJECT_DIR/.build/x86_64-apple-macosx/release/Miore"
ARM_BINARY="$PROJECT_DIR/.build/arm64-apple-macosx/release/Miore"

rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
lipo -create "$X86_BINARY" "$ARM_BINARY" -output "$APP/Contents/MacOS/Miore"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
# SwiftPM's generated Bundle.module accessor expects this bundle beside the executable.
cp -R "$PROJECT_DIR/.build/arm64-apple-macosx/release/Miore_Miore.bundle" "$APP/Contents/Resources/Miore_Miore.bundle"

swift "$PROJECT_DIR/scripts/Icon.swift" "$ICON_SOURCE"
for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" "512 icon_256x256@2x" "512 icon_512x512" "1024 icon_512x512@2x"; do
  parts=(${=spec})
  sips -z "${parts[1]}" "${parts[1]}" "$ICON_SOURCE" --out "$ICONSET/${parts[2]}.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"

echo "$APP"
