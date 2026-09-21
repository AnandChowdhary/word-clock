import AppKit
import ServiceManagement
import Sparkle

final class PreferencesWindowController: NSWindowController {
    init(updater: SPUUpdater) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab(label: "General", symbol: "gearshape", controller: GeneralSettingsViewController(updater: updater)))
        tabs.addTabViewItem(Self.tab(label: "Calendar", symbol: "calendar", controller: CalendarSettingsViewController()))
        tabs.addTabViewItem(Self.tab(label: "Appearance", symbol: "paintbrush", controller: AppearanceSettingsViewController()))
        tabs.addTabViewItem(Self.tab(label: "About", symbol: "info.circle", controller: AboutViewController()))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Word Clock Settings"
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.contentViewController = tabs
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    private static func tab(label: String, symbol: String, controller: NSViewController) -> NSTabViewItem {
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

private class SettingsPaneViewController: NSViewController {
    let defaults = UserDefaults.standard

    func switchRow(_ title: String, control: NSSwitch) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        let row = NSStackView(views: [label, NSView(), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return row
    }

    func popUpRow(_ title: String, control: NSPopUpButton) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        let row = NSStackView(views: [label, NSView(), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true
        control.widthAnchor.constraint(equalToConstant: 118).isActive = true
        return row
    }

    func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    func paneView(rows: [NSView]) -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 300))
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        root.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28)
        ])
        return root
    }

    func save(_ value: Bool, key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .wordClockPreferencesChanged, object: nil)
    }

    func save(_ value: Int, key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .wordClockPreferencesChanged, object: nil)
    }
}

private final class GeneralSettingsViewController: SettingsPaneViewController {
    private let updater: SPUUpdater
    private let weekdaySwitch = NSSwitch()
    private let roundingSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()
    private let updateCheckSwitch = NSSwitch()
    private let automaticDownloadSwitch = NSSwitch()

