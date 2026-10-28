# Webview apps (Tauri 2, Electron)

A webview renders CSS pixels at 1 px = 1 pt on macOS at 100% zoom, so native point sizes carry over exactly. What makes webview apps feel "small" or "like a terminal" is a flat scale (everything 13px or less), all-caps tracked labels, monospace numbers and tight rows — not the base size itself.

## Type

System font only: `font-family: system-ui, -apple-system, sans-serif;` (no named "SF Pro" files). Map Apple's macOS text styles (`hig-macos.md` → Typography) to roles:

| Role | Style | Size / line height | Weight |
|---|---|---|---|
| Window or detail title | Title 1 | 22 / 26 | 700 |
| Pane or section title | Title 2 | 17 / 22 | 600 |
| Primary content: list row titles, detail text, reading text | Title 3 | 15 / 20 | 400 (600 when emphasised) |
| Controls, buttons, form labels, sidebar items, menus-in-page | Body | 13 / 16 | 400 |
| Group headers in lists and tables | Headline | 13 / 16 | 700, Title Case, no tracking |
| Sidebar section headers (house judgment; the HIG only asks for succinct labels) | Subheadline | 11 / 14 | 600, Title Case, secondary label colour |
| Secondary metadata: dates, counts, subtitles | Callout | 12 / 15 | 400, secondary label colour |
| Badges, tiny counts only | Subheadline | 11 / 14 | 400 |

