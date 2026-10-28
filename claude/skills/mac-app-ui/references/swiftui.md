# SwiftUI / AppKit apps

Native controls already follow the guidelines. Use them as they are and spend the effort on custom views and the wiring. Menus, the menu-bar extra, Settings, About and alerts are in `menus-settings-about.md`.

## Structure

- Windowed app: `WindowGroup` (or `Window` for a single window) with `NavigationSplitView` for sidebar layouts; `Table` or `List` for collections, with selection and context menus; toolbar items as `Label`s with `.help`.
- Empty states: `ContentUnavailableView` (content: `menus-settings-about.md` → Wording and accessibility).

## Type and colour

- Default text styles: `.body` for row titles, controls and labels; `.callout` for metadata; `.headline` for list group headers; `.title3`, `.title2` and `.title` for the larger roles in the `SKILL.md` scale. UI text uses text styles, not `.font(.system(size:))`. macOS has no Dynamic Type; the styles have fixed sizes (`hig-macos.md` → Typography).
- Semantic colours: `.primary`, `.secondary`, `Color.accentColor`, `.bar`. Literal colours appear only in the asset catalog.
- `.monospacedDigit()` for numbers in columns; monospace fonts for code only.

## Wiring traps

- Paste, copy, undo: route through the Edit menu (`.onPasteCommand`, `CommandGroup(after: .pasteboard)`) so Edit > Paste and its shortcut both work; an `NSEvent` key monitor bypasses the menu.
- Accessibility: `.accessibilityLabel` on icon-only `Button`s and on custom progress or status views; `.accessibilityValue` for progress; `AccessibilityNotification.Announcement` for transient feedback.
- Every action is reachable from a menu or shortcut, as well as from any bottom bar or hover button.
