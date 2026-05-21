import Foundation

extension Date {
    var heartLinkLongDate: String {
        HeartLinkDateFormatter.long.string(from: self)
    }

    var heartLinkShortDate: String {
        HeartLinkDateFormatter.short.string(from: self)
    }
}

enum HeartLinkDateFormatter {
    static let long: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

