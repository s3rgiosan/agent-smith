# SwiftUI / AppKit apps

Native controls already follow the guidelines. Use them as they are and spend effort on custom views and the platform wiring.

## Structure

- Windowed app: `WindowGroup` (or `Window` for single-window apps) with `NavigationSplitView` for sidebar layouts; `Table` or `List` for collections, with selection and context menus; toolbar items as `Label`s with `.help`.
- `Settings { SettingsView() }` scene: gives Settings… ⌘, in the app menu for free. Use a `TabView` for several panes, `Form` with `.formStyle(.grouped)` for one; changes apply immediately (`@AppStorage`).
- Commands: `.commands { CommandGroup(…) }` for every main action, with keyboard shortcuts; the toolbar and the menu share the same enabled rules.
- Menu-bar extra (only if Step 1 says so): `MenuBarExtra` with `.menuBarExtraStyle(.menu)` when the content is plain items; `.window` only when it needs custom rows. Menu-bar-only apps set `LSUIElement` in the Info.plist that ends up in the app bundle (check how the build produces the bundle and confirm the key is in the built `Contents/Info.plist`) and `NSApp.setActivationPolicy(.accessory)`. Open Settings with `SettingsLink` and activate the app first.

## Type and colour

- Text styles only (`.body`, `.headline`, `.title3`, `.callout`, `.subheadline`); no `.font(.system(size:))` for UI text. macOS has no Dynamic Type: the styles have fixed sizes (`hig-macos.md` → Typography).
- Semantic colours (`.primary`, `.secondary`, `Color.accentColor`, `.bar`); no hex for UI chrome.
- `.monospacedDigit()` for numbers in columns; no monospace fonts outside code.

## Wiring traps

- Paste, copy, undo: route through the Edit menu (`.onPasteCommand`, `CommandGroup(after: .pasteboard)`), not an `NSEvent` key monitor, so Edit > Paste and the menu shortcut both work.
- About: `NSApp.orderFrontStandardAboutPanel(options:)` with credits (the one-line description) from a "About <App>" item replacing `.appInfo`; set `NSHumanReadableCopyright` to `© <current year> Sérgio Santos` in Info.plist so the panel shows it.
- Help: replace `.help` with one "<App> Help" item that opens the app's docs or README URL (`openURL`), unless the app ships a Help Book.
- Accessibility: `.accessibilityLabel` on every icon-only `Button` and on custom progress or status views; `.accessibilityValue` for progress; announce transient feedback (`AccessibilityNotification.Announcement`) instead of relying on animation alone.
- Every action reachable from a menu or shortcut, not only from a bottom bar or a hover button.
