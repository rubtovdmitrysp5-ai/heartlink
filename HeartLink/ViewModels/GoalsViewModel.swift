import Foundation
import Combine

@MainActor
final class GoalsViewModel: ObservableObject {
    @Published var title = ""
    @Published var detail = ""
    @Published var kind: GoalKind = .task
    @Published var targetAmount = ""
    @Published var amountToAdd = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    func configure(with goal: CoupleGoal) {
        title = goal.title
        detail = goal.detail
        kind = goal.kind
        if let targetAmount = goal.targetAmount {
            self.targetAmount = String(Int(targetAmount))
        }
    }

    func increaseProgress(for goal: CoupleGoal, using service: FirestoreService) async {
        await service.updateGoalProgress(goal: goal, progress: goal.progress + 0.12)
    }

    func createGoal(using service: FirestoreService) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Введите название цели."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let didSave = await service.createGoal(
            title: trimmedTitle,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            targetAmount: kind == .savings ? Double(targetAmount.replacingOccurrences(of: ",", with: ".")) : nil
        )

        if didSave {
            reset()
        } else {
            errorMessage = service.lastErrorMessage ?? "Не удалось создать цель."
        }

        return didSave
    }

    func updateGoal(_ goal: CoupleGoal, using service: FirestoreService) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Введите название цели."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let didSave = await service.updateGoal(
            goal,
            title: trimmedTitle,
            detail: detail,
            kind: kind,
            targetAmount: kind == .savings ? Double(targetAmount.replacingOccurrences(of: ",", with: ".")) : nil
        )

        if !didSave {
            errorMessage = service.lastErrorMessage ?? "Не удалось обновить цель."
        }

        return didSave
    }

    func addAmount(to goal: CoupleGoal, using service: FirestoreService) async {
        guard let amount = Double(amountToAdd.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            errorMessage = "Введите сумму больше нуля."
            return
        }

        isSaving = true
        defer { isSaving = false }
        await service.addSavingsAmount(amount, to: goal)
        amountToAdd = ""
    }

    private func reset() {
        title = ""
        detail = ""
        kind = .task
        targetAmount = ""
        amountToAdd = ""
    }
}
