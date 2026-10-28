# mac-app-ui

Part of [Agent Smith](../../../README.md): tools, scripts and skills for agent-driven development.

A Claude Code skill that holds a Mac app's UI to Apple's Human Interface Guidelines for macOS. It covers Tauri and Electron webview apps and SwiftUI and AppKit apps: type, colour, windows, menus, the menu-bar extra, Settings, About and alerts. Before the app goes to you for testing, it checks every surface against native renders and records the results in a conformance table.

---

## Installation

```bash
git clone https://github.com/s3rgiosan/agent-smith.git
cd agent-smith/claude/scripts

# Default → ~/.claude (or $CLAUDE_CONFIG_DIR)
./install_claude_skills.sh mac-app-ui

# Another Claude home
./install_claude_skills.sh mac-app-ui --claude ~/.claude-work
```

Uninstall:

```bash
./install_claude_skills.sh mac-app-ui --uninstall
```

Start a new session after installing so Claude Code picks up the skill. See the [Claude scripts README](../../scripts/README.md#install_claude_skillssh) for every installer flag.

The verification scripts need macOS with the Xcode command line tools. `native-window.sh` also needs Screen Recording permission for the terminal.

---

## Usage

Open a Claude Code session in the app's repo and ask naturally:

```
"Restyle the settings window so it feels native."
"Review this Tauri app's UI against the macOS HIG."
"The text in the sidebar is too small and it looks like a web page."
"Add a menu-bar extra with a status item."
```

The skill works in three steps:

1. **Platforms and shape.** Reads the repo for the target platforms and the app's shape (windowed, menu-bar-only, or windowed with a status item), asks only what the repo leaves open, and records both in the project's CLAUDE.md under `## Mac app UI`.
2. **Apply the standard.** The macOS type scale in the system font, semantic system colours as light and dark tokens, the user's accent for selection and primary buttons, minimum window sizes from the app config, and a wiring contract that lists each menu item and permission with its handler or declaration.
3. **Verify before handing over.** Inventories every surface and control type, snapshots each one in WKWebView in light and dark at the minimum window size, and compares controls and window chrome with real AppKit renders and a captured native window. The results go in a conformance table, and the app is handed over only when no row is Doesn't or Not checked. You then confirm VoiceOver, accent and appearance switches, Full Keyboard Access, the wiring contract and the native-only surfaces.

### Scripts

```bash
# Real AppKit controls in light and dark → <out-dir>/ak-<light|dark>-<control>.png
swift scripts/appkit-reference.swift <out-dir>

# A native window with sidebar and toolbar → <out-dir>/native-window-<light|dark>.png
sh scripts/native-window.sh <out-dir>

# A page rendered in WKWebView; the optional script runs after load and prints its result
swift scripts/webkit-snapshot.swift <url> <width> <height> <out.png> <light|dark> [script]
```

The scripts render offscreen or capture only the window they create.

---

## What's Inside

```
mac-app-ui/
├── README.md                       ← you are here
├── SKILL.md                        ← platforms and shape, the standard, verification gate
├── references/
│   ├── hig-macos.md                ← sourced macOS HIG facts
│   ├── menus-settings-about.md     ← menus, zoom, shortcuts, Settings, About, alerts, empty states, wording
│   ├── swiftui.md                  ← SwiftUI and AppKit apps
│   └── webview.md                  ← Tauri and Electron webview apps, preview harness
└── scripts/
    ├── appkit-reference.swift      ← real AppKit controls rendered in light and dark
    ├── native-window.sh            ← builds and captures a native reference window in light and dark
    ├── native-window.swift         ← the reference window native-window.sh captures
    └── webkit-snapshot.swift       ← renders a page in WKWebView and saves a PNG
```

---

## License

[MIT](../../../LICENSE)
