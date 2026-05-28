import Foundation

enum LoveGameKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case dailyQuestion
    case partnerQuiz
    case romanticTask
    case adultTruthOrDare
    case adultDrinkOrDare
    case desireCards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailyQuestion: "Вопрос дня"
        case .partnerQuiz: "Квиз о партнёре"
        case .romanticTask: "Романтичное задание"
        case .adultTruthOrDare: "Правда или действие 18+"
        case .adultDrinkOrDare: "Делай или пей 18+"
        case .desireCards: "Карты желаний"
        }
    }

    var symbolName: String {
        switch self {
        case .dailyQuestion: "sparkles"
        case .partnerQuiz: "questionmark.bubble"
        case .romanticTask: "heart.text.square"
        case .adultTruthOrDare: "flame.fill"
        case .adultDrinkOrDare: "wineglass.fill"
        case .desireCards: "heart.rectangle.fill"
        }
    }

    var isAdult: Bool {
        switch self {
        case .adultTruthOrDare, .adultDrinkOrDare, .desireCards: true
        default: false
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
        ),
        LoveGame(
            id: "game-4",
            kind: .adultTruthOrDare,
            prompt: "Выберите: честный интимный вопрос или нежное действие для партнёра. Только по взаимному согласию.",
            options: ["Правда", "Действие", "Пропустить"],
            completedToday: false,
            answers: []
        ),
        LoveGame(
            id: "game-5",
            kind: .adultDrinkOrDare,
            prompt: "Выполните романтичное задание или сделайте глоток. Можно заменить напиток чаем или водой.",
            options: ["Сделаю", "Пью", "Новое задание"],
            completedToday: false,
            answers: []
        ),
        LoveGame(
            id: "game-6",
            kind: .desireCards,
            prompt: "Выберите одну карту желания на вечер: поцелуй, массаж, комплимент или объятия без телефона.",
            options: ["Поцелуй", "Массаж", "Комплимент", "Объятия"],
            completedToday: false,
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
