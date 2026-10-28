// Renders real AppKit controls in light and dark appearance, as a visual reference for the
// webview's controls. Renders offscreen; it captures no screen content.
//
// Usage: swift scripts/appkit-reference.swift <out-dir>
// Writes <out-dir>/ak-<light|dark>-<control>.png for push, default, popup, pulldown, field, search,
// segmented, switch, check-on, check-off, check-mixed, radio-on, radio-off, toolbar-button and
// plus-minus. Creates <out-dir> when it is missing.

import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func controls() -> [(String, NSView)] {
    let push = NSButton(title: "Replace Token…", target: nil, action: nil)
    push.bezelStyle = .push

    let defaultButton = NSButton(title: "Add Account", target: nil, action: nil)
    defaultButton.bezelStyle = .push
    defaultButton.keyEquivalent = "\r"

    let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
    popUp.addItems(withTitles: ["Work", "Personal", "Corp GitLab"])

    // A pull-down shows its first item as the fixed title.
    let pullDown = NSPopUpButton(frame: .zero, pullsDown: true)
    pullDown.addItems(withTitles: ["Sort By", "Name", "Date Modified", "Size"])

    let field = NSTextField(string: "")
    field.placeholderString = "github_pat_…"
    field.frame.size.width = 220

    let search = NSSearchField(string: "")
    search.placeholderString = "Search"
    search.frame.size.width = 220

    let segmented = NSSegmentedControl(labels: ["GitHub", "GitLab"], trackingMode: .selectOne, target: nil, action: nil)
    segmented.selectedSegment = 0

    let toggle = NSSwitch()
    toggle.state = .on

    let checkOn = NSButton(checkboxWithTitle: "billing-api", target: nil, action: nil)
    checkOn.state = .on
    let checkOff = NSButton(checkboxWithTitle: "sandbox", target: nil, action: nil)
    let checkMixed = NSButton(checkboxWithTitle: "acme", target: nil, action: nil)
    checkMixed.allowsMixedState = true
    checkMixed.state = .mixed

    let radioOn = NSButton(radioButtonWithTitle: "Every Hour", target: nil, action: nil)
    radioOn.state = .on
    let radioOff = NSButton(radioButtonWithTitle: "Every Day", target: nil, action: nil)
    radioOff.state = .off

    let toolbarStyle = NSButton(title: "", image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)!, target: nil, action: nil)
    toolbarStyle.bezelStyle = .toolbar

    let plusMinus = NSSegmentedControl(images: [NSImage(systemSymbolName: "plus", accessibilityDescription: nil)!, NSImage(systemSymbolName: "minus", accessibilityDescription: nil)!], trackingMode: .momentary, target: nil, action: nil)
    plusMinus.segmentStyle = .smallSquare

    return [
        ("push", push), ("default", defaultButton), ("popup", popUp), ("pulldown", pullDown),
        ("field", field), ("search", search), ("segmented", segmented), ("switch", toggle),
        ("check-on", checkOn), ("check-off", checkOff), ("check-mixed", checkMixed),
        ("radio-on", radioOn), ("radio-off", radioOff),
        ("toolbar-button", toolbarStyle), ("plus-minus", plusMinus),
    ]
}

func render(dark: Bool) {
    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
    for (name, view) in controls() {
        (view as? NSControl)?.sizeToFit()
        if name == "field" || name == "search" { view.frame.size.width = 220 }
        let size = view.fittingSize.width > 0 ? view.fittingSize : view.frame.size
        let pad: CGFloat = 8
        let host = NSView(frame: NSRect(x: 0, y: 0, width: max(size.width, view.frame.width) + pad * 2, height: max(size.height, view.frame.height) + pad * 2))
        host.wantsLayer = true
        appearance.performAsCurrentDrawingAppearance {
            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        view.frame = NSRect(x: pad, y: pad, width: host.frame.width - pad * 2, height: host.frame.height - pad * 2)
        host.addSubview(view)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        let png = rep.representation(using: .png, properties: [:])!
        try! png.write(to: outDir.appendingPathComponent("ak-\(dark ? "dark" : "light")-\(name).png"))
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
render(dark: false)
render(dark: true)
print("Wrote \(outDir.path)/ak-<light|dark>-<control>.png")
