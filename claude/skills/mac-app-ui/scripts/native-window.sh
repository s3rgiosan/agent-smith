#!/bin/sh
# Captures a native macOS window (sidebar + unified toolbar) as the key window, in light and dark.
# Usage: sh native-window.sh <out-dir>   Writes native-window-light.png and native-window-dark.png.
# Needs Xcode command line tools and Screen Recording permission for the terminal.
set -eu

OUT="$(cd "${1:-.}" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
APP="$WORK/NativeReference.app"

mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NativeReference</string>
<key>CFBundleIdentifier</key><string>local.mac-app-ui.native-reference</string>
<key>CFBundleName</key><string>NativeReference</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
swiftc -O "$HERE/native-window.swift" -o "$APP/Contents/MacOS/NativeReference"

cat > "$WORK/window-id.swift" <<'SWIFT'
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
if let w = list.first(where: { ($0[kCGWindowOwnerName as String] as? String) == "NativeReference" && ($0[kCGWindowLayer as String] as? Int) == 0 }) {
    print(w[kCGWindowNumber as String]!)
}
SWIFT

for mode in light dark; do
    open -n "$APP" --args "$mode"
    sleep 3
    id=""
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        id="$(swift "$WORK/window-id.swift")"
        [ -n "$id" ] && break
        sleep 1
    done
    [ -n "$id" ] || { echo "NativeReference window not found" >&2; exit 1; }
    screencapture -x -l "$id" "$OUT/native-window-$mode.png"
    sleep 10
done
rm -rf "$WORK"
echo "Wrote $OUT/native-window-light.png and $OUT/native-window-dark.png"