- Nothing below 11px (house rule; Apple's minimum is 10pt).
- Numbers in columns: `font-variant-numeric: tabular-nums;` in the system font, not monospace.
- Monospace (`ui-monospace`) only for code, paths and command output.
- Row heights follow the text: a list row with a Title 3 title and a Callout subtitle is about 44–52px; a single-line sidebar row about 28px.
- Starting sizes (house defaults; the HIG states none): toolbar 52px, sidebar 220px, content list 320px, detail flexible with a ~640px reading column, controls 28px tall (the macOS default control size, `hig-macos.md` → Layout).
- Offer zoom in apps with a main window: Tauri `"zoomHotkeysEnabled": true` on the window plus the `core:webview:allow-set-webview-zoom` permission (core defaults don't include it); Electron handles ⌘+/⌘− via the View menu's zoom roles. Menu-bar popovers skip zoom.

## Colour

- Define tokens on `:root`, override under `@media (prefers-color-scheme: dark)`, and set `color-scheme: light dark`.
- WebKit's semantic colours work in Tauri on macOS behind a feature check: `@supports (color: -apple-system-label) { … -apple-system-label, -apple-system-secondary-label, -apple-system-separator, -apple-system-window-background, -apple-system-control-background, -apple-system-red, -apple-system-green, -apple-system-orange … }` (in production in Vigia, `src/App.css`). Keep literal fallbacks outside the `@supports`. They are WebKit-only: Electron (Chromium) uses the literal light/dark tokens.
- Status colours: the system red/green/orange (above) where available; literal fallbacks darkened in light mode so icons reach 3:1. Status always pairs colour with a shape and a word.
- **The user's accent colour:** the CSS `AccentColor` keyword is a fixed blue in Safari 16.5+ and Chrome 149+ (MDN browser-compat-data), so it does not follow System Settings. Read the real value natively and push it into a CSS variable:
  - Electron: `systemPreferences.getAccentColor()` (macOS, Windows) from the main process, sent to the renderer through the preload; re-read on window focus and `nativeTheme` `updated` (the `accent-color-changed` event isn't relied on for macOS).
  - Tauri: read `NSColor.controlAccentColor` in Rust (objc2-app-kit, `NSColor` + `NSColorSpace` features) converted to sRGB, and emit it to the webview; re-read on app activation and appearance change, since it's a dynamic colour.
  - Verify in the running app by switching the accent and appearance in System Settings.
- Text on the accent: white, as macOS does; when white on the accent is under 4.5:1 (the default blue `#007aff` is about 4.0:1), darken the fill until it passes. Don't use `AccentColorText` (fixed black in WebKit).
- Contrast: 4.5:1 for text under 18pt, 3:1 for 18pt+ and for icons/control borders, in both themes (`hig-macos.md` → Accessibility, Color).

## Window chrome (macOS)

- Tauri: `"titleBarStyle": "Overlay"`, `"hiddenTitle": true`, `"transparent": true`, `"windowEffects": { "effects": ["sidebar"], "state": "followsWindowActiveState" }` (menu-bar popovers: `"effects": ["popover"]`). Mac-only apps put these in `tauri.conf.json`. Cross-platform apps put them in `src-tauri/tauri.macos.conf.json` so other platforms keep normal windows.
  - A platform file's `app.windows` array **replaces** the base array (RFC 7396 merge in tauri-utils), so repeat the full window object (label, title, sizes, zoom).
  - `macOSPrivateApi` is a no-op since Tauri 2.12.1 (tauri `src/lib.rs` docs); don't add it.
  - Drag regions need `data-tauri-drag-region` and the `core:window:allow-start-dragging` permission. With an Overlay title bar the window can't be dragged while unfocused (tauri#4316).
  - Pad the sidebar top so content clears the traffic lights; keep content panes opaque; honour `prefers-reduced-transparency`.
- Electron: `titleBarStyle: 'hiddenInset'`, `vibrancy: 'sidebar'` (or `'under-window'`), drag via `-webkit-app-region: drag` with controls set to `no-drag`.

## Menus, Settings, About

- **App menu bar.**
  - Tauri: build it in Rust with `tauri::menu` (`SubmenuBuilder`, `PredefinedMenuItem`, `AboutMetadata`), set it on the app, and emit custom items to the focused window. The page receives ⌘ key events before the menu does; calling `preventDefault` on a handled key stops the menu firing too (wry 0.57). Never handle the same shortcut in both places without that guard.
  - Electron: `Menu.setApplicationMenu(Menu.buildFromTemplate(…))` with `role`s for standard items; send custom items over IPC through a preload and handle them in the renderer.
- **Settings window.** A second window (Tauri `WebviewWindowBuilder` with label `settings`; Electron a second `BrowserWindow`), not resizable, centred, routed by label or hash; opening it again focuses the existing one. Persist settings in one store every window reads — the backend (a settings file the main process owns) or `localStorage` with the `storage` event — and apply changes in every window when they change. Give it its own capability with only the permissions it uses (Tauri).
- **About.** Tauri `AboutMetadata { name, version, short_version: Some(String::new()), copyright, credits, .. }` (the empty `short_version` keeps the version from showing twice); Electron `app.setAboutPanelOptions({ applicationName, applicationVersion, copyright, credits })` — check in the running app that the version doesn't show twice. Use the product name, not the package name. The icon comes from the app bundle.
- **Menu-bar extra (Tauri).** Tray icon as a black-and-clear template image (`icon_as_template(true)`), `ActivationPolicy::Accessory` for menu-bar-only apps, `show_menu_on_left_click(false)` when a left click opens a popover window; the popover hides on blur and Escape. Under the Accessory policy a new window may not receive keyboard focus, so switch to `Regular` while the Settings window is open and back to `Accessory` when it closes. Vigia's `src-tauri/src/tray.rs` and `windows.rs` are the working reference.

## Behaviour

- Selection: accent fill with readable text while the list has focus; `--selection-inactive` grey when focus is elsewhere or the window is inactive (toggle a root class on window `blur`/`focus` and `visibilitychange`).
- Focus: `:focus-visible { outline: auto; }` gives WebKit's platform ring; don't draw custom rings.
- Keyboard: inside text fields on macOS only Escape and ⌘ chords may trigger app actions; Ctrl+A/E/F/B/N/P/D/K are text-editing keys there.
- Text selection: `user-select: none` on chrome only (toolbars, sidebar labels); content, names and errors stay selectable.
- Dialogs: `<dialog>` with `showModal()`; return focus to the opener on close.
- Lists: `role="listbox"` with `aria-activedescendant` on a focusable container, options in labelled groups (listbox → group → option only). The container shows no focus ring; the selection highlight is the indicator.
- Tables (several columns): `role="grid"` with `aria-activedescendant`, sortable headers with `aria-sort` (click again to reverse), resizable columns, arrow/Home/End/Page keys.
- Motion: spinners and transitions stop or simplify under `@media (prefers-reduced-motion: reduce)`.
- Cursor: `cursor: default` on controls (macOS uses the arrow), pointer only for real links.