    init(updater: SPUUpdater) {
        self.updater = updater
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        weekdaySwitch.state = defaults.bool(forKey: "showWeekday") ? .on : .off
        roundingSwitch.state = defaults.bool(forKey: "roundToFive") ? .on : .off
        loginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        updateCheckSwitch.state = updater.automaticallyChecksForUpdates ? .on : .off
        automaticDownloadSwitch.state = updater.automaticallyDownloadsUpdates ? .on : .off

        weekdaySwitch.target = self
        weekdaySwitch.action = #selector(weekdayChanged)
        roundingSwitch.target = self
        roundingSwitch.action = #selector(roundingChanged)
        loginSwitch.target = self
        loginSwitch.action = #selector(loginChanged)
        updateCheckSwitch.target = self
        updateCheckSwitch.action = #selector(updateCheckChanged)
        automaticDownloadSwitch.target = self
        automaticDownloadSwitch.action = #selector(automaticDownloadChanged)

        let menuBarRows = NSStackView(views: [
            switchRow("Show weekday in menu bar", control: weekdaySwitch),
            switchRow("Round time to nearest five minutes", control: roundingSwitch)
        ])
        menuBarRows.orientation = .vertical
        menuBarRows.alignment = .leading
        menuBarRows.spacing = 4
        menuBarRows.widthAnchor.constraint(equalToConstant: 384).isActive = true

        let systemRows = NSStackView(views: [switchRow("Start Word Clock at login", control: loginSwitch)])
        systemRows.orientation = .vertical
        systemRows.alignment = .leading
        systemRows.widthAnchor.constraint(equalToConstant: 384).isActive = true

        let updateRows = NSStackView(views: [
            switchRow("Automatically check for updates", control: updateCheckSwitch),
            switchRow("Download and install updates automatically", control: automaticDownloadSwitch)
        ])
        updateRows.orientation = .vertical
        updateRows.alignment = .leading
        updateRows.spacing = 4
        updateRows.widthAnchor.constraint(equalToConstant: 384).isActive = true

        view = paneView(rows: [
            sectionLabel("MENU BAR"), menuBarRows,
            sectionLabel("SYSTEM"), systemRows,
            sectionLabel("UPDATES"), updateRows
        ])
        updateUpdateControls()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func weekdayChanged() {
        save(weekdaySwitch.state == .on, key: "showWeekday")
    }

    @objc private func roundingChanged() {
        save(roundingSwitch.state == .on, key: "roundToFive")
    }

    @objc private func loginChanged() {
        do {
            if loginSwitch.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Couldn’t update Login Items"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func updateCheckChanged() {
        updater.automaticallyChecksForUpdates = updateCheckSwitch.state == .on
        updateUpdateControls()
    }

    @objc private func automaticDownloadChanged() {
        updater.automaticallyDownloadsUpdates = automaticDownloadSwitch.state == .on
    }

    private func updateUpdateControls() {
        automaticDownloadSwitch.isEnabled = updateCheckSwitch.state == .on
    }
}

private final class CalendarSettingsViewController: SettingsPaneViewController {
    private let showEventsSwitch = NSSwitch()
    private let allDaySwitch = NSSwitch()
    private let multipleParticipantsSwitch = NSSwitch()
    private let weekNumbersSwitch = NSSwitch()
    private let eventCountPopUp = NSPopUpButton()
    private let lookAheadPopUp = NSPopUpButton()
    private let lookAheadDays = [1, 3, 7, 14, 30]

    override func loadView() {
        showEventsSwitch.state = defaults.bool(forKey: "showUpcomingEvents") ? .on : .off
        allDaySwitch.state = defaults.bool(forKey: "includeAllDayEvents") ? .on : .off
        multipleParticipantsSwitch.state = defaults.bool(forKey: "onlyEventsWithMultipleParticipants") ? .on : .off
        weekNumbersSwitch.state = defaults.bool(forKey: "showWeekNumbers") ? .on : .off

        eventCountPopUp.addItems(withTitles: ["1 event", "2 events", "3 events", "4 events", "5 events"])
        let eventCount = min(max(defaults.integer(forKey: "upcomingEventCount"), 1), 5)
        eventCountPopUp.selectItem(at: eventCount - 1)

        lookAheadPopUp.addItems(withTitles: ["1 day", "3 days", "1 week", "2 weeks", "1 month"])
        let storedLookAhead = defaults.integer(forKey: "eventLookAheadDays")
        lookAheadPopUp.selectItem(at: lookAheadDays.firstIndex(of: storedLookAhead) ?? 3)

        showEventsSwitch.target = self
        showEventsSwitch.action = #selector(showEventsChanged)
        allDaySwitch.target = self
        allDaySwitch.action = #selector(allDayChanged)
        multipleParticipantsSwitch.target = self
        multipleParticipantsSwitch.action = #selector(multipleParticipantsChanged)
        weekNumbersSwitch.target = self
        weekNumbersSwitch.action = #selector(weekNumbersChanged)
        eventCountPopUp.target = self
        eventCountPopUp.action = #selector(eventCountChanged)
        lookAheadPopUp.target = self
        lookAheadPopUp.action = #selector(lookAheadChanged)

        let upNextRows = NSStackView(views: [
            switchRow("Show upcoming events", control: showEventsSwitch),
            switchRow("Include all-day events", control: allDaySwitch),
            switchRow("Only events with 2+ participants", control: multipleParticipantsSwitch),
            popUpRow("Number of events", control: eventCountPopUp),
            popUpRow("Look ahead", control: lookAheadPopUp)
        ])
        upNextRows.orientation = .vertical
        upNextRows.alignment = .leading
        upNextRows.spacing = 2
        upNextRows.widthAnchor.constraint(equalToConstant: 384).isActive = true

        let calendarRows = NSStackView(views: [
            switchRow("Show week numbers", control: weekNumbersSwitch)
        ])
        calendarRows.orientation = .vertical
        calendarRows.alignment = .leading
        calendarRows.widthAnchor.constraint(equalToConstant: 384).isActive = true

        view = paneView(rows: [
            sectionLabel("UP NEXT"), upNextRows,
            sectionLabel("CALENDAR"), calendarRows
        ])
        updateEnabledState()
    }

    @objc private func showEventsChanged() {
        save(showEventsSwitch.state == .on, key: "showUpcomingEvents")
        updateEnabledState()
    }

    @objc private func allDayChanged() {
        save(allDaySwitch.state == .on, key: "includeAllDayEvents")
    }

    @objc private func multipleParticipantsChanged() {
        save(multipleParticipantsSwitch.state == .on, key: "onlyEventsWithMultipleParticipants")
    }

    @objc private func weekNumbersChanged() {
        save(weekNumbersSwitch.state == .on, key: "showWeekNumbers")
    }

    @objc private func eventCountChanged() {
        save(eventCountPopUp.indexOfSelectedItem + 1, key: "upcomingEventCount")
    }

    @objc private func lookAheadChanged() {
        let index = min(max(lookAheadPopUp.indexOfSelectedItem, 0), lookAheadDays.count - 1)
        save(lookAheadDays[index], key: "eventLookAheadDays")
    }

    private func updateEnabledState() {
        let enabled = showEventsSwitch.state == .on
        allDaySwitch.isEnabled = enabled
        multipleParticipantsSwitch.isEnabled = enabled
        eventCountPopUp.isEnabled = enabled
        lookAheadPopUp.isEnabled = enabled
    }
}

private final class AppearanceSettingsViewController: SettingsPaneViewController {
    private let lowercaseSwitch = NSSwitch()

    override func loadView() {
        lowercaseSwitch.state = defaults.bool(forKey: "useLowercase") ? .on : .off
        lowercaseSwitch.target = self
        lowercaseSwitch.action = #selector(lowercaseChanged)

        let rows = NSStackView(views: [
            switchRow("Use lowercase time wording", control: lowercaseSwitch)
        ])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 4
        rows.widthAnchor.constraint(equalToConstant: 384).isActive = true

        let sampleTitle = sectionLabel("PREVIEW")
        let sample = NSTextField(labelWithString: "ten past four")
        sample.font = .systemFont(ofSize: 18, weight: .regular)
        sample.textColor = .secondaryLabelColor

        view = paneView(rows: [sectionLabel("APPEARANCE"), rows, sampleTitle, sample])
    }

    @objc private func lowercaseChanged() {
        save(lowercaseSwitch.state == .on, key: "useLowercase")
    }

}

private final class AboutViewController: NSViewController {
    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 230))
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64)
        ])

        let title = NSTextField(labelWithString: "Word Clock")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let detail = NSTextField(labelWithString: "Version \(version)\nTime, the way you would say it.")
        detail.alignment = .center
        detail.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [icon, title, detail])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        root.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor)
        ])
        view = root
    }
}
