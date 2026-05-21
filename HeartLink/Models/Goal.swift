import Foundation

enum GoalKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case task
    case savings
    case wishlist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: "Задача"
        case .savings: "Накопление"
        case .wishlist: "Желание"
        }
    }

    var symbolName: String {
        switch self {
        case .task: "checklist"
        case .savings: "banknote"
        case .wishlist: "gift"
        }
    }
}

struct CoupleGoal: Identifiable, Codable, Hashable {
    let id: String
    var coupleId: String
    var title: String
    var detail: String
    var kind: GoalKind
    var progress: Double
    var targetAmount: Double?
    var currentAmount: Double?
    var dueDate: Date?
    var isCompleted: Bool

    static let samples: [CoupleGoal] = [
        CoupleGoal(
            id: "goal-1",
            coupleId: "couple-demo",
            title: "Путешествие к морю",
            detail: "Накопить на спокойную поездку на двоих.",
            kind: .savings,
            progress: 0.62,
            targetAmount: 180000,
            currentAmount: 111600,
            dueDate: .now.addingTimeInterval(86400 * 90),
            isCompleted: false
        ),
        CoupleGoal(
            id: "goal-2",
            coupleId: "couple-demo",
            title: "Вечер без дел",
            detail: "Приготовить ужин и выключить уведомления.",
            kind: .task,
            progress: 0.35,
            targetAmount: nil,
            currentAmount: nil,
            dueDate: .now.addingTimeInterval(86400 * 3),
            isCompleted: false
        ),
        CoupleGoal(
            id: "goal-3",
            coupleId: "couple-demo",
            title: "Керамические кружки",
            detail: "Найти пару кружек для воскресного кофе.",
            kind: .wishlist,
            progress: 0.1,
            targetAmount: nil,
            currentAmount: nil,
            dueDate: nil,
            isCompleted: false
        )
    ]
}

