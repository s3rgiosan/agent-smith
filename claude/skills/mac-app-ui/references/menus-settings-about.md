# Menus, menu-bar extra, Settings, About

The contract both stacks follow, with the Tauri, Electron and SwiftUI calls for each part. HIG sources: `hig-macos.md` → Menus and the menu bar, Settings, Alerts, Writing.

## App menu bar

Every app with a Dock icon sets its own menu bar:

- **App:** About <App> (own group), Settings… ⌘,, Services, Hide <App>, Hide Others, Show All, Quit <App>.
- **File:** the document commands the app has (New, Open, Close ⌘W).
- **Edit:** Undo, Redo, Cut, Copy, Paste, Delete, Select All, Find.
- **View:** Show Sidebar or Hide Sidebar (the title reflects the current state), Enter Full Screen, and the zoom items in webview apps.
- **Window:** Minimize, Zoom, Bring All to Front.
- **Help:** "<App> Help", opening the app's docs or README URL.

Every toolbar and context-menu command also has a menu-bar item. Unavailable items stay in place, dimmed.

- Tauri: build the menu in Rust with `tauri::menu` (`SubmenuBuilder`, `PredefinedMenuItem`), set it on the app, and emit custom items to the focused window. In a WKWebView probe the page received ⌘ key events before the menu, and calling `preventDefault` on a handled key also stopped the menu item firing. Give each shortcut one owner: the menu item, or the page handler that calls `preventDefault`.
- Electron: `Menu.setApplicationMenu(Menu.buildFromTemplate(…))` with `role`s for standard items (`appMenu`, `editMenu`, `viewMenu`, `windowMenu`, `help`); custom items go over IPC through the preload.
- SwiftUI: `.commands { CommandGroup(…) }` for every main action with its shortcut; the toolbar and the menu share the same enabled rules. Help: replace `.help` with one "<App> Help" item that calls `openURL`, unless the app ships a Help Book.

## Context menus

Native menus built in the backend: Tauri `window.popup_menu(&menu)`, Electron `menu.popup({ window })`, SwiftUI `.contextMenu`. The page calls `preventDefault` on `contextmenu` over chrome and asks the backend for the menu. Unavailable items are hidden, except Cut, Copy and Paste, which show dimmed. Shortcuts appear in the menu bar, not in context menus.

## Activation policies

- **Regular:** Dock icon and the app's menu bar.
- **Accessory:** no Dock icon and no menu bar; windows can still be activated.

Menu-bar-only apps run as Accessory: Tauri `app.set_activation_policy(ActivationPolicy::Accessory)`, Electron `app.setActivationPolicy('accessory')`, SwiftUI `LSUIElement` in the built `Contents/Info.plist` plus `NSApp.setActivationPolicy(.accessory)`. If testing shows the Settings window opens without keyboard focus, switch to Regular while it is open and back to Accessory when it closes; while Regular, show a reduced menu bar (App with About, Settings…, Hide, Hide Others, Show All, Quit; Edit; Window) so copy, paste and ⌘W work.

## Menu-bar extra

Only when the CLAUDE.md shape includes one.

- Icon: a black-and-clear template image (Tauri `icon_as_template(true)`).
- Content: a native menu. It holds section headers (AppKit `NSMenuItem.sectionHeader(title:)`, macOS 14+) and item subtitles (AppKit `NSMenuItem.subtitle` and Electron `sublabel`, macOS 14.4+). muda 0.20 has `PredefinedMenuItem::section_header`, but Tauri 2.12.5 doesn't expose it and muda has no subtitles, so Tauri apps use a disabled `MenuItem` as a header.
- A popover window only for inline controls or live content a menu can't hold: Tauri `show_menu_on_left_click(false)` with a window using `"effects": ["popover"]`; SwiftUI `.menuBarExtraStyle(.window)` (plain items use `.menu`). The popover hides on blur and Escape; its footer holds Settings… and a More button that opens the native menu (About, Settings…, Quit).
- Menu-bar-only apps put About <App>, Settings… and Quit <App> in the extra's menu.
- The system hides extras when the menu bar is full, so relaunching the app opens its popover or Settings: Tauri `RunEvent::Reopen`, Electron `app` `activate`, AppKit `applicationShouldHandleReopen(_:hasVisibleWindows:)`.
- Windowed apps with an extra offer a Show in Menu Bar setting: Tauri `TrayIcon::set_visible`, SwiftUI `MenuBarExtra(isInserted:)`.

