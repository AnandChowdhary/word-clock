import AppKit

final class CalendarMonthView: NSView {
    private var calendar = Calendar.autoupdatingCurrent
    private var displayedMonth: Date
    private var selectedDate = Date.now
    private let monthLabel = NSTextField(labelWithString: "")
    private var dayButtons: [CalendarDayButton] = []
    private var weekLabels: [NSTextField] = []
    private var weekColumn: NSStackView!
    private var weekDivider: NSBox!
    var onSelectDate: ((Date) -> Void)?

    override var intrinsicContentSize: NSSize {
        NSSize(width: 218, height: 190)
    }

    override init(frame frameRect: NSRect) {
        displayedMonth = Calendar.autoupdatingCurrent.dateInterval(of: .month, for: .now)?.start ?? .now
        super.init(frame: frameRect)
        buildView()
        updateMonth()
    }

    required init?(coder: NSCoder) { nil }

    func showToday() {
        selectedDate = .now
        displayedMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        updateMonth()
    }

    func refreshToday() {
        if calendar.isDate(selectedDate, inSameDayAs: .now) {
            selectedDate = .now
        }
        updateMonth()
    }

    func setShowsWeekNumbers(_ showsWeekNumbers: Bool) {
        weekColumn.isHidden = !showsWeekNumbers
        weekDivider.isHidden = !showsWeekNumbers
    }

    private func buildView() {
        monthLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        monthLabel.textColor = .labelColor
        monthLabel.alignment = .center

        let previousButton = monthNavigationButton(
            symbol: "chevron.left",
            accessibilityLabel: "Previous month",
            action: #selector(showPreviousMonth)
        )
        let nextButton = monthNavigationButton(
            symbol: "chevron.right",
            accessibilityLabel: "Next month",
            action: #selector(showNextMonth)
        )

        let monthHeader = NSView()
        [previousButton, monthLabel, nextButton].forEach(monthHeader.addSubview)
        [previousButton, monthLabel, nextButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            monthHeader.widthAnchor.constraint(equalToConstant: 218),
            monthHeader.heightAnchor.constraint(equalToConstant: 24),
            previousButton.leadingAnchor.constraint(equalTo: monthHeader.leadingAnchor),
            previousButton.centerYAnchor.constraint(equalTo: monthHeader.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 24),
            previousButton.heightAnchor.constraint(equalToConstant: 24),
            monthLabel.centerXAnchor.constraint(equalTo: monthHeader.centerXAnchor),
            monthLabel.centerYAnchor.constraint(equalTo: monthHeader.centerYAnchor),
            monthLabel.leadingAnchor.constraint(greaterThanOrEqualTo: previousButton.trailingAnchor, constant: 4),
            nextButton.trailingAnchor.constraint(equalTo: monthHeader.trailingAnchor),
            nextButton.centerYAnchor.constraint(equalTo: monthHeader.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 24),
            nextButton.heightAnchor.constraint(equalToConstant: 24),
            monthLabel.trailingAnchor.constraint(lessThanOrEqualTo: nextButton.leadingAnchor, constant: -4)
        ])

        let weekdayGrid = NSGridView(views: [weekdayLabels()])
        weekdayGrid.columnSpacing = 1
        weekdayGrid.rowSpacing = 0

        let daysGrid = NSGridView()
        daysGrid.columnSpacing = 1
        daysGrid.rowSpacing = 3
        for _ in 0..<6 {
            var row: [NSView] = []
            for _ in 0..<7 {
                let button = CalendarDayButton(date: .now)
                button.target = self
                button.action = #selector(selectDate(_:))
                dayButtons.append(button)
                row.append(button)
            }
            daysGrid.addRow(with: row)
        }

        let dateColumns = NSStackView(views: [weekdayGrid, daysGrid])
        dateColumns.orientation = .vertical
        dateColumns.alignment = .centerX
        dateColumns.spacing = 8

        let weekHeaderSpacer = NSView()
        weekHeaderSpacer.translatesAutoresizingMaskIntoConstraints = false
        weekHeaderSpacer.heightAnchor.constraint(equalToConstant: 15).isActive = true

