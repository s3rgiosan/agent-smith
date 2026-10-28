// A native reference window: NSSplitViewController with a source-list sidebar, a unified toolbar
// with standard items, and a content pane. native-window.sh bundles it as an app, because a bare
// script can't become the active app, then captures it in light and dark.
//
// Usage (through native-window.sh): NativeReference <light|dark> <work-dir>
// Once the window is key, writes <work-dir>/native-window-<mode>-cached.png (a cacheDisplay render
// of the window's theme frame) and then <work-dir>/ready-<mode> with the line
// "<window-number> <window-width-pt> <close-x-pt> <close-y-pt-from-top> <is-key 0|1>".
// The script terminates the app after capturing; the app quits by itself after 120 seconds.

import AppKit

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dark"
let workDir = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ".")

final class Sidebar: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    let header = "Library"
    let rows: [(String, String)] = [("Inbox", "tray"), ("Drafts", "doc"), ("Sent", "paperplane"), ("Archive", "archivebox")]
    let outline = NSOutlineView()

    override func loadView() {
        outline.style = .sourceList
        outline.headerView = nil
        outline.floatsGroupRows = false
        let column = NSTableColumn(identifier: .init("c"))
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.dataSource = self
        outline.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.drawsBackground = false
        view = scroll
        outline.reloadData()
        outline.expandItem(header)
        outline.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? 1 : rows.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        item == nil ? header : rows[index].0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? String) == header
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as? String) == header
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? String) != header
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let title = item as! String
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        cell.textField = label
        if title == header {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }
        let symbol = rows.first { $0.0 == title }!.1
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!)
        icon.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)
        cell.imageView = icon
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}

final class Content: NSViewController {
    override func loadView() {
        let title = NSTextField(labelWithString: "Drafts")
        title.font = .systemFont(ofSize: 22, weight: .bold)
        let lines = ["Quarterly report", "Release notes for version 2.4", "Team offsite agenda"].map { text -> NSTextField in
            NSTextField(labelWithString: text)
        }
        let meta = NSTextField(labelWithString: "3 items, edited today")
        meta.font = .systemFont(ofSize: 12)
        meta.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title] + lines + [meta])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 20),
        ])
        view = container
    }
}

extension NSToolbarItem.Identifier {
    static let compose = Self("compose")
    static let sort = Self("sort")
    static let search = Self("search")
}

final class ToolbarDelegate: NSObject, NSToolbarDelegate {
    @objc func noop(_ sender: Any?) {}

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, .compose, .sort, .search]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case .compose:
            let item = NSToolbarItem(itemIdentifier: id)
            item.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New Draft")
            item.label = "New Draft"
            item.toolTip = "New Draft"
            item.isBordered = true
            item.target = self
            item.action = #selector(noop(_:))
            return item
        case .sort:
            let item = NSMenuToolbarItem(itemIdentifier: id)
            item.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Sort")
            item.label = "Sort"
            let menu = NSMenu()
            for title in ["Name", "Date Modified", "Size"] {
                let entry = NSMenuItem(title: title, action: #selector(noop(_:)), keyEquivalent: "")
                entry.target = self
                menu.addItem(entry)
            }
            item.menu = menu
            return item
        case .search:
            let item = NSSearchToolbarItem(itemIdentifier: id)
            item.searchField.placeholderString = "Search Drafts"
            return item
        default:
            return nil
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)

let split = NSSplitViewController()
split.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: Sidebar()))
split.addSplitViewItem(NSSplitViewItem(viewController: Content()))

let win = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 900, height: 560),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
win.contentViewController = split
win.setContentSize(NSSize(width: 900, height: 560))
win.title = "Drafts"
let toolbarDelegate = ToolbarDelegate()
let toolbar = NSToolbar(identifier: "main")
toolbar.delegate = toolbarDelegate
toolbar.displayMode = .iconOnly
win.toolbar = toolbar
win.toolbarStyle = .unified
win.center()

// Writes the cached render, then the ready file the script polls for.
func reportReady() {
    let frameView = win.contentView!.superview!
    if let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) {
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: workDir.appendingPathComponent("native-window-\(mode)-cached.png"))
    }
    let close = win.standardWindowButton(.closeButton)!
    let center = close.convert(NSPoint(x: close.bounds.midX, y: close.bounds.midY), to: nil)
    let line = String(format: "%d %.1f %.1f %.1f %d\n", win.windowNumber, win.frame.width, center.x, win.frame.height - center.y, win.isKeyWindow ? 1 : 0)
    try? line.write(to: workDir.appendingPathComponent("ready-\(mode)"), atomically: true, encoding: .utf8)
}

// Activates the app and makes the window key every 0.25 seconds while the app runs, so the window
// stays key until the script captures it. Reports ready once the window is key, or after 15 seconds.
// Cooperative NSApp.activate() can leave the app inactive when launched from a terminal.
var reported = false
func keepKey(attempt: Int = 0) {
    if !NSApp.isActive || !win.isKeyWindow {
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
    if !reported && ((NSApp.isActive && win.isKeyWindow && attempt >= 4) || attempt >= 60) {
        reported = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { reportReady() }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { keepKey(attempt: attempt + 1) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        keepKey()
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { NSApp.terminate(nil) }
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
