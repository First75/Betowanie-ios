import Foundation

extension Date {
    private static let polishLocale = Locale(identifier: "pl_PL")

    var polishDateString: String {
        formatted(.dateTime.day().month(.wide).year().locale(Self.polishLocale))
    }

    var polishTimeString: String {
        formatted(.dateTime.hour().minute().locale(Self.polishLocale))
    }

    var polishDateTimeString: String {
        formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Self.polishLocale))
    }

    var polishRelativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Self.polishLocale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