        var weekViews: [NSView] = [weekHeaderSpacer]
        for _ in 0..<6 {
            let label = NSTextField(labelWithString: "")
            label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            label.textColor = .tertiaryLabelColor
            label.alignment = .right
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.widthAnchor.constraint(equalToConstant: 24),
                label.heightAnchor.constraint(equalToConstant: 20)
            ])
            weekLabels.append(label)
            weekViews.append(label)
        }

        weekColumn = NSStackView(views: weekViews)
        weekColumn.orientation = .vertical
        weekColumn.alignment = .trailing
        weekColumn.spacing = 3
        weekColumn.setCustomSpacing(8, after: weekHeaderSpacer)

        weekDivider = NSBox()
        weekDivider.boxType = .separator
        weekDivider.translatesAutoresizingMaskIntoConstraints = false
        weekDivider.widthAnchor.constraint(equalToConstant: 1).isActive = true

        let calendarGrid = NSStackView(views: [weekColumn, weekDivider, dateColumns])
        calendarGrid.orientation = .horizontal
        calendarGrid.alignment = .top
        calendarGrid.spacing = 8

        let content = NSStackView(views: [monthHeader, calendarGrid])
        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 8
        addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            weekDivider.heightAnchor.constraint(equalTo: calendarGrid.heightAnchor)
        ])
    }

    private func monthNavigationButton(symbol: String, accessibilityLabel: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: accessibilityLabel)!, target: self, action: action)
        button.isBordered = false
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        button.focusRingType = .none
        button.toolTip = accessibilityLabel
        button.setAccessibilityLabel(accessibilityLabel)
        return button
    }

    private func weekdayLabels() -> [NSView] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        let ordered = Array(symbols[start...] + symbols[..<start])

        return ordered.map { symbol in
            let label = NSTextField(labelWithString: symbol.uppercased())
            label.font = .systemFont(ofSize: 9, weight: .medium)
            label.textColor = .labelColor
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.widthAnchor.constraint(equalToConstant: 24),
                label.heightAnchor.constraint(equalToConstant: 15)
            ])
            return label
        }
    }

    private func updateMonth() {
        monthLabel.stringValue = displayedMonth.formatted(Date.FormatStyle().month(.wide).year())
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7

        for (index, button) in dayButtons.enumerated() {
            let offset = index - leadingDays
            let date = calendar.date(byAdding: .day, value: offset, to: displayedMonth)!
            button.configure(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                isToday: calendar.isDateInToday(date),
                isSelectedDate: calendar.isDate(date, inSameDayAs: selectedDate)
            )
        }

        for (week, label) in weekLabels.enumerated() {
            let rowStartOffset = week * 7 - leadingDays
            let rowStart = calendar.date(byAdding: .day, value: rowStartOffset, to: displayedMonth)!
            label.stringValue = String(calendar.component(.weekOfYear, from: rowStart))
        }
    }

    @objc private func selectDate(_ sender: CalendarDayButton) {
        selectedDate = sender.date
        updateMonth()
        onSelectDate?(sender.date)
    }

    @objc private func showPreviousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        updateMonth()
    }

    @objc private func showNextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        updateMonth()
    }
}

private final class CalendarDayButton: NSButton {
    private(set) var date: Date
    private var isInDisplayedMonth = true
    private var isToday = false
    private var isSelectedDate = false
    private var isHovered = false
    private var trackingAreaReference: NSTrackingArea?

    init(date: Date) {
        self.date = date
        super.init(frame: .zero)
        isBordered = false
        focusRingType = .none
        setButtonType(.momentaryChange)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 24),
            heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(date: Date, isInDisplayedMonth: Bool, isToday: Bool, isSelectedDate: Bool) {
        self.date = date
        self.isInDisplayedMonth = isInDisplayedMonth
        self.isToday = isToday
        self.isSelectedDate = isSelectedDate
        title = String(calendarDay(date))
        setAccessibilityLabel(date.formatted(date: .complete, time: .omitted))
        needsDisplay = true
    }

    private func calendarDay(_ date: Date) -> Int {
        Calendar.autoupdatingCurrent.component(.day, from: date)
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
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let circleRect = bounds.insetBy(dx: 1, dy: 0)
        if isSelectedDate {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(ovalIn: circleRect).fill()
        } else if isToday {
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(ovalIn: circleRect.insetBy(dx: 0.75, dy: 0.75))
            path.lineWidth = 1.25
            path.stroke()
        } else if isHovered {
            NSColor.unemphasizedSelectedContentBackgroundColor.withAlphaComponent(0.5).setFill()
            NSBezierPath(ovalIn: circleRect).fill()
        }

        let color: NSColor
        if isSelectedDate {
            color = .white
        } else if isToday {
            color = .controlAccentColor
        } else if isInDisplayedMonth {
            color = .labelColor
        } else {
            color = .tertiaryLabelColor
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let size = title.size(withAttributes: attributes)
        let rect = NSRect(x: 0, y: (bounds.height - size.height) / 2, width: bounds.width, height: size.height)
        title.draw(in: rect, withAttributes: attributes)
    }
}

final class MenuRowButton: NSButton {
    private var isHovered = false
    private var isPressed = false
    private var trackingAreaReference: NSTrackingArea?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.cornerCurve = .continuous
    }

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

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateHoverAppearance()
        super.mouseDown(with: event)
        isPressed = false
        updateHoverAppearance()
    }

    override func draw(_ dirtyRect: NSRect) {
        if isPressed || isHovered {
            let fillColor = isPressed
                ? NSColor.unemphasizedSelectedContentBackgroundColor
                : NSColor.labelColor.withAlphaComponent(0.08)
            fillColor.setFill()
            NSBezierPath(
                roundedRect: bounds,
                xRadius: min(9, bounds.height / 2),
                yRadius: min(9, bounds.height / 2)
            ).fill()
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byTruncatingTail
        let drawingFont = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let color = isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: drawingFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let textHeight = (title as NSString).size(withAttributes: attributes).height
        let textRect = NSRect(
            x: 8,
            y: (bounds.height - textHeight) / 2,
            width: bounds.width - 16,
            height: textHeight
        )
        (title as NSString).draw(in: textRect, withAttributes: attributes)
    }

    private func updateHoverAppearance() {
        needsDisplay = true
    }
}
