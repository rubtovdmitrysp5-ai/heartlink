import Foundation

enum MessageKind: String, Codable, Hashable {
    case text
    case image
    case voice
}

struct ChatReaction: Identifiable, Codable, Hashable {
    let id: String
    var emoji: String
    var authorId: String
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: String
    var coupleId: String
    var authorId: String
    var text: String
    var kind: MessageKind
    var mediaURL: URL?
    var voiceDuration: TimeInterval?
    var isOneTime: Bool?
    var oneTimeDuration: TimeInterval?
    var viewedBy: [String]?
    var reactions: [ChatReaction]
    var sentAt: Date
    var isRead: Bool

    func wasViewed(by userId: String) -> Bool {
        viewedBy?.contains(userId) == true
    }

    static let samples: [ChatMessage] = [
        ChatMessage(
            id: "message-1",
            coupleId: "couple-demo",
            authorId: "partner-demo",
            text: "РЈРІРёРґРёРјСЃСЏ РІРµС‡РµСЂРѕРј? РЇ Р·Р°Р±СЂРѕРЅРёСЂРѕРІР°Р» СЃС‚РѕР»РёРє.",
            kind: .text,
            mediaURL: nil,
            voiceDuration: nil,
            isOneTime: nil,
            oneTimeDuration: nil,
            viewedBy: nil,
            reactions: [ChatReaction(id: "reaction-1", emoji: "\u{2764}\u{FE0F}", authorId: "user-demo")],
            sentAt: .now.addingTimeInterval(-3600),
            isRead: true
        ),
        ChatMessage(
            id: "message-2",
            coupleId: "couple-demo",
            authorId: "user-demo",
            text: "Р”Р°. РЈР¶Рµ РІС‹Р±РёСЂР°СЋ РїР»Р°С‚СЊРµ.",
            kind: .text,
            mediaURL: nil,
            voiceDuration: nil,
            isOneTime: nil,
            oneTimeDuration: nil,
            viewedBy: nil,
            reactions: [],
            sentAt: .now.addingTimeInterval(-3000),
            isRead: true
        ),
        ChatMessage(
            id: "message-3",
            coupleId: "couple-demo",
            authorId: "partner-demo",
            text: "Р“РѕР»РѕСЃРѕРІРѕРµ СЃРѕРѕР±С‰РµРЅРёРµ",
            kind: .voice,
            mediaURL: nil,
            voiceDuration: 18,
            isOneTime: nil,
            oneTimeDuration: nil,
            viewedBy: nil,
            reactions: [],
            sentAt: .now.addingTimeInterval(-1200),
            isRead: false
        )
    ]
}
