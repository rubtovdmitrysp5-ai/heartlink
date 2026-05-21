import Foundation

struct Couple: Identifiable, Codable, Hashable {
    let id: String
    var firstUserId: String
    var secondUserId: String
    var startedAt: Date
    var anniversaryDay: Int
    var anniversaryMonth: Int
    var inviteCode: String
    var privateModeEnabled: Bool

    var daysTogether: Int {
        Calendar.current.dateComponents([.day], from: startedAt, to: .now).day ?? 0
    }

    var nextAnniversary: Date {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        let components = DateComponents(year: currentYear, month: anniversaryMonth, day: anniversaryDay)
        let thisYear = calendar.date(from: components) ?? .now
        if thisYear >= calendar.startOfDay(for: .now) {
            return thisYear
        }
        return calendar.date(from: DateComponents(year: currentYear + 1, month: anniversaryMonth, day: anniversaryDay)) ?? thisYear
    }

    var daysUntilAnniversary: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: nextAnniversary).day ?? 0
    }

    static let sample = Couple(
        id: "couple-demo",
        firstUserId: "user-demo",
        secondUserId: "partner-demo",
        startedAt: .now.addingTimeInterval(-86400 * 486),
        anniversaryDay: 14,
        anniversaryMonth: 2,
        inviteCode: "LOVE-1420",
        privateModeEnabled: false
    )
}

