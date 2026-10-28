# Webview apps (Tauri 2, Electron)

A webview renders 1 CSS px as 1 pt at 100% zoom, so the type scale in `SKILL.md` applies in px. Menus, Settings, About, alerts and the menu-bar extra are in `menus-settings-about.md`.

## Type

- `font-family: system-ui, -apple-system, sans-serif;` with no font files.
- Weights follow the `SKILL.md` table: Title 1 and Title 2 700 (emphasised), Title 3 400, Body 400 with emphasised row titles 600, Headline 700 (its default), Callout 400, Subheadline 600 (emphasised). Defaults and emphasised weights: `hig-macos.md` → Typography.
- Numbers in columns: `font-variant-numeric: tabular-nums;`. `ui-monospace` for code, paths and command output.
- Zoom: the View menu owns it (`menus-settings-about.md` → Zoom).

## Sizes

- Controls: 24px tall at regular size, 28px at large, as AppKit push buttons, text fields and pop-up buttons. Pad each clickable target to at least 28×28px (`hig-macos.md` → Accessibility).
- Rows: single-line 24–28px (an AppKit table row is 24pt); a 13px title over 12px metadata about 44px.
- Starting layout (house defaults): toolbar 52px, sidebar 220px, content list 320px, detail flexible with a reading column of about 640px.
- Minimum window size: Electron sets it with `BrowserWindow` `minWidth`/`minHeight` (Tauri and SwiftUI: `SKILL.md` → Step 2).
- Window state: restore size and position (Tauri `tauri-plugin-window-state`; Electron `win.getBounds()` saved in the settings store), plus sidebar width and the selection.

## Colour

Tokens on `:root`, dark values under `@media (prefers-color-scheme: dark)`, and `color-scheme: light dark`. Every literal colour lives in this block.

**Tauri (WKWebView).** WebKit's semantic colours go inside `@supports (color: -apple-system-label) { … }`, literal fallbacks outside it:

| Token | WebKit colour | Fallback light | Fallback dark |
|---|---|---|---|
| Window and content background | `-apple-system-background` | `#ffffff` | `#1e1e1e` |
| Label | `-apple-system-label` | `rgb(0 0 0 / 0.847)` | `rgb(255 255 255 / 0.847)` |
| Secondary label | `-apple-system-secondary-label` | `rgb(0 0 0 / 0.498)` | `rgb(255 255 255 / 0.549)` |
| Separator | `-apple-system-separator` | `rgb(0 0 0 / 0.098)` | `rgb(255 255 255 / 0.098)` |
| Selection, list focused | `-apple-system-selected-content-background` | `#0064e1` | `#0059d1` |
| Selection, list unfocused | `-apple-system-unemphasized-selected-content-background` | `#dcdcdc` | `#464646` |
| Accent (Multicolor) | `-apple-system-control-accent` | `#007aff` | `#007aff` |
| Status red | `-apple-system-red` | `#ff383c` | `#ff4245` |
| Status green | `-apple-system-green` | `#34c759` | `#30d158` |
| Status orange | `-apple-system-orange` | `#ff8d28` | `#ff9230` |

Measured: WKWebView `getComputedStyle` and `NSColor` in sRGB, macOS 27.0.1, Multicolor accent. Fallbacks are the `NSColor` values; WKWebView resolves every keyword to the same value except the selection colours, which it gives as `#0063e1` (light) and `#0058d0` (dark), and the dark secondary label, which it rounds to alpha 0.55. `-apple-system-control-background` and `-apple-system-secondary-background` resolve to the same value as `-apple-system-background`.

**Electron (Chromium).** Read the same colours in the main process with `systemPreferences.getColor()`: `window-background`, `control-background`, `label`, `secondary-label`, `separator`, `selected-content-background`, `unemphasized-selected-content-background` (each returns `#RRGGBBAA`). Send them to the renderer through the preload, set them as CSS variables, and re-read them on `nativeTheme` `updated` and on window `focus`.

**The user's accent.**
- Tauri: use `-apple-system-control-accent`. Verify it follows by switching the accent in System Settings with the app running. If it stays blue, read `NSColor.controlAccentColor` in Rust (objc2-app-kit 0.3, features `NSColor` and `NSColorSpace`), convert it to sRGB, emit it to the webview, and re-read it on app activation and appearance change.
- Electron: `systemPreferences.getAccentColor()` (documented for macOS 10.14+) in the main process, sent through the preload; re-read on window `focus`.
- The CSS `AccentColor` keyword is a fixed blue in Safari 16.5+ and Chrome 149+ and unsupported in older Chromium (MDN browser-compat-data). `AccentColorText` resolves to black in WKWebView. Use the native read above.

**Selection.** List rows take the selection tokens:

```css
.list [aria-selected="true"] { background: var(--selection); color: var(--selection-text); }
.list:not(:focus-within) [aria-selected="true"],
:root.window-inactive .list [aria-selected="true"] { background: var(--selection-unfocused); color: var(--label); }
```

