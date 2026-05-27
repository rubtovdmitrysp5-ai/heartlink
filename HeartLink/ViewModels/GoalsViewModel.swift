import Foundation
import Combine

@MainActor
final class GoalsViewModel: ObservableObject {
    @Published var title = ""
    @Published var detail = ""
    @Published var kind: GoalKind = .task
    @Published var targetAmount = ""
    @Published var isSaving = false

    func increaseProgress(for goal: CoupleGoal, using service: FirestoreService) async {
        await service.updateGoalProgress(goal: goal, progress: goal.progress + 0.12)
    }

    func createGoal(using service: FirestoreService) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        isSaving = true
        defer { isSaving = false }

        await service.createGoal(
            title: trimmedTitle,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            targetAmount: kind == .savings ? Double(targetAmount.replacingOccurrences(of: ",", with: ".")) : nil
        )

        title = ""
        detail = ""
        kind = .task
        targetAmount = ""
        return true
    }
}
