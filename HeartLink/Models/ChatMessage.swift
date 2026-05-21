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
    var reactions: [ChatReaction]
    var sentAt: Date
    var isRead: Bool

    static let samples: [ChatMessage] = [
        ChatMessage(
            id: "message-1",
            coupleId: "couple-demo",
            authorId: "partner-demo",
            text: "Увидимся вечером? Я забронировал столик.",
            kind: .text,
            mediaURL: nil,
            voiceDuration: nil,
            reactions: [ChatReaction(id: "reaction-1", emoji: "❤️", authorId: "user-demo")],
            sentAt: .now.addingTimeInterval(-3600),
            isRead: true
        ),
        ChatMessage(
            id: "message-2",
            coupleId: "couple-demo",
            authorId: "user-demo",
            text: "Да. Уже выбираю платье.",
            kind: .text,
            mediaURL: nil,
            voiceDuration: nil,
            reactions: [],
            sentAt: .now.addingTimeInterval(-3000),
            isRead: true
        ),
        ChatMessage(
            id: "message-3",
            coupleId: "couple-demo",
            authorId: "partner-demo",
            text: "Голосовое сообщение",
            kind: .voice,
            mediaURL: nil,
            voiceDuration: 18,
            reactions: [],
            sentAt: .now.addingTimeInterval(-1200),
            isRead: false
        )
    ]
}

