import Foundation

enum EventConfig {
    static let currentEvent = "MŚ 2026"

    static let finalsBettingClosingDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 2 * 60 * 60)
        components.year = 2024
        components.month = 6
        components.day = 14
        components.hour = 21
        components.minute = 0
        components.second = 0

        guard let date = components.date else {
            preconditionFailure("Invalid finals betting closing date configuration")
        }

        return date
    }()
}
