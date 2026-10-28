// A native window with an NSSplitViewController sidebar and a unified toolbar, shown frontmost for
// 12 seconds so it can be captured as the key window. Run it through native-window.sh, which bundles
// it as an app (a bare script can't become the active app) and captures it in light and dark.
// Arguments: "light" for the light appearance; dark otherwise.

import AppKit

final class Side: NSViewController {
  override func loadView() {
    let outline = NSOutlineView(); outline.style = .sourceList; outline.headerView = nil
    let col = NSTableColumn(identifier: .init("c")); outline.addTableColumn(col)
    let scroll = NSScrollView(); scroll.documentView = outline; scroll.drawsBackground = false
    view = scroll
  }
}
final class Main: NSViewController {
  override func loadView() {
    let t = NSTextField(labelWithString: "Content"); let v = NSView(); v.addSubview(t)
    t.frame = NSRect(x: 20, y: 300, width: 200, height: 20); view = v
  }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
if CommandLine.arguments.contains("light") { app.appearance = NSAppearance(named: .aqua) } else { app.appearance = NSAppearance(named: .darkAqua) }
let split = NSSplitViewController()
split.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: Side()))
split.addSplitViewItem(NSSplitViewItem(viewController: Main()))
let win = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 800, height: 500),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
win.contentViewController = split
win.setContentSize(NSSize(width: 800, height: 500))
win.title = "NativeReference"
let tb = NSToolbar(identifier: "t"); win.toolbar = tb; win.toolbarStyle = .unified
win.makeKeyAndOrderFront(nil)
app.activate()
DispatchQueue.main.asyncAfter(deadline: .now() + 12) { app.terminate(nil) }
app.run()
