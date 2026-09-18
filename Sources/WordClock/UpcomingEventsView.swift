import AppKit

final class UpcomingEventsView: NSView {
    private let provider: CalendarEventProvider
    private let dismissPanel: () -> Void
    private let contentStack = NSStackView()
    private var heightConstraint: NSLayoutConstraint!

    override var intrinsicContentSize: NSSize {
        NSSize(width: 250, height: heightConstraint?.constant ?? 0)
    }

    init(provider: CalendarEventProvider, dismissPanel: @escaping () -> Void) {
        self.provider = provider
        self.dismissPanel = dismissPanel
        super.init(frame: .zero)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 0
        addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 250),
            heightConstraint,
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        provider.onChange = { [weak self] state in
            self?.render(state)
        }
        render(.loading)
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        provider.load()
    }

    private func render(_ state: CalendarEventState) {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard case .hidden = state else {
            isHidden = false
            addSeparator()
            addHeader()

            switch state {
            case .needsPermission:
                addActionRow("Allow Calendar Access…", action: #selector(requestAccess))
                setHeight(61)
            case .loading:
                addLoadingRow()
                setHeight(64)
            case .denied:
                addActionRow("Calendar access is off…", action: #selector(openPrivacySettings))
                setHeight(61)
            case .loaded(let events):
                if events.isEmpty {
                    addEmptyRow()
                    setHeight(64)
                } else {
                    for event in events {
                        let row = CalendarEventRowButton(event: event) { [weak self] selectedEvent in
                            self?.dismissPanel()
                            self?.provider.open(selectedEvent)
                        }
                        contentStack.addArrangedSubview(centeredContainer(row, height: 35))
                    }
                    setHeight(CGFloat(26 + events.count * 35))
                }
            case .hidden:
                break
            }
            return
        }

        isHidden = true
        setHeight(0)
    }

    private func setHeight(_ height: CGFloat) {
        heightConstraint.constant = height
        invalidateIntrinsicContentSize()
        superview?.invalidateIntrinsicContentSize()
        NotificationCenter.default.post(name: .wordClockPanelContentChanged, object: nil)
    }

    private func addSeparator() {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 250).isActive = true
        contentStack.addArrangedSubview(separator)
    }

    private func addHeader() {
        let label = NSTextField(labelWithString: "UP NEXT")
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        let container = NSView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 250),
            container.heightAnchor.constraint(equalToConstant: 25),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 1)
        ])
        contentStack.addArrangedSubview(container)
    }

    private func addActionRow(_ title: String, action: Selector) {
        let button = MenuRowButton(title: title, target: self, action: action)
        button.isBordered = false
        button.alignment = .left
        button.font = .systemFont(ofSize: NSFont.systemFontSize)
        button.focusRingType = .none
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 27).isActive = true
        let container = centeredContainer(button, height: 35)
        contentStack.addArrangedSubview(container)
    }

    private func addLoadingRow() {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        let label = NSTextField(labelWithString: "Loading events…")
        label.textColor = .secondaryLabelColor
        let row = NSStackView(views: [spinner, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        contentStack.addArrangedSubview(centeredContainer(row, height: 38))
    }

    private func addEmptyRow() {
        let label = NSTextField(labelWithString: "No upcoming events")
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        contentStack.addArrangedSubview(centeredContainer(label, height: 38))
    }

    private func centeredContainer(_ view: NSView, height: CGFloat, horizontalInset: CGFloat = 8) -> NSView {
        let container = NSView()
        container.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 250),
            container.heightAnchor.constraint(equalToConstant: height),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalInset),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalInset),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    @objc private func requestAccess() {
        provider.requestAccess()
    }

    @objc private func openPrivacySettings() {
        dismissPanel()
        provider.openCalendarPrivacySettings()
    }
}

private final class CalendarEventRowButton: NSButton {
    private let event: UpcomingCalendarEvent
    private let onOpen: (UpcomingCalendarEvent) -> Void
    private var isHovered = false
    private var trackingAreaReference: NSTrackingArea?

    override var wantsUpdateLayer: Bool { true }

    init(event: UpcomingCalendarEvent, onOpen: @escaping (UpcomingCalendarEvent) -> Void) {
        self.event = event
        self.onOpen = onOpen
        super.init(frame: .zero)

        title = ""
        isBordered = false
        focusRingType = .none
        target = self
        action = #selector(openEvent)
        wantsLayer = true
        layer?.cornerCurve = .continuous

        let time = NSTextField(labelWithString: "")
        time.attributedStringValue = NSAttributedString(
            string: timeDescription(for: event),
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        time.alignment = .left

        let eventTitle = NSTextField(labelWithString: event.title)
        eventTitle.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        eventTitle.lineBreakMode = .byTruncatingTail

        [time, eventTitle].forEach(addSubview)
        [time, eventTitle].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 27),
            time.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            time.centerYAnchor.constraint(equalTo: centerYAnchor),
            time.widthAnchor.constraint(equalToConstant: 58),
            eventTitle.leadingAnchor.constraint(equalTo: time.trailingAnchor, constant: 8),
            eventTitle.centerYAnchor.constraint(equalTo: centerYAnchor),
            eventTitle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])

        setAccessibilityLabel(event.joinURL == nil ? "Open \(event.title) in Calendar" : "Join \(event.title)")
        toolTip = event.joinURL == nil ? "Open in Calendar" : "Join meeting"
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        layer?.cornerRadius = min(9, bounds.height / 2)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { removeTrackingArea(trackingAreaReference) }
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateHoverAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateHoverAppearance()
    }

    override func updateLayer() {
        super.updateLayer()
        updateHoverAppearance()
    }

    private func updateHoverAppearance() {
        layer?.backgroundColor = isHovered
            ? NSColor.labelColor.withAlphaComponent(0.08).cgColor
            : NSColor.clear.cgColor
    }

    @objc private func openEvent() {
        onOpen(event)
    }

    private func timeDescription(for event: UpcomingCalendarEvent) -> String {
        if event.isAllDay { return "All day" }
        if Calendar.current.isDateInToday(event.startDate) {
            return event.startDate.formatted(Date.FormatStyle().hour().minute())
        }
        return event.startDate.formatted(Date.FormatStyle().weekday(.abbreviated).hour().minute())
    }
}
