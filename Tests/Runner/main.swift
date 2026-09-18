import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!

let cases = [
    (4, 0, "four o'clock"),
    (4, 11, "ten past four"),
    (4, 14, "quarter past four"),
    (4, 28, "half past four"),
    (4, 43, "quarter to five"),
    (4, 58, "five o'clock"),
    (23, 58, "twelve o'clock")
]

for (hour, minute, expected) in cases {
    let date = calendar.date(from: DateComponents(
        timeZone: calendar.timeZone,
        year: 2026,
        month: 9,
        day: 18,
        hour: hour,
        minute: minute
    ))!
    let actual = WordTimeFormatter.phrase(for: date, calendar: calendar)
    precondition(actual == expected, "Expected '\(expected)', got '\(actual)'")
}

print("Passed \(cases.count) word-time formatter checks")

let exactDate = calendar.date(from: DateComponents(
    timeZone: calendar.timeZone,
    year: 2026,
    month: 9,
    day: 18,
    hour: 16,
    minute: 33
))!
precondition(
    WordTimeFormatter.phrase(for: exactDate, calendar: calendar, roundToFive: false)
        == "twenty-seven minutes to five"
)
print("Passed exact-minute wording check")