## Settings window

- Its own non-modal window, opened by Settings… ⌘,; opening it again focuses the existing one.
- Several panes: a toolbar of pane buttons that can't be customised and always shows the active pane. The window title is the pane name; a single-pane window is titled "<App> Settings". Reopen on the last viewed pane.
- Minimize and zoom disabled, not resizable, centred: Tauri `WebviewWindowBuilder` with label `settings` and `.minimizable(false).maximizable(false).resizable(false).center()`; Electron `new BrowserWindow({ minimizable: false, maximizable: false, resizable: false })`; SwiftUI `Settings { SettingsView() }` with a `TabView` for panes, `Form` with `.formStyle(.grouped)` for one.
- Changes apply immediately with no Save or Cancel. Toggles and pop-ups apply on change; text and number fields on commit (Return or leaving the field).
- One store every window reads, with a change broadcast: a settings file the backend owns, or `localStorage` with the `storage` event (webview); `@AppStorage` (SwiftUI).
- Tauri: the window gets its own capability with only the permissions it uses.
- SwiftUI: `SettingsLink` opens it; if testing shows the window opening behind other apps, activate the app first.

## About

The native About panel, first item of the App menu (menu-bar-only apps: first item of the extra's menu).

- Product name in its proper case, not the package name.
- The version once.
- `© <current year> <copyright holder in LICENSE>`.
- Credits: the README tagline as one line; ask the user when the README has none.
- The icon from the app bundle.

Calls:
- Tauri: `AboutMetadata { name, version, short_version: Some(String::new()), copyright, credits, .. }`. muda passes `short_version` as `NSAboutPanelOptionVersion`, the build number AppKit shows in parentheses after the version; an empty string leaves it blank.
- Electron: `app.setAboutPanelOptions({ applicationName, applicationVersion, copyright, credits })`; check in the running app that the version shows once (`version` is the build number).
- SwiftUI: an "About <App>" item replacing `.appInfo` that calls `NSApp.orderFrontStandardAboutPanel(options:)` with credits; `NSHumanReadableCopyright` in Info.plist holds the copyright line.

## App icon

Follow the icon design system the user names. By default it is the one at https://claude.ai/artifact/QimJSWWYsG1ghfNaSprKxy: read its `project/README.md` and follow it. If the link can't be read, ask the user for the icon system.

## Alerts and errors

- Alerts are for destructive actions that can't be undone and for failures that block the task. Undoable actions run at once and offer Undo.
- Native alerts: Tauri `tauri-plugin-dialog` (an `NSAlert`, shown as a sheet when the builder gets `.parent(&window)`); Electron `dialog.showMessageBox(window, …)` (a sheet on the given window); SwiftUI `.alert` or `.confirmationDialog`.
- The title states the situation, without "Error". Buttons are verbs; Cancel is always "Cancel". The default button is trailing; Escape and ⌘. cancel.
- Other errors: inline next to what failed; app-level errors in a banner that stays until dismissed. Error text is selectable.

## Wording and accessibility

- Title Case: buttons, menu items, window and tab titles, column headings, toolbar item labels.
- Sentence case: labels, help text, descriptions, alert informative text.
- "…" ends a command that needs more input before it completes.
- Every icon-only control has an accessibility label; status pairs colour with a shape or a word; the keyboard reaches every control.
