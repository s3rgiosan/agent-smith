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

A screen that reads like a terminal lacks hierarchy, not size. Fix it with four or more sizes per screen from the table, nothing below 11px, Title Case headers at default tracking, monospace only for code, and tabular figures. Zoom (`references/menus-settings-about.md` → Zoom) serves users who want larger text.

**Windows.** Each main window's minimum size comes from the app config: Tauri `minWidth`/`minHeight`, SwiftUI `.frame(minWidth:minHeight:)`.

**Colour.** Semantic system colours as light/dark tokens. The user's accent drives selection, sidebar icons and primary buttons; an app accent shows only under Multicolor. Selected rows: selected-content background and white text while the list has focus; unemphasized background and label colour otherwise. Contrast: 4.5:1 for text under 18pt, 3:1 at 18pt+ or bold (HIG); 3:1 for icons and control borders (WCAG 1.4.11). `grep -rnE '#[0-9a-fA-F]{3,8}\b' src/` hits only the token block.

**Wiring contract.** A repo file (for example `docs/wiring.md`) lists each menu, context-menu and status item with its handler and emitted event, and each permission with where it's declared (Tauri capability, Electron entitlement, Info.plist usage string). It goes to the user with the handoff.

References: `references/webview.md` (Tauri, Electron, preview harness), `references/swiftui.md`, `references/menus-settings-about.md` (menus, zoom, shortcuts, Settings, About, alerts, empty states, wording), `references/hig-macos.md` (sourced HIG facts).

## Step 3: verify before handing over

Scripts need Xcode command line tools; point every output path at a scratch directory. In order:

1. **Inventory.** The surfaces present (window chrome, toolbar, sidebar, lists, detail panes, sheets and dialogs, alerts and errors, empty states, Settings, About, menus, context menus, status item) and the control types on them (push, default, pop-up, pull-down, field, search, checkbox, radio, segmented, switch).
2. **Snapshot plan.** Every surface opens from a preview URL. Webview apps get a dev-only preview harness: mocked IPC, loaded only in dev outside the native shell, and a URL control per surface (`references/webview.md` → Preview harness); clicks in the snapshot JS run once after load and miss asynchronous state. Native-only surfaces (menus, context menus, pull-down menus, alerts, About, traffic lights, window config) get a verdict from code with file:line evidence, which counts as checked, and are listed for the user to confirm.
3. **Native references.** `swift <skill-dir>/scripts/appkit-reference.swift <out-dir>` writes `ak-<light|dark>-<control>.png`; controls draw in the inactive-window state, without accent fills. `sh <skill-dir>/scripts/native-window.sh <out-dir>` writes `native-window-light.png` and `native-window-dark.png`, a key window with sidebar and toolbar; on failure it writes `native-window-<mode>-cached.png`, which lacks materials and active-state colours.
4. **Compare.** Build, launch, and snapshot each surface from the dev server URL (Tauri `build.devUrl`) at the minimum window size in both themes: `swift <skill-dir>/scripts/webkit-snapshot.swift <url> <w> <h> <out.png> <light|dark> "<js>"`; read every PNG. Pass: builds; legible (no clipped or overlapping text, truncation only with an ellipsis, contrast per Colour). Per screen, `<js>` = `[...new Set([...document.querySelectorAll('body *')].map(e => getComputedStyle(e).fontSize))].join()` prints its sizes. Pass: none under 11px; main-window screens use four or more. Hex grep: token block only. Config keys and APIs: cited from installed source or docs, or reported unverified. Compare each control with its AppKit snapshot in the same appearance (shape, fill, border, height, corner radius, font), and chrome, sidebar and toolbar with the native capture; build to the capture where it differs from HIG wording.
5. **Table.** Rows: every surface and control type from the inventory. Columns: element, verdict (Follows / Partly / Doesn't / Not checked), evidence (file:line or PNG), source (`hig-macos.md` section or HIG URL). A Partly row states the measured difference: app value vs native value.

Fix every Doesn't and re-snapshot. Hand over only when the table has no Doesn't and no Not checked rows; each Partly row is fixed or listed in the handoff as an open decision for the user. A delegated review gets a time budget (30 minutes unless the user sets one) and marks unreached rows Not checked.

The user confirms:
- VoiceOver (⌘F5) announces every control in the main flow.
- Accent and appearance switches update the running app.
- Full Keyboard Access: Tab reaches every control; arrows move through lists.
- Every wiring-contract entry fires.
- The native-only surfaces listed in the table.

## Common mistakes

| Mistake | Fix |
|---|---|
| `AccentColor` keyword as the user's accent | Native accent read (`references/webview.md`). |
| Custom title bar without a sidebar | Standard title bar. |
| Settings drawer with Save | Settings window, immediate changes. |
| "Dynamic Type" on macOS | Fixed styles plus zoom. |
