#!/bin/sh
# Captures a native macOS reference window (source-list sidebar, unified toolbar with standard items,
# content pane) as the key window, in light and dark. Captures only the window this script creates.
#
# Usage: sh native-window.sh <out-dir>
# Writes <out-dir>/native-window-light.png and <out-dir>/native-window-dark.png. When screencapture
# can't capture the window, writes <out-dir>/native-window-<mode>-cached.png instead.
# Needs Xcode command line tools and Screen Recording permission for the terminal.
set -eu

mkdir -p "${1:-.}"
OUT="$(cd "${1:-.}" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
APP="$WORK/NativeReference.app"
BIN="$APP/Contents/MacOS/NativeReference"

stop_app() {
    pkill -f "$BIN" 2>/dev/null || true
}
cleanup() {
    stop_app
    rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

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
swiftc -O "$HERE/native-window.swift" -o "$BIN" 2>"$WORK/swiftc.log" || { cat "$WORK/swiftc.log" >&2; exit 1; }

# Prints the RGB of one pixel: <png> <x-px> <y-px-from-top>.
cat > "$WORK/pixel.swift" <<'SWIFT'
import AppKit
let a = CommandLine.arguments
let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: a[1])))!
let c = rep.colorAt(x: Int(a[2])!, y: Int(a[3])!)!.usingColorSpace(.sRGB)!
print(Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255), rep.pixelsWide)
SWIFT

status=0
for mode in light dark; do
    file="$OUT/native-window-$mode.png"
    rm -f "$file" "$OUT/native-window-$mode-cached.png"
    open -n "$APP" --args "$mode" "$WORK"

    ready="$WORK/ready-$mode"
    i=0
    while [ ! -s "$ready" ] && [ "$i" -lt 60 ]; do
        sleep 0.5
        i=$((i + 1))
    done
    [ -s "$ready" ] || { echo "NativeReference window not ready after 30 s" >&2; exit 1; }
    read -r id width close_x close_y is_key < "$ready"

    captured=0
    red=0
    attempt=0
    while [ "$red" -eq 0 ] && [ "$attempt" -lt 3 ]; do
        attempt=$((attempt + 1))
        screencapture -x -o -l "$id" "$file" 2>"$WORK/screencapture.log" && [ -s "$file" ] || break
        captured=1
        # A key window's close button is red: red exceeds green and blue by more than 50.
        set -- $(swift "$WORK/pixel.swift" "$file" 0 0)
        x=$(awk -v px="$4" -v w="$width" -v v="$close_x" 'BEGIN { printf "%d", px / w * v }')
        y=$(awk -v px="$4" -v w="$width" -v v="$close_y" 'BEGIN { printf "%d", px / w * v }')
        set -- $(swift "$WORK/pixel.swift" "$file" "$x" "$y")
        rgb="$1 $2 $3"
        if [ $(($1 - $2)) -gt 50 ] && [ $(($1 - $3)) -gt 50 ]; then red=1; else sleep 1; fi
    done
    if [ "$captured" -eq 1 ] && [ "$red" -eq 1 ]; then
        echo "Wrote $file (key window: close button rgb $rgb)"
    elif [ "$captured" -eq 1 ]; then
        echo "WARNING: $file close button is rgb $rgb, not red, after 3 captures: the window wasn't key (app reported key=$is_key at launch). Re-run with nothing else taking focus." >&2
        status=2
    else
        cp "$WORK/native-window-$mode-cached.png" "$OUT/"
        echo "screencapture failed: $(cat "$WORK/screencapture.log")" >&2
        echo "Wrote $OUT/native-window-$mode-cached.png: a cacheDisplay render. It omits materials (the sidebar and the rows on it) and active-state colours, so compare toolbar and content layout, sizes and spacing only; don't compare fills, the sidebar or traffic-light colours." >&2
        status=2
    fi
    stop_app
    sleep 1
done
exit "$status"
