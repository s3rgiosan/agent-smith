# Apple HIG: macOS facts

Extracted from the JSON feed behind each page (`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`). Human URL base: `https://developer.apple.com/design/human-interface-guidelines/<slug>`. Quotes are Apple's wording. "Not stated" means the page gives no value. Several tables on the pages have API-name or image-only columns that the JSON does not expose; those are noted.

Slug 404s: `the-dock`, `menu-bar-extras`, `status-bar-extras`. Menu bar extras are a section of `the-menu-bar` (anchor `#Menu-bar-extras`). Dock guidance exists only as `dock-menus` (200).

---
## 1. Typography
Source: https://developer.apple.com/design/human-interface-guidelines/typography

- macOS default text size 13 pt, minimum 10 pt (iOS 17/11, tvOS 29/23, visionOS 17/12, watchOS 16/12).
- "SF Pro is the system font in macOS. NY is available for Mac apps built with Mac Catalyst. macOS doesn't support Dynamic Type."
- "In general, avoid light font weights... prefer Regular, Medium, Semibold, or Bold... avoid Ultralight, Thin, and Light."
- "Minimize the number of typefaces you use."
- "Use dynamic system font variants to match the text in standard controls" (macOS). Variants listed (API column empty in feed): Control content, Label, Menu, Menu bar, Message, Palette, Title, Tool tips, Document text (user), Monospaced document text (user fixed pitch), Bold system font, System font.
- Don't embed system fonts; use system font constants. System fonts are variable with dynamic optical sizes; in a running app the system adjusts tracking at every point size.
- Text style = weight + point size + leading. Emphasized variants via symbolic traits (SwiftUI `bold()`-style modifier / UIKit symbolic traits); emphasized weights can be medium, semibold, bold, or heavy.
- Loose leading for wide columns/long passages; tight leading for constrained height (list row); "If you need to display three or more lines of text, avoid tight leading."

### macOS built-in text styles (as found)
| Text style | Weight | Size (pt) | Line height (pt) | Emphasized weight |
|---|---|---|---|---|
| Large Title | Regular | 26 | 32 | Bold |
| Title 1 | Regular | 22 | 26 | Bold |
| Title 2 | Regular | 17 | 22 | Bold |
| Title 3 | Regular | 15 | 20 | Semibold |
| Headline | Bold | 13 | 16 | Heavy |
| Body | Regular | 13 | 16 | Semibold |
| Callout | Regular | 12 | 15 | Semibold |
| Subheadline | Regular | 11 | 14 | Semibold |
| Footnote | Regular | 10 | 13 | Semibold |
| Caption 1 | Regular | 10 | 13 | Medium |
| Caption 2 | Medium | 10 | 13 | Semibold |

### macOS tracking values (size pt -> tracking in 1/1000 em / points)
6: +41/+0.24; 7: +34/+0.23; 8: +26/+0.21; 9: +19/+0.17; 10: +12/+0.12; 11: +6/+0.06; 12: 0/0.0; 13: -6/-0.08; 14: -11/-0.15; 15: -16/-0.23; 16: -20/-0.31; 17: -26/-0.43; 18: -25/-0.44; 19: -24/-0.45; 20: -23/-0.45; 21: -18/-0.36; 22: -12/-0.26; 23: -4/-0.10; 24: +3/+0.07; 25: +6/+0.15; 26: +8/+0.22; 27: +11/+0.29; 28: +14/+0.38; 29: +14/+0.40; 30: +14/+0.40; 31: +13/+0.39; 32: +13/+0.41; 33: +12/+0.40; 34: +12/+0.40; 35: +11/+0.38; 36: +10/+0.37; 37: +10/+0.36; 38: +10/+0.37; 39: +10/+0.38; 40: +10/+0.37; 41: +9/+0.36; 42: +9/+0.37; 43: +9/+0.38; 44: +8/+0.37; 45: +8/+0.35; 46: +8/+0.36; 47: +8/+0.37; 48: +8/+0.35; 49: +7/+0.33; 50: +7/+0.34; 51: +7/+0.35; 52: +6/+0.31; 53: +6/+0.33; 54: +6/+0.32; 56: +6/+0.30; 58: +5/+0.28; 60: +4/+0.26; 62: +4/+0.24; 64: +4/+0.22; 66: +3/+0.19; 68: +2/+0.17; 70: +2/+0.14; 72: +2/+0.14; 76: +1/+0.07; 80-96: 0/0.
The page says to adjust tracking "in interface mockups" only; running apps get it automatically.

