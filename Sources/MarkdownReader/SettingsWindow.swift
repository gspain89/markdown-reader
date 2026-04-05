import Cocoa

// Native macOS settings window
final class SettingsWindowController: NSWindowController {

    private static var shared: SettingsWindowController?

    static func show() {
        if shared == nil {
            shared = SettingsWindowController()
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let contentView = buildUI()
        window.contentView = contentView
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Construction

    private func buildUI() -> NSView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 520))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // --- Appearance ---
        stack.addArrangedSubview(sectionLabel("Appearance"))
        stack.addArrangedSubview(makeThemePicker())
        stack.addArrangedSubview(makeFontPicker())
        stack.addArrangedSubview(makeFontSizeStepper())
        stack.addArrangedSubview(makeWidthPicker())
        stack.addArrangedSubview(spacer(12))

        // --- Behavior ---
        stack.addArrangedSubview(sectionLabel("Behavior"))
        stack.addArrangedSubview(makeCheckbox("Auto-reload on file change", key: "autoReload", default: true))
        stack.addArrangedSubview(makeCheckbox("Remember scroll position", key: "rememberScroll", default: true))
        stack.addArrangedSubview(makeCheckbox("Show table of contents", key: "showTOC", default: false))
        stack.addArrangedSubview(makeCheckbox("Show breadcrumb path", key: "showBreadcrumb", default: true))
        stack.addArrangedSubview(makeCheckbox("Show word count", key: "showWordCount", default: true))
        stack.addArrangedSubview(makeCheckbox("Show reading progress", key: "showProgress", default: true))
        stack.addArrangedSubview(spacer(12))

        // --- Content ---
        stack.addArrangedSubview(sectionLabel("Content"))
        stack.addArrangedSubview(makeCheckbox("Enable syntax highlighting", key: "enableHighlight", default: true))
        stack.addArrangedSubview(makeCheckbox("Enable Mermaid diagrams", key: "enableMermaid", default: true))
        stack.addArrangedSubview(makeCheckbox("Enable KaTeX math", key: "enableKatex", default: true))

        let clipView = NSClipView()
        clipView.documentView = stack
        scrollView.contentView = clipView
        scrollView.documentView = stack

        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        return scrollView
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            wrapper.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -2)
        ])
        return wrapper
    }

    private func spacer(_ height: CGFloat) -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    // --- Theme Picker ---
    private func makeThemePicker() -> NSView {
        let row = makeRow(label: "Theme")
        let seg = NSSegmentedControl(labels: ["Light", "Dark", "Auto"], trackingMode: .selectOne, target: nil, action: nil)
        let current = Settings.shared.theme
        seg.selectedSegment = current == "light" ? 0 : current == "dark" ? 1 : 2
        seg.target = self
        seg.action = #selector(themeChanged(_:))
        row.addArrangedSubview(seg)
        return row
    }

    @objc private func themeChanged(_ sender: NSSegmentedControl) {
        let values = ["light", "dark", "auto"]
        Settings.shared.theme = values[sender.selectedSegment]
    }

    // --- Font Picker ---
    private func makeFontPicker() -> NSView {
        let row = makeRow(label: "Font")
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: ["Default (Serif)", "Sans", "System", "Monospace"])
        let families = ["serif", "sans", "system", "mono"]
        if let idx = families.firstIndex(of: Settings.shared.fontFamily) {
            popup.selectItem(at: idx)
        }
        popup.target = self
        popup.action = #selector(fontChanged(_:))
        popup.tag = 100
        row.addArrangedSubview(popup)
        return row
    }

    @objc private func fontChanged(_ sender: NSPopUpButton) {
        let families = ["serif", "sans", "system", "mono"]
        Settings.shared.fontFamily = families[sender.indexOfSelectedItem]
    }

    // --- Font Size ---
    private func makeFontSizeStepper() -> NSView {
        let row = makeRow(label: "Font size")
        let label = NSTextField(labelWithString: "\(Settings.shared.fontSize) px")
        label.tag = 200
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let stepper = NSStepper()
        stepper.minValue = 12
        stepper.maxValue = 28
        stepper.integerValue = Settings.shared.fontSize
        stepper.increment = 1
        stepper.target = self
        stepper.action = #selector(fontSizeChanged(_:))
        stepper.tag = 201

        let sub = NSStackView(views: [label, stepper])
        sub.spacing = 6
        row.addArrangedSubview(sub)
        return row
    }

    @objc private func fontSizeChanged(_ sender: NSStepper) {
        Settings.shared.fontSize = sender.integerValue
        // Update label
        if let label = sender.superview?.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 200 }) {
            label.stringValue = "\(sender.integerValue) px"
        }
    }

    // --- Width Picker ---
    private func makeWidthPicker() -> NSView {
        let row = makeRow(label: "Content width")
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: ["Narrow (600 px)", "Standard (720 px)", "Wide (900 px)", "Full"])
        let widths = ["narrow", "standard", "wide", "full"]
        if let idx = widths.firstIndex(of: Settings.shared.contentWidth) {
            popup.selectItem(at: idx)
        }
        popup.target = self
        popup.action = #selector(widthChanged(_:))
        row.addArrangedSubview(popup)
        return row
    }

    @objc private func widthChanged(_ sender: NSPopUpButton) {
        let widths = ["narrow", "standard", "wide", "full"]
        Settings.shared.contentWidth = widths[sender.indexOfSelectedItem]
    }

    // --- Checkbox ---
    private func makeCheckbox(_ title: String, key: String, default defaultValue: Bool) -> NSView {
        let btn = NSButton(checkboxWithTitle: title, target: self, action: #selector(checkboxChanged(_:)))
        btn.state = (UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue) ? .on : .off
        btn.identifier = NSUserInterfaceItemIdentifier(key)
        return btn
    }

    @objc private func checkboxChanged(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        let value = sender.state == .on
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: Settings.changedNotification, object: nil)
    }

    // --- Row helper ---
    private func makeRow(label text: String) -> NSStackView {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let row = NSStackView(views: [label])
        row.spacing = 8
        row.alignment = .centerY
        return row
    }
}
