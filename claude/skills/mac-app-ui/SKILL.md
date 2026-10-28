---
name: mac-app-ui
description: Use when building, restyling or reviewing a Mac app's UI — Tauri or Electron webview apps and SwiftUI/AppKit apps — including windows, sidebars, lists, type sizes, colours, menus, Settings, About, menu-bar extras and app icons; also when a Mac app UI "looks like a web page", "looks like a terminal" or has text that is too small.
license: MIT
compatibility: macOS 14+; Tauri 2, Electron 32+, SwiftUI
metadata:
  author: s3rgiosan
---

# Mac app UI standard

Every app follows Apple's Human Interface Guidelines for macOS and the same house conventions, so the apps feel native and consistent with each other. Native controls already follow the guidelines; the work is in webview apps, custom views and the platform wiring around them.

## Step 1: ask before building

Ask the user these and record the answers in the project's CLAUDE.md. Don't assume.

1. **Platforms.** macOS only (the default), or also Linux and Windows? Only cross-platform apps add `CmdOrCtrl`/`ctrlKey` handling, non-Mac window chrome and per-platform configs.
2. **Menu-bar extra.** Does the app need an always-visible status item in the macOS menu bar? Only apps whose purpose is glanceable status need one, such as a CI or system monitor. It is not a default.
3. **Shape.** Regular windowed app, menu-bar-only app (no Dock icon), or both?

## Step 2: apply the house conventions

| Area | Rule |
|---|---|
| Type | Apple text styles only. Webview sizes: see `references/webview.md` → Type. Never below 11px; no monospace outside code; no all-caps labels. |
| Colour | System/semantic colours and the user's accent. No hard-coded brand blue/green for accent or selection. Light and dark always; 4.5:1 for text under 18pt. |
| Selection | Lists and tables: a highlight, no focus ring. Accent fill + white text while the list has focus (darken the fill until white reaches 4.5:1); grey when focus is elsewhere or the window is inactive. Text and search fields: the system focus ring. |
| App menu bar | Every app with a Dock icon sets its own: App (About, Settings… ⌘,, Services, Hide, Hide Others, Show All, Quit), File, Edit, View, Window, Help. Help holds "<App> Help", opening the app's docs or README URL. Every custom item is wired and tested. Menu-bar-only apps: About, Settings… and Quit live in the status item's menu; while their Settings window is open (and the app is briefly Regular) they show a reduced app menu — App (About, Settings…, Hide, Hide Others, Show All, Quit), Edit, Window — so copy/paste and ⌘W work. |
| Menu-bar extra | Only when Step 1 says so. A native menu when every entry is one line of text, optionally with an icon or checkmark. A small popover window (about 360–380 × 480–520) when entries need two lines, grouped rows with metadata, or inline controls; its footer may hold Settings… and a "More" button opening the same native menu as a right-click (About, Settings…, Quit). |
| Settings | Its own non-modal window, opened by Settings… ⌘,; changes apply immediately; no Save/Cancel; no Close button. One store every window reads, with a change broadcast. |
| About | The native About panel, first app-menu item "About <App>" (menu-bar-only apps: first item in the status item's menu). Product name in its proper case, version once, `© <current year> <copyright holder in the project's LICENSE>`, a one-line description taken from the README tagline (ask if there's none), the app icon. |
| Errors | Inline next to what failed; a banner that stays until dismissed for app-level errors, text selectable; modal alerts only to confirm destructive actions. |
| Empty states | A title, one line of explanation, and the one action that fills it. |
| Icons | In-app: SF Symbols (SwiftUI) or SF Symbols exported as PNG masks (webview: render each symbol with `NSImage(systemSymbolName:)` to a black-on-transparent PNG and use it as a CSS mask; Lucide on Linux/Windows because the SF Symbols licence covers Apple platforms only). App icon: follow the icon design system the user names; by default the one at https://claude.ai/artifact/QimJSWWYsG1ghfNaSprKxy (read its `project/README.md`). Never redraw or restate its recipe. |
| Motion | Spinners and transitions stop or simplify under `prefers-reduced-motion` / Reduce Motion. |
| Wording | Title Case for buttons, menu items, window and tab titles; sentence case for labels, help text and descriptions; "…" when a command opens more UI. |
| Accessibility | Every icon-only control has a label; status never by colour alone; keyboard reaches everything; Full Keyboard Access works. |

Stack details: `references/webview.md` (Tauri, Electron), `references/swiftui.md`. Sourced HIG facts: `references/hig-macos.md`.

## Step 3: verify before calling it done

1. Build it and run it. Look at it in light and dark, focused and unfocused, at the minimum window size. Webview apps: render screens with `swift scripts/webkit-snapshot.swift <url> <width> <height> <out.png> <light|dark> [script]` (WKWebView, so system colours resolve as in the app) and read the PNGs; compare controls against `swift scripts/appkit-reference.swift <out-dir>` (real AppKit controls).
2. Use it with the keyboard only, and with VoiceOver on (⌘F5) for the main flow.
3. Click every menu item and confirm each does something.
4. Switch the accent colour and appearance in System Settings while the app runs; the UI must follow.
5. Check every value you took from memory (config keys, API names, "required" flags) against the installed source or docs; say which ones you couldn't check.

## Common mistakes

| Mistake | Fix |
|---|---|
| Copying native point sizes 1:1 into a webview (13px everything, 11px secondary) | Use the webview type scale; content text is larger than control text. |
| `AccentColor` CSS keyword "follows the user's accent" | It is a fixed blue in WebKit and Chromium. Read the accent natively (`references/webview.md`). |
| Uppercase tracked section headers, monospace numbers | Title Case headers at Headline weight; system font with tabular figures. |
| Settings as an in-window drawer/modal with Save | Separate Settings window, changes apply immediately. |
| Menu items or tray items emitting events nobody listens to | Wire and test each one. |
| "Dynamic Type" on macOS | macOS has no Dynamic Type; text styles have fixed sizes. Offer ⌘+/⌘− zoom in webview apps. |
| Global `user-select: none` | Only on chrome; errors, names and content stay selectable. |
| Stale config claims (`macOSPrivateApi` "required") | Check the installed version's source. |