---
## 2. Designing for macOS
Source: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos

- Viewing distance "about 1 to 3 feet".
- "Leverage large displays to present more content in fewer nested levels and with less need for modality."
- "Let people resize, hide, show, and move your windows... and support full-screen mode."
- "Use the menu bar to give people easy access to all the commands they need."
- "Handle keyboard shortcuts"; "Support personalization, letting people customize toolbars, configure windows... and choose the colors and fonts they want."

---
## 3. Layout (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/layout

- "Avoid placing controls or critical information at the bottom of a window. People often move windows so that the bottom edge is below the bottom of the screen."
- "Avoid displaying content behind the camera housing at the top edge of the window."
- General: place most important items near top and leading side; align and indent to convey hierarchy; group related items; progressive disclosure (disclosure triangles, menus, nested views).
- "Instead of applying a solid or semi-opaque background color beneath controls, use a scroll edge effect"; extend full-window background content underneath sidebars/toolbars; a background extension effect mirrors/blurs an image under sidebars/inspectors.
- Spacing/margin values for macOS: not stated.

---
## 4. Sidebars
Source: https://developer.apple.com/design/human-interface-guidelines/sidebars

- macOS: "A sidebar's row height, text, and glyph size depend on its overall size, which can be small, medium, or large. You can set the size programmatically, but people can also change it by selecting a different sidebar icon size in General settings." Numeric row heights / widths: not stated.
- "In general, show no more than two levels of hierarchy in a sidebar." Deeper data: split view with a content list between sidebar and detail.
- Two levels: "use succinct, descriptive labels to title each group."
- "Group hierarchy with disclosure controls if your app has a lot of content."
- Icons: SF Symbols; custom icon -> prefer a custom symbol over bitmap. "By default, sidebar icons use your app's accent color." Users can change system accent color and "expect all sidebar icons to appear in that color"; fixed colors only sparingly (example: Mail VIP icon yellow).
- Hide/show: "Consider letting people hide the sidebar"; macOS: show/hide button or Show Sidebar / Hide Sidebar in the View menu. "Avoid hiding the sidebar by default."
- "Consider automatically hiding and revealing a sidebar when its container window resizes."
- "Avoid putting critical information or actions at the bottom of a sidebar."
- "Let people customize the contents of a sidebar" when possible.
- Sidebars float above content (Liquid Glass layer); extend visually rich content beneath.

---
## 5. Split views (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/split-views

- Panes can be arranged vertically, horizontally, or both; dividers can be dragged.
- "Prefer the thin divider style. The thin divider measures one point in width."
- "By default, a split view devotes a third of the screen width to the primary pane and two-thirds to the secondary pane, but you can also specify a half-and-half layout."
- "Set reasonable defaults for minimum and maximum pane sizes" (values not stated); keep divider visible.
- Persistently highlight current selection in each pane leading to the detail view.
- Provide multiple ways to reveal hidden panes (toolbar button, menu command with shortcut).
- "Display a single title above a split view."

---
## 6. Lists and tables (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/lists-and-tables

- Click column heading to sort; clicking an already sorted column re-sorts in the opposite direction.
- "Let people resize columns."
- "Consider using alternating row colors in a multicolumn table." (macOS bordered style uses alternating row backgrounds.)
- "Use an outline view instead of a table view to present hierarchical data" (disclosure triangles).
- Column headings: "Use nouns or short noun phrases... and don't add ending punctuation." (Capitalization link not resolved in the feed.)
- Hierarchy-navigating tables persistently highlight the selected row; option lists briefly highlight then show a checkmark.
- Truncation: middle ellipsis can help distinguish items.
- Row heights: not stated.

---
## 7. Toolbars
Source: https://developer.apple.com/design/human-interface-guidelines/toolbars

