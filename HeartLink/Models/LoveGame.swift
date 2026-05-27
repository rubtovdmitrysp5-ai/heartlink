import Foundation

enum LoveGameKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case dailyQuestion
    case partnerQuiz
    case romanticTask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailyQuestion: "Вопрос дня"
        case .partnerQuiz: "Квиз о партнёре"
        case .romanticTask: "Романтичное задание"
        }
    }

    var symbolName: String {
        switch self {
        case .dailyQuestion: "sparkles"
        case .partnerQuiz: "questionmark.bubble"
        case .romanticTask: "heart.text.square"
        }
    }
}

struct LoveGame: Identifiable, Codable, Hashable {
    let id: String
    var kind: LoveGameKind
    var prompt: String
    var options: [String]
    var completedToday: Bool
    var answers: [LoveGameAnswer]?

    static let samples: [LoveGame] = [
        LoveGame(
            id: "game-1",
            kind: .dailyQuestion,
            prompt: "Какой момент этой недели ты хочешь запомнить вместе?",
            options: [],
            completedToday: false,
            answers: []
        ),
        LoveGame(
            id: "game-2",
            kind: .partnerQuiz,
            prompt: "Какой десерт партнёр выберет первым?",
            options: ["Тирамису", "Чизкейк", "Мороженое", "Шоколадный торт"],
            completedToday: false,
            answers: []
        ),
        LoveGame(
            id: "game-3",
            kind: .romanticTask,
            prompt: "Отправь голосовое сообщение с одной причиной, почему ты любишь партнёра.",
            options: [],
            completedToday: true,
            answers: []
        )
    ]
}

struct LoveGameAnswer: Identifiable, Codable, Hashable {
    let id: String
    var userId: String
    var text: String
    var createdAt: Date
}
