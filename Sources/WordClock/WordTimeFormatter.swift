import Foundation

enum WordTimeFormatter {
    private static let numbers = [
        "twelve", "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten", "eleven"
    ]

    private static let minutePhrases = [
        0: "", 5: "five past", 10: "ten past", 15: "quarter past",
        20: "twenty past", 25: "twenty-five past", 30: "half past",
        35: "twenty-five to", 40: "twenty to", 45: "quarter to",
        50: "ten to", 55: "five to"
    ]

    private static let exactMinutes = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty", "twenty-one", "twenty-two", "twenty-three",
        "twenty-four", "twenty-five", "twenty-six", "twenty-seven", "twenty-eight", "twenty-nine"
    ]

    static func phrase(
        for date: Date,
        calendar: Calendar = .current,
        lowercase: Bool = true,
        roundToFive: Bool = true
    ) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let phrase = roundToFive
            ? roundedPhrase(hour: hour, minute: minute)
            : exactPhrase(hour: hour, minute: minute)

        guard !lowercase else { return phrase }
        return phrase.prefix(1).uppercased() + phrase.dropFirst()
    }

    private static func roundedPhrase(hour: Int, minute: Int) -> String {
        let roundedMinute = ((minute + 2) / 5) * 5

        if roundedMinute == 0 {
            return "\(hourName(hour)) o'clock"
        } else if roundedMinute == 60 {
            return "\(hourName(hour + 1)) o'clock"
        } else if roundedMinute <= 30 {
            return "\(minutePhrases[roundedMinute]!) \(hourName(hour))"
        } else {
            return "\(minutePhrases[roundedMinute]!) \(hourName(hour + 1))"
        }
    }

    private static func exactPhrase(hour: Int, minute: Int) -> String {
        if minute == 0 { return "\(hourName(hour)) o'clock" }
        if minute == 15 { return "quarter past \(hourName(hour))" }
        if minute == 30 { return "half past \(hourName(hour))" }
        if minute == 45 { return "quarter to \(hourName(hour + 1))" }

        if minute < 30 {
            return "\(minuteName(minute)) \(minute == 1 ? "minute" : "minutes") past \(hourName(hour))"
        }

        let remaining = 60 - minute
        return "\(minuteName(remaining)) \(remaining == 1 ? "minute" : "minutes") to \(hourName(hour + 1))"
    }

    private static func minuteName(_ minute: Int) -> String {
        exactMinutes[minute]
    }

    private static func hourName(_ hour: Int) -> String {
        numbers[(hour % 12 + 12) % 12]
    }
}
