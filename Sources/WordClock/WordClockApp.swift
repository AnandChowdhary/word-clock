import AppKit

extension Notification.Name {
    static let wordClockPreferencesChanged = Notification.Name("WordClockPreferencesChanged")
    static let wordClockPanelContentChanged = Notification.Name("WordClockPanelContentChanged")
}

@main
enum WordClockMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: StatusPanel?
    private var calendarViewController: CalendarPopoverViewController?
    private var timer: Timer?
    private var preferencesWindowController: PreferencesWindowController?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "useLowercase": true,
            "roundToFive": true,
            "showWeekday": false,
            "showWeekNumbers": true,
            "showUpcomingEvents": true,
            "includeAllDayEvents": true,
            "onlyEventsWithMultipleParticipants": false,
            "upcomingEventCount": 3,
            "eventLookAheadDays": 14
        ])

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let calendarViewController = CalendarPopoverViewController(
            showPreferences: { [weak self] in self?.showPreferences() },
            dismissPanel: { [weak self] in self?.hidePanel() }
        )
        self.calendarViewController = calendarViewController
        panel = StatusPanel(contentViewController: calendarViewController)
        installDismissMonitors()

        updateStatusTitle()
        timer = Timer.scheduledTimer(
            timeInterval: 30,
            target: self,
            selector: #selector(updateStatusTitle),
            userInfo: nil,
            repeats: true
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusTitle),
            name: .wordClockPreferencesChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelContentChanged),
            name: .wordClockPanelContentChanged,
            object: nil
        )
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        positionPanel(refresh: true)
    }

    private func positionPanel(refresh: Bool) {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let panel else { return }

        if refresh {
            calendarViewController?.refresh()
        }
        calendarViewController?.view.layoutSubtreeIfNeeded()
        panel.setContentSize(calendarViewController?.view.fittingSize ?? panel.frame.size)

        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let unclampedX = buttonRect.midX - panel.frame.width / 2
        let x = min(max(unclampedX, screenFrame.minX + 6), screenFrame.maxX - panel.frame.width - 6)
        let y = buttonRect.minY - panel.frame.height - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
        button.highlight(true)
    }

    @objc private func panelContentChanged() {
        guard panel?.isVisible == true else { return }
        positionPanel(refresh: false)
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        statusItem.button?.highlight(false)
    }

    private func installDismissMonitors() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.hidePanel()
                return nil
            }
            if !self.isPointerInsidePanelOrStatusItem() {
                self.hidePanel()
            }
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, !self.isPointerInsidePanelOrStatusItem() else { return }
                self.hidePanel()
            }
        }
    }

    private func isPointerInsidePanelOrStatusItem() -> Bool {
        let pointer = NSEvent.mouseLocation
        if panel?.frame.contains(pointer) == true { return true }
        guard let button = statusItem.button, let window = button.window else { return false }
        let buttonRect = window.convertToScreen(button.convert(button.bounds, to: nil))
        return buttonRect.contains(pointer)
    }

    @objc private func updateStatusTitle() {
        let defaults = UserDefaults.standard
        let now = Date.now
        let spokenTime = WordTimeFormatter.phrase(
            for: now,
            lowercase: defaults.bool(forKey: "useLowercase"),
            roundToFive: defaults.bool(forKey: "roundToFive")
        )
        let title = defaults.bool(forKey: "showWeekday")
            ? "\(now.formatted(Date.FormatStyle().weekday(.abbreviated))), \(spokenTime)"
            : spokenTime
        statusItem.button?.title = title
        statusItem.button?.toolTip = "Current time: \(WordTimeFormatter.phrase(for: now, lowercase: false, roundToFive: defaults.bool(forKey: "roundToFive")))"
        statusItem.button?.setAccessibilityLabel("Current time: \(title)")
        if panel?.isVisible == true {
            calendarViewController?.refresh()
        }
    }

    private func showPreferences() {
        hidePanel()
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.center()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

final class StatusPanel: NSPanel {
    init(contentViewController: NSViewController) {
        contentViewController.loadView()
        contentViewController.view.layoutSubtreeIfNeeded()
        let contentSize = contentViewController.view.fittingSize

        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        animationBehavior = .utilityWindow
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]

        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 14
        contentView?.layer?.cornerCurve = .continuous
        contentView?.layer?.masksToBounds = true
        contentView?.layer?.borderWidth = 0
        contentView?.layer?.borderColor = nil
    }

    override var canBecomeKey: Bool { true }
}

final class CalendarPopoverViewController: NSViewController {
    private static let popoverWidth: CGFloat = 250
    private let timeLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let monthView = CalendarMonthView()
    private let eventProvider = CalendarEventProvider()
    private let showPreferences: () -> Void
    private let dismissPanel: () -> Void
    private lazy var upcomingEventsView = UpcomingEventsView(
        provider: eventProvider,
        dismissPanel: dismissPanel
    )

    init(showPreferences: @escaping () -> Void, dismissPanel: @escaping () -> Void) {
        self.showPreferences = showPreferences
        self.dismissPanel = dismissPanel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root: NSView
        let contentHost: NSView

        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 14
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = true
            }
            let host = NSView()
            glass.contentView = host
            root = glass
            contentHost = host
        } else {
            let material = NSVisualEffectView()
            material.material = .popover
            material.blendingMode = .behindWindow
            material.state = .active
            root = material
            contentHost = material
        }

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        dateLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = .secondaryLabelColor

        let header = NSStackView(views: [timeLabel, dateLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 4
        header.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 10, right: 16)

        let calendarContainer = NSView()
        calendarContainer.addSubview(monthView)
        monthView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            monthView.centerXAnchor.constraint(equalTo: calendarContainer.centerXAnchor),
            monthView.topAnchor.constraint(equalTo: calendarContainer.topAnchor, constant: 10),
            monthView.bottomAnchor.constraint(equalTo: calendarContainer.bottomAnchor, constant: -10)
        ])

        let preferencesButton = rowButton(title: "Preferences…", action: #selector(openPreferences))
        let quitButton = rowButton(title: "Quit", action: #selector(quit))
        quitButton.keyEquivalent = "q"
        quitButton.keyEquivalentModifierMask = .command

        let stack = NSStackView(views: [
            header,
            separator(),
            calendarContainer,
            upcomingEventsView,
            separator(),
            buttonContainer(preferencesButton),
            separator(),
            buttonContainer(quitButton)
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        contentHost.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: Self.popoverWidth),
            stack.topAnchor.constraint(equalTo: contentHost.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            calendarContainer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        view = root
        refresh()
    }

    func refresh() {
        guard isViewLoaded else { return }
        let now = Date.now
        timeLabel.stringValue = now.formatted(date: .omitted, time: .shortened)
        dateLabel.stringValue = now.formatted(Date.FormatStyle().weekday(.wide).month(.wide).day().year())
        monthView.setShowsWeekNumbers(UserDefaults.standard.bool(forKey: "showWeekNumbers"))
        monthView.showToday()
        upcomingEventsView.refresh()
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: Self.popoverWidth).isActive = true
        return box
    }

    private func rowButton(title: String, action: Selector) -> NSButton {
        let button = MenuRowButton(title: title, target: self, action: action)
        button.isBordered = false
        button.alignment = .left
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        button.contentTintColor = .labelColor
        button.focusRingType = .none
        return button
    }

    private func buttonContainer(_ button: NSButton) -> NSView {
        let container = NSView()
        container.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 35),
            container.widthAnchor.constraint(equalToConstant: Self.popoverWidth),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            button.heightAnchor.constraint(equalToConstant: 27),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    @objc private func openPreferences() { showPreferences() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