- macOS: "the toolbar resides in the frame at the top of a window, either below or integrated with the title bar. Note that window titles can display inline with controls, and toolbar items don't include a bezel."
- "Make every toolbar item available as a command in the menu bar. Because people can customize the toolbar or hide it, it can't be the only place that presents a command."
- Window title: "Don't title windows with your app name"; "keep the title under 15 characters long."
- Three zones: leading edge (back/sidebar toggle, then title, then optional document menu; not customizable), center (common controls; customizable, collapse into overflow), trailing edge (important items, inspector buttons, optional search field, More menu, primary action; visible at all sizes).
- "Minimize the number of groups... aim for a maximum of three."
- "Prefer system-provided symbols without borders"; "Prefer simple, recognizable symbols for items instead of text, except for actions like edit."
- "Use the `.prominent` style for key actions such as Done or Submit... Only specify one primary action, and put it on the trailing side."
- "Keep actions with text labels separate" (fixed space between text-labeled buttons).
- System adds overflow menu in macOS automatically; "Don't add an overflow menu manually."
- Standard Back and Close buttons: "don't use a text label that says Back or Close."
- Standard components have corner radii concentric with bar corners.
- Toolbar height: not stated.

---
## 8. Buttons (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/buttons

- Minimum hit region: "at least 44x44 pt" (general rule on this page). macOS control sizes: see Accessibility section (28x28 default, 20x20 minimum).
- Roles: Normal, Primary (default button), Cancel, Destructive. Primary uses accent color; destructive uses system red. "Don't assign the primary role to a button that performs a destructive action." Primary button responds to Return.
- "Keep the number of prominent buttons to one or two per view." "Use style — not size — to visually distinguish the preferred choice."
- Always include a press state for custom buttons. macOS shows a tooltip after hover.
- Button text: start with a verb ("Add to Cart").
- Push buttons (standard macOS button): can show text, symbol, icon, image; can be default; can be tinted. "Append a trailing ellipsis to the title when a push button opens another window, view, or app." Flexible-height push button only for tall/variable content (same corner radius/padding).
- Square (gradient) buttons: symbols/icons, not text; used in a view (e.g. add/remove table rows), "not in the window frame"; not for toolbars/status bars.
- Help button: circular with question mark; "no more than one help button per window"; locations: dialog with dismissal buttons -> lower corner opposite the dismissal buttons, vertically aligned with them; dialog without dismissal buttons or Settings window/pane -> lower-left or lower-right; in a view, not in window frame; no introductory text.
- Image button: "about 10 pixels of padding between the edges of the image and the button edges"; in a view, not the window frame; label below the image button.

---
## 9. Pop-up buttons
Source: https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons

- "Use a pop-up button to present a flat list of mutually exclusive options or states." Use a pull-down button to offer actions, multiple selection, or submenus.
- Button updates its content to show the current selection; provide a useful default selection.
- Give an introductory label or descriptive button label so options are predictable.
- Optional "Custom" item for occasional extra options; explanatory text may sit below the list.

## 10. Pull-down buttons
Source: https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons

- Menu closes and the app performs the chosen action. Use for commands/items directly related to the button's action (Add, Sort, Back with history).
- Mutually exclusive non-command choices -> pop-up button instead.
- "Avoid putting all of a view's actions in one pull-down button."
- "listing a minimum of three items can help the interaction feel worthwhile"; with one or two use buttons or toggles.
- Menu title only if it adds meaning. Destructive items: red text. Icons on items "when it provides value".

## 11. Segmented controls
Source: https://developer.apple.com/design/human-interface-guidelines/segmented-controls

- Single choice, or in macOS single or multiple choice; may also act as a group of action buttons without selection state.
- "Aim for no more than about five to seven segments in a wide interface."
- Equal-width segments; text or images, not a mix; "Use nouns or noun phrases for segment labels."
- macOS: introductory text or label below each segment may clarify; tooltip for each segment; "Use a tab view in the main window area — instead of a segmented control — for view switching"; segmented control is fine in a toolbar or inspector pane for view switching; spring loading supported.
- Don't mix actions and selection state within one control.

## 12. Tab views (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/tab-views

- "Avoid providing more than six tabs in a tab view."
- Tab labels: nouns or short noun phrases; "Use title-style capitalization for tab labels."
- "Avoid using a pop-up button to switch between tabs."
- Inset the tab view by leaving a window-body margin on all sides (amount not stated). Tabbed control sits on the top edge of the content area.

## 13. Toggles, checkboxes, radio buttons (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/toggles

