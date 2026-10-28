---
name: mac-app-ui
description: Use when building, restyling or reviewing a Mac app's UI (Tauri, Electron, WKWebView, SwiftUI, AppKit), including windows, title bar and traffic lights, sidebars, lists, type sizes, colours or colors, dark mode, accent color, menus, tray, status item or menu-bar extra, Settings window, About panel, app icons or the Human Interface Guidelines (HIG); also when a Mac app feels non-native, looks like a web page or a terminal, or has text that is too small.
---

# Mac app UI

## Step 1: platforms and shape

1. If CLAUDE.md has a `## Mac app UI` section, use it and go to Step 2.
2. Read Tauri config, `LSUIElement`, `ActivationPolicy`, tray code, `Package.swift`, LICENSE (copyright holder), README (tagline).
3. Ask only what the repo leaves open:
   - Platforms: macOS only (default), or also Linux and Windows?
   - Shape: windowed, menu-bar-only, or windowed with a status item? Recommend windowed, no status item, unless the app shows glanceable status.
4. Record in CLAUDE.md, one value each:

```markdown
## Mac app UI
- Platforms: macOS only|macOS, Linux, Windows
- Shape: windowed|menu-bar-only|windowed + status item
```

## Step 2: apply the standard

**Type.** System font, macOS text styles (1px = 1pt):

| Role | Size / line | Weight |
|---|---|---|
| Window or detail header | 22/26 Title 1 | 700 |
| Pane title | 17/22 Title 2 | 700 |
| Reading text, detail-pane section headers | 15/20 Title 3 | 400 |
| Row titles, controls, labels, sidebar items | 13/16 Body | 400 (row titles 600 when emphasised) |
| List group headers | 13/16 Headline | 700 |
| Metadata | 12/15 Callout | 400, secondary label |
| Sidebar section headers, badges | 11/14 Subheadline | 600 |

Terminal-like apps lack hierarchy, not size: four or more sizes per screen, nothing below 11px, Title Case headers without tracking, monospace only for code, tabular figures. Two-line rows about 44px; single-line rows 24–28px. ⌘+/⌘− zoom serves users who want larger text.

**Colour.** Semantic system colours as light/dark tokens. The user's accent drives selection, sidebar icons and primary buttons; an app accent shows only under Multicolor. Selected rows: selected-content background and white text while the list has focus; unemphasized background and label colour otherwise. Contrast: 4.5:1 for text under 18pt, 3:1 at 18pt+ or bold (HIG); 3:1 for icons and control borders (WCAG 1.4.11). `grep -rnE '#[0-9a-fA-F]{3,8}\b' src/` hits only the token block.

**Wiring contract.** List each menu, context-menu and status item with its handler and emitted event. List each permission with where it's declared: Tauri capability, Electron entitlement, Info.plist usage string.

References: `references/webview.md` (Tauri, Electron), `references/swiftui.md`, `references/menus-settings-about.md` (menus, menu-bar extra, Settings, About, app icon, alerts, wording), `references/hig-macos.md` (sourced HIG facts).

## Step 3: verify before handing over

The app goes to the user for testing only with a complete conformance table that has no "Doesn't" rows.

You run (from the skill's base directory; needs Xcode command line tools):
1. Build, launch, then `swift <skill-dir>/scripts/webkit-snapshot.swift <url> <w> <h> <out.png> <light|dark> "<js>"` per screen at the minimum window size, both themes; read the PNGs. Pass: builds, nothing clipped, legible.
2. Pass `[...new Set([...document.querySelectorAll('body *')].map(e => getComputedStyle(e).fontSize))].join()` as `<js>`; it prints. Pass: four+ sizes, none under 11px.
3. Hex grep. Pass: token block only.
4. Check config keys and APIs in installed source or docs. Pass: each cited or reported unverified.
5. Conformance table. Rows: every surface (window chrome, toolbar, sidebar, lists, detail panes, sheets and dialogs, alerts and errors, Settings, About, menus, context menus, status item) and every control type on them (push, default, pop-up, field, search, checkbox, radio, segmented, switch). Render native controls with `swift <skill-dir>/scripts/appkit-reference.swift <out-dir>` and compare each control's snapshot in the same appearance: shape, fill, border, height, corner radius, font. Capture a native key window with `sh <skill-dir>/scripts/native-window.sh <out-dir>` and compare window chrome, sidebar and toolbar against it; build to the capture when it differs from HIG wording. Columns: element, Follows / Partly / Doesn't, evidence (file:line or PNG), source (`hig-macos.md` section or HIG URL). Fix every Doesn't, re-snapshot, and put the table in the handoff.

The user confirms:
- VoiceOver (⌘F5) announces every control in the main flow.
- Accent and appearance switches update the running app.
- Full Keyboard Access: Tab reaches every control; arrows move through lists.
- Every wiring-contract entry fires.

## Common mistakes

| Mistake | Fix |
|---|---|
| Flat scale: one or two sizes for everything | The role scale. |
| `AccentColor` keyword as the user's accent | Native accent read (`references/webview.md`). |
| All-caps tracked headers, monospace numbers | Title Case; tabular figures. |
| Custom title bar without a sidebar | Standard title bar. |
| Settings drawer with Save | Settings window, immediate changes. |
| Items emitting unhandled events | Wiring contract. |
| Permission used, not declared | Declare it. |
| "Dynamic Type" on macOS | Fixed styles plus zoom. |
| Global `user-select: none` | Chrome only. |
| Config claims from memory | Check installed source. |
| Handing over with controls never compared to AppKit | Conformance table first. |
