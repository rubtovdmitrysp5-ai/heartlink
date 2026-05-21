import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var email: String
    var avatarURL: URL?
    var currentMood: MoodStatus
    var partnerId: String?
    var coupleId: String?
    var createdAt: Date

    static let sample = UserProfile(
        id: "user-demo",
        displayName: "Алина",
        email: "alina@example.com",
        avatarURL: nil,
        currentMood: .happy,
        partnerId: "partner-demo",
        coupleId: "couple-demo",
        createdAt: .now.addingTimeInterval(-86400 * 420)
    )

    static let partnerSample = UserProfile(
        id: "partner-demo",
        displayName: "Марк",
        email: "mark@example.com",
        avatarURL: nil,
        currentMood: .missYou,
        partnerId: "user-demo",
        coupleId: "couple-demo",
        createdAt: .now.addingTimeInterval(-86400 * 420)
    )
}