- macOS supports switch, checkbox, and radio button styles. Use them in the window body, "not the window frame" (avoid toolbar/status bar).
- Switch: for settings to emphasize or a group of settings; mini switch for single row in a grouped form (matches control height). "In general, don't replace a checkbox with a switch."
- Checkbox: states on, off, mixed (dash); title on trailing side; use checkboxes (not switches) for a hierarchy of settings, aligned on the leading edge with indentation.
- Radio buttons: "Typically displayed in groups of two to five"; mutually exclusive; more than two exclusive options -> radio buttons; multiple selection -> checkboxes.

## 14. Text fields (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/text-fields

- Combo box when pairing text input with a list of choices. "Present a text field only when necessary."
- Placeholder text plus a separate label; secure text field for passwords; stack multiple fields vertically with consistent widths; validate (email on field exit); expansion tooltip for clipped text.

---
## 15. Menus (all types) and the menu bar
Sources: https://developer.apple.com/design/human-interface-guidelines/menus and https://developer.apple.com/design/human-interface-guidelines/the-menu-bar

### Labels and organization (menus)
- "To be consistent with platform experiences, use title-style capitalization... capitalizes every word except articles, coordinating conjunctions, and short prepositions, and capitalizes the last word in the label, regardless of the part of speech."
- Action labels: verb or verb phrase. "Remove articles like a, an, and the from menu-item labels."
- "Append an ellipsis to a menu item's label when the action requires more information before it can complete." The character is "…".
- Unavailable items appear dimmed; the menu itself stays available even if all items are unavailable.
- Icons: use sparingly; "provide icons for all menu items in a group, or none of them"; use system icons for common actions (Copy, Share, Delete).
- Order: most important/frequent first; group related items with separators; keep related commands in same group.
- Submenus: use sparingly; one level; "if a submenu contains more than about five items, consider creating a new menu"; submenu item stays available; "Prefer using a submenu to indenting menu items."
- Toggled items: changeable label (Show Map / Hide Map); add verbs if unclear (Turn HDR On); checkmark for attribute in effect; offer a Plain item to clear many toggled attributes.
- Context menus (https://developer.apple.com/design/human-interface-guidelines/context-menus): "Hide unavailable menu items, don't dim them" (macOS exception: Cut, Copy, Paste may appear unavailable); about three groups max; one submenu level; "Show keyboard shortcuts in your app's main menus, not in context menus."; macOS calls it a contextual menu.

### Menu bar structure (macOS)
- Order: YourAppName, File, Edit, Format, View, app-specific menus, Window, Help. Apple menu on the leading side; menu bar extras on trailing side.
- "Always show the same set of menu items... disable the action instead of hiding it."
- "Prefer short, one-word menu titles. If you need... more than one word... use title-style capitalization."
- Define custom shortcuts only when necessary; support standard shortcuts for standard items.
- App-specific menus go between View and Window, "from most to least general or commonly used".

### App menu (order)
About YourAppName (first, own group, separator after; short name of 16 characters or fewer; no version number) / Settings… / optional app-specific items (after Settings, same group) / Services / Hide YourAppName / Hide Others / Show All / Quit YourAppName (Option changes it to Quit and Keep Windows). App name shown in bold in the menu bar. Settings… "Use only for app-level settings. If you also offer document-specific settings, put them in the File menu."

### File menu (order)
New Item; Open; Open Recent (submenu, recognizable names not paths, most recent first, Clear Menu); Close (Option -> Close All; tab window: Close Tab, Option -> Close Other Tabs); Close File; Save (autosave periodically); Save All; Duplicate (Option -> Save As; "Prefer Duplicate to menu items like Save As, Export, Copy To, and Save To"); Rename…; Move To…; Export As…; Revert To; Page Setup…; Print….

### Edit menu (order)
Undo (append target, e.g. "Undo Typing"); Redo; Cut; Copy; Paste; Paste and Match Style; Delete ("Provide a Delete menu item instead of an Erase or Clear"); Select All; Find (submenu: Find, Find and Replace, Find Next, Find Previous, Use Selection for Find, Jump to Selection); Spelling and Grammar; Substitutions; Transformations; Speech; Start Dictation and Emoji & Symbols (system adds at bottom).

### Format menu
Font (Show Fonts, Bold, Italic, Underline, Bigger, Smaller, Show Colors, Copy Style, Paste Style); Text (Align Left, Align Center, Justify, Align Right, Writing Direction, Show Ruler, Copy Ruler, Paste Ruler). Omit if no formatted text.

### View menu
"Provide a View menu even if your app supports only a subset of the standard view functions." Items: Show/Hide Tab Bar; Show All Tabs/Exit Tab Overview; Show/Hide Toolbar; Customize Toolbar; Show/Hide Sidebar; Enter/Exit Full Screen. "Ensure that each show/hide item title reflects the current state."

### Window menu
"Provide a Window menu even if your app has only one window." Items: Minimize (Option -> Minimize All); Zoom (Option -> Zoom All; "Avoid using Zoom to enter or exit full-screen mode"); Show Previous Tab; Show Next Tab; Move Tab to New Window; Merge All Windows; Enter/Exit Full Screen (only if no View menu); Bring All to Front (Option -> Arrange in Front); open windows listed alphabetically (not panels).

### Help menu
Send YourAppName Feedback to Apple; YourAppName Help; additional items after a separator; keep few. Help Book format gets an automatic search field.

### Dynamic menu items
Modifier-key alternates (Control, Option, Shift, Command); "Require only a single modifier key"; never the only way to do a task; mainly menu bar menus.

### Menu bar extras
- "A menu bar extra exposes app-specific functionality using an icon that appears in the menu bar when your app is running, even when it's not the frontmost app." Located on opposite side from the app's menus.
- "The menu bar's height is 24 pt."
- "Consider using a symbol to represent your menu bar extra"; interface icons/symbols use black and clear colors; system recolors for light/dark menu bars and selected state.
- "Display a menu — not a popover — when people click your menu bar extra" unless functionality is too complex for a menu.
- "Let people — not your app — decide whether to put your menu bar extra in the menu bar" (typically a setting in the app's settings window; optionally offer during setup).
- "Avoid relying on the presence of menu bar extras": system hides them to make room for app menus.
- Also expose functionality elsewhere, e.g. a Dock menu.
- In full-screen mode the menu bar hides until the pointer reaches the top of the screen.

### Dock menus
Source: https://developer.apple.com/design/human-interface-guidelines/dock-menus
Label succinctly; "Make custom Dock menu items available in other places, too"; prefer high-value items (open/recent windows, common actions when no window is open). Dock icon sizes / badge rules: not stated on fetched pages.

---
## 16. Settings (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/settings

- Open with Command-Comma (","). Menu item "Settings…" in the App menu; "Avoid adding settings buttons to a window's toolbar." Document-level options go in the File menu.
- "Typically, a custom settings window contains a toolbar that includes buttons for switching between views — called panes."
- "Dim a settings window's minimize and maximize buttons."
- "use a noncustomizable toolbar that remains visible and always indicates the active toolbar button."
- "Update the window's title to reflect the currently visible pane. If your settings window doesn't have multiple panes, use the title App Name Settings."
- "Restore the most recently viewed pane."
- Defaults that serve most people; minimize number of settings; don't duplicate system-wide settings (accessibility, scrolling, authentication); keep task-specific options in the relevant view; put "general, infrequently changed settings" here.
- Help button location in Settings: lower-left or lower-right (Buttons page).
- Window sizes: not stated.

---
## 17. Windows (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/windows

- Window = frame + body area; frame can include window controls and a toolbar; rarely a bottom bar below body content.
- States: Main (one per app), Key (active; accepts input; one onscreen), Inactive. Key window uses color in close/minimize/zoom; inactive and non-key main windows use gray; inactive windows don't use vibrancy-from-underlying-content (appear subdued).
- Panels like Colors/Fonts become key only when the title bar or a text-input component is clicked.
- "Make sure custom windows use the system-defined appearances."
- "Avoid creating custom window UI... don't try to replicate the system-provided appearance."
- "Avoid putting critical information or actions in a bottom bar" (Finder status bar shows item count etc.).
- "Use the term window in user-facing content"; don't say "scene".
- "Avoid opening new windows as default behavior unless it makes sense"; offer new-window via command.
- Default/minimum macOS window size: not stated. (The 1280x720 pt default on this page is visionOS.)

## 18. Panels (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/panels

- Less prominent than main windows; use for inspector or quick controls. Inspector panel updates on selection change; an Info window that keeps its contents is a regular window.
- "Prefer simple adjustment controls in a panel" (sliders, steppers over text entry).
- Needs a title bar and short noun title ("Fonts", "Colors", "Inspector"); in menus refer by title without "panel" ("Show Fonts").
- Front-most when app active; hidden when app inactive; not in Window menu document list; "avoid making a panel's minimize button available."
- HUD panel: dark translucent; use only in media apps, when a standard panel would obscure essential content, and with no controls (except disclosure triangle). Keep small, sparing color, keep one panel style across modes.

## 19. Sheets (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/sheets

- macOS sheet is always modal: "a cardlike view with rounded corners that floats on top of its parent window. The parent window is dimmed."
- Users can still interact with other app windows before dismissing.
- "Present a sheet in a reasonable default size"; support resizing when useful.
- One sheet at a time; use a panel instead when repeated input and result observation needed (e.g. Find and Replace); for long flows use a new window or full-screen.
- Buttons: Cancel (or Close), Done, Back. "If you provide a Done button, always pair it with a Cancel button... or a Back button." "Avoid showing all three."
- macOS placement of these buttons: not stated.

## 20. Alerts (macOS)
Source: https://developer.apple.com/design/human-interface-guidelines/alerts

- Title, optional informative text, up to three buttons; macOS may include a text field, icon, accessory view, suppression checkbox, Help button.
- macOS shows app icon by default. "Use a caution symbol sparingly" (`exclamationmark.triangle`); not for save/empty trash.
- Title: situation, no "Error"; avoid wrapping beyond two lines. Informative text: "complete sentences, sentence-style capitalization, and appropriate punctuation." Button titles: "one- or two-word title", verbs ("View All", "Reply", "Ignore"), no ending punctuation. Capitalization style for button titles is a link in the feed whose text is blank (page examples are title case); not stated in readable text. "OK" only for purely informational alerts (avoid "Yes"/"No"). Always "Cancel" to cancel.
- Placement: default button on trailing side of a row (top of a stack); Cancel on leading side (bottom of stack).
- Destructive style only for a destructive action people didn't deliberately choose (e.g. Empty Trash gets no destructive style). With destructive action include Cancel; don't make Cancel the default.
- Cancel via Escape or Command-Period.
- "Avoid displaying alerts for common, undoable actions"; no alerts at app launch; don't use an alert merely for information.

---
## 21. Color
Source: https://developer.apple.com/design/human-interface-guidelines/color

- "Avoid hard-coding system color values"; use semantic APIs; don't redefine semantic meaning of dynamic colors.
- Supply light, dark, and increased contrast variants for custom colors; "Even if your app ships in a single appearance mode, provide both light and dark colors."
- Don't rely on color alone to convey information.
- Liquid Glass has no inherent color; apply color sparingly; for primary actions color the background, not symbols/text. Prefer monochromatic toolbars/tab bars over colorful backgrounds. Sidebars: Liquid Glass "appears more opaque in larger elements like sidebars".
- Accent color (macOS 11+): customizes buttons, selection highlighting, sidebar icons; applied only when System Settings accent is multicolor; a user-chosen non-multicolor accent replaces yours (except fixed-color sidebar icons).
- Wide color: Display P3, 16 bits per channel, PNG.
- macOS dynamic system colors (name -> use; AppKit API column empty in feed): Alternate selected control text color (text on selected list/table surface); Alternating content background colors (alternating rows/columns); Control accent (accent from System Settings); Control background color (large element like browser/table); Control color (control surface); Control text color; Current control tint; Unavailable control text color; Find highlight color; Grid color; Header text color; Highlight color (virtual light source); Keyboard focus indicator color (ring around focused control); Label color; Link color; Placeholder text color; Quaternary label color; Secondary label color; Selected content background color (key window/view); Selected control color; Selected control text color; Selected menu item text color; Selected text background color; Selected text color; Separator color; Shadow color; Tertiary label color; Text background color; Text color (document text); Under page background color; Unemphasized selected content background color (non-key window/view); Unemphasized selected text background color; Unemphasized selected text color; Window background color; Window frame text color.
- Numeric system color values (RGB/hex): not in the feed text.

## 22. Materials
Source: https://developer.apple.com/design/human-interface-guidelines/materials

- Two kinds: Liquid Glass (controls and navigation layer, floats above content) and standard materials (content layer).
- "Don't use Liquid Glass in the content layer"; use sparingly in custom controls.
- Variants: regular (blurs, adjusts luminosity; use with lots of text: alerts, sidebars, popovers) and clear (highly translucent; only over visually rich/media backgrounds). For clear glass over bright content, "consider adding a dark dimming layer of 35% opacity."
- macOS: standard materials with designated purposes plus vibrant versions; two blending modes: behind window and within window. Material names in the table are not exposed in the feed (images/codeVoice only).
- Choose materials "based on semantic meaning and recommended usage", not apparent color; use vibrant colors on top; thicker = more opaque/better contrast, thinner = more context.
- Vibrancy label levels: default, secondary, tertiary, quaternary; avoid quaternary on some materials (low contrast).

## 23. Dark Mode
Source: https://developer.apple.com/design/human-interface-guidelines/dark-mode

- "Avoid offering an app-specific appearance setting."
- Support Auto appearance switching while app runs.
- Contrast: "no lower than 4.5:1"; "strive for a contrast ratio of 7:1, especially in small text" for custom colors.
- "Soften the color of white backgrounds" in images.
- Use system label colors (primary through quaternary); use system views for text drawing; SF Symbols with dynamic colors.
- Background colors: base (dimmer) and elevated (brighter) sets; elevated for foreground interfaces such as popovers/sheets; prefer system background colors.
- macOS: graphite accent causes desktop tinting (window backgrounds pick up desktop color); "Include some transparency in custom component backgrounds when appropriate," only for components with visible background/bezel in a neutral state.
- Test with Increase Contrast and Reduce Transparency on.

## 24. Accessibility
Source: https://developer.apple.com/design/human-interface-guidelines/accessibility

- Text sizes (default/minimum): macOS 13 pt / 10 pt.
- Control sizes (default/minimum): macOS 28x28 pt / 20x20 pt (iOS 44x44/28x28; tvOS 66x66/56x56; visionOS 60x60/28x28; watchOS 44x44/28x28).
- Padding: "about 12 points of padding around elements that include a bezel"; "about 24 points of padding" around elements without a bezel.
- Contrast minimums (WCAG AA values): text up to 17 pts, all weights: 4.5:1; 18 pts, all weights: 3:1; any size Bold: 3:1. If not met by default, provide higher-contrast scheme under Increase Contrast.
- Larger text: "Ideally, give people the option to enlarge text by at least 200 percent"; macOS has no Dynamic Type (custom UI scaling would be needed).
- Full Keyboard Access: "Let people use the keyboard alone to navigate and interact"; avoid overriding system shortcuts.
- Reduce Motion: reduce automatic/repetitive animations (zooming, scaling, peripheral motion); tighten springs; track gestures; avoid depth/z-axis animation; replace x/y/z transitions with fades; avoid animating into/out of blurs.
- Don't rely on color alone; describe UI for VoiceOver; no autoplay without controls; honor Dim Flashing Lights.
- macOS-specific additional considerations: none stated.

## 25. Focus and selection
Source: https://developer.apple.com/design/human-interface-guidelines/focus-and-selection

- iPadOS and macOS show focus by a ring or highlight. Full keyboard access reaches every control, so "you only need to support focus for content elements like list items, text fields, and search fields, and not for controls like buttons, sliders, and toggles."
- "In iPadOS and macOS, the system draws focused list items using white text and a background highlight that matches the app's accent color, drawing unfocused items using the standard text color and a gray background highlight."
- "In general, use a focus ring for a text or search field, but use a highlight in a list or collection."
- Rely on system focus effects; "Avoid changing focus without people's interaction."
- Related color names: Keyboard focus indicator color; Selected content background color (key window) vs Unemphasized selected content background color (non-key window).

## 26. Keyboards
Source: https://developer.apple.com/design/human-interface-guidelines/keyboards

- "Support Full Keyboard Access when possible."
- "In general, don't repurpose standard keyboard shortcuts for custom actions."
- Custom shortcuts: "Define custom keyboard shortcuts for only the most frequently used app-specific commands." Modifiers: Command = main modifier; Shift = secondary complement; Option = sparingly for less-common/power features; Control = avoid. Modifier order when several: Control, Option, Shift, Command. Don't add Shift for the upper character of a two-character key (Help is Command-Question mark). Don't build an unrelated shortcut by adding a modifier to an existing one (e.g. Shift-Command-Z).
- Standard macOS shortcuts (selected, from table): Command-Comma open app settings; Command-Q quit; Command-H hide app; Option-Command-H hide others; Command-M minimize; Option-Command-M minimize all; Command-W close window; Shift-Command-W close file and its windows; Option-Command-W close all windows; Command-N new document; Command-O open; Command-S save; Shift-Command-S duplicate / Save As; Command-P print; Shift-Command-P page setup; Command-Z undo; Shift-Command-Z redo; Command-X cut; Command-C copy; Command-V paste; Option-Shift-Command-V paste and match style; Command-A select all; Shift-Command-A deselect all; Command-F find; Command-G find next; Shift-Command-G find previous; Command-E use selection for find; Command-J scroll to selection; Command-B bold; Command-I italic (also Info window in some apps; Option-Command-I inspector); Command-U underline; Command-T Fonts window; Shift-Command-C Colors window; Option-Command-T show/hide toolbar; Control-Command-F enter full screen; Command-Question mark open Help; Command-Period cancel operation; Esc cancel current action; Command-Grave accent next window of frontmost app; Shift-Command-Grave accent previous window; Command-Tab / Shift-Command-Tab app switch; Command-Space Spotlight; Control-F2 focus menu bar; Control-F3 focus Dock; Control-F5 focus toolbar; Control-F6 first/next panel; Control-F1 toggle full keyboard access; Command-F5 VoiceOver; Shift-Command-3/4 screenshots; Command-Hyphen decrease size; Shift-Command-Equal increase size; Command-Left/Right bracket left/right-align; Command-Pipe center-align.
- Not on Keyboards page: shortcuts for Show/Hide Sidebar, Toolbar item shortcuts other than Option-Command-T (not stated).

---
## 27. Searching
Source: https://developer.apple.com/design/human-interface-guidelines/searching

- Use a search field as the expected search surface; give search a primary position if important; one location for app-wide search (local filtering allowed); show scope via placeholder text or title; suggestions and recents (provide a way to clear history); Spotlight indexing for systemwide search; prefer system open/save views (built-in search). macOS-specific search field values: not stated on this page (separate page `search-fields`, not fetched).
- Toolbar page: search field sits on the trailing edge of the toolbar.

---
## 28. SF Symbols
Source: https://developer.apple.com/design/human-interface-guidelines/sf-symbols

- Rendering modes: Monochrome (one color), Hierarchical (one color, varying opacity per layer), Palette (two or more colors), Multicolor (intrinsic colors). Use system colors so symbols adapt to accessibility/appearance.
- Nine weights (ultralight to black), each matching a San Francisco weight; three scales: small, medium (default), large, defined relative to SF cap height.
- Variable color communicates change (capacity/strength), not depth; use Hierarchical for depth.
- Animations listed on the page include Bounce, Scale, Variable color, Replace, Wiggle, Breathe (Pulse is referenced), Draw On/Draw Off (SF Symbols 7+); the list may contain others not read. Gradient rendering in SF Symbols 7+.
- Symbol with enclosing shape improves legibility at small sizes. No macOS-specific additional considerations.

## 29. App icons (size facts only)
Source: https://developer.apple.com/design/human-interface-guidelines/app-icons

- iOS, iPadOS, macOS: square layout, 1024x1024 px, layered; system masks to rounded rectangle. Appearances: default, dark, clear light, clear dark, tinted light, tinted dark. Display P3 supported on macOS.
- Provide square, unmasked layers; keep primary content centered; no baked-in shadows/highlights/blurs; avoid soft/feathered edges on foreground layers. Icon Composer is the tool. Other macOS icon sizes (e.g. @1x/@2x sets): not stated.

## 30. Writing (capitalization)
Source: https://developer.apple.com/design/human-interface-guidelines/writing

- "Adopt capitalization rules that align with your app's style, then apply them consistently... Title case is generally considered formal, while sentence case is more casual. Choose a style for each UI element type and use it consistently."
- No macOS-specific writing considerations.
- Component-level rules found on other pages: title-style capitalization for menu item labels (Menus), menu bar menu titles with more than one word (The menu bar), tab labels (Tab views); sentence-style for alert informative text (Alerts). Alert button titles and column headings point to a capitalization link whose target is not in the feed. Title-style definition (Menus): capitalize every word except articles, coordinating conjunctions, and short prepositions; always capitalize the last word.
- Button label guidance: "it's almost always best to use a verb"; "Send" over "Let's do it!"; avoid "Click here".
- Settings labels: "labeling them as practically as possible"; describe what a setting does when on.