`--selection-text` is white. Toggle `window-inactive` on window `blur`/`focus` and `visibilitychange`. Text and search fields keep the system focus ring.

**Status.** System red, green and orange, each paired with a shape and a word.

## Window chrome

- **Default:** the standard title bar and an opaque window background, which is each stack's default window config (HIG: avoid custom window UI).
- **Sidebar layouts:** overlay title bar with the `sidebar` material.
  - Tauri: `"titleBarStyle": "Overlay"`, `"hiddenTitle": true`, `"transparent": true`, `"windowEffects": { "effects": ["sidebar"], "state": "followsWindowActiveState" }`. Mac-only apps put these in `tauri.conf.json`; cross-platform apps in `src-tauri/tauri.macos.conf.json`. A platform file's `app.windows` array replaces the base array (RFC 7396 merge in tauri-utils), so repeat the full window object. `macOSPrivateApi` is a no-op since Tauri 2.12.1 (tauri `src/lib.rs` docs), so leave it out.
  - Tauri drag regions: `data-tauri-drag-region` plus the `core:window:allow-start-dragging` permission. A double-click on a drag region always toggles maximize, whatever the user's title-bar double-click setting (tauri 2.12.5 `src/window/scripts/drag.js`, lines 86–126). An Overlay window can't be dragged while unfocused.
  - Electron: `titleBarStyle: 'hiddenInset'`, `vibrancy: 'sidebar'`; drag with `app-region: drag` and `app-region: no-drag` on controls.
  - Then: put the window title (short, not the app name) in the toolbar's leading zone; pad the sidebar top to clear the traffic lights; keep content panes opaque; dim custom chrome under `:root.window-inactive`; drop the traffic-light padding in full screen (Tauri: on `WindowEvent::Resized` read `window.is_fullscreen()` and emit it; Electron: `enter-full-screen` and `leave-full-screen`).
- **Reduce Transparency:** `prefers-reduced-transparency` never matches in WKWebView. Read `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` natively and set a root class that gives the sidebar an opaque background.
- **Reduce Motion:** `@media (prefers-reduced-motion: reduce)` works; spinners and transitions stop or become fades.

## Behaviour

- **Toolbar** zones: leading (sidebar toggle, title), centre (common controls), trailing (primary action, search field).
- **Search field:** ⌘F focuses it, Escape clears it, the placeholder names the scope ("Search Notes").
- **Lists:** `role="listbox"` with `aria-activedescendant` on a focusable container, options in labelled groups (listbox → group → option). Arrow keys move; typing jumps to the first matching row; Delete removes the selection with Undo; when the list takes focus with nothing selected, select the first row. The selection highlight is the focus indicator, so the container has no ring.
- **Tables:** `role="grid"` with `aria-activedescendant`; sortable headers with `aria-sort` (a second click reverses); resizable columns; arrow, Home, End and Page keys.
- **Sidebar:** show and hide from a toolbar button and View → Show/Hide Sidebar; icons in the accent colour.
- **Icons:** SF Symbols exported as masks. Render each with `NSImage(systemSymbolName:)` and `NSImage.SymbolConfiguration(pointSize:weight:)` at the weight of the adjacent text, at @2x, black on transparent PNG; apply it as `mask-image` over `background-color: currentColor`. An icon-only control carries its accessibility label as `aria-label`.
- **Focus:** `:focus-visible { outline: auto; }` draws WebKit's platform ring.
- **Keyboard:** inside text fields, only Escape and ⌘ chords trigger app actions; Ctrl+A/E/F/B/N/P/D/K edit text there.
- **Text selection:** `user-select: none` on chrome (toolbars, sidebar labels); content, names and errors stay selectable.
- **Custom sheets:** `<dialog>` with `showModal()`, focus returned to the opener on close. Alerts are native (`menus-settings-about.md` → Alerts).
- **Cursor:** `cursor: default` on controls; `pointer` on real links only.

## Preview harness

Step 3 snapshots every surface by URL, so the app ships a dev-only preview harness:

- A mocked IPC layer that loads only in dev builds running outside the native shell: Tauri `mockIPC` from `@tauri-apps/api/mocks`; Electron a stub of the preload API on `window`. It returns fixture data for every command the surfaces call.
- A URL control per surface the conformance table covers: each sheet, dialog, palette, drawer, Settings pane, overlay, empty state and error state (for example `?surface=settings-general`, `?surface=delete-sheet`, `?state=empty`). The app reads it at startup and renders that surface open; production builds leave the harness out.
- The snapshot script's JS argument reads values (computed styles, the font-size probe). It runs once, 1.2 s after load, so clicks passed there are unreliable for state that renders asynchronously; open surfaces through the URL.
- Native menus, context menus, alerts and the About panel don't render in the harness; Step 3 judges them from code.
