import Foundation
import Combine

@MainActor
final class GamesViewModel: ObservableObject {
    @Published var selectedAnswer: String?
    @Published var dailyAnswer = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    func submit(game: LoveGame, userId: String, using service: FirestoreService) async -> Bool {
        let answer = game.options.isEmpty ? dailyAnswer : (selectedAnswer ?? "")
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Выберите или введите ответ."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let didSave = await service.submitGameAnswer(game: game, answer: answer, userId: userId)
        if didSave {
            clear()
        } else {
            errorMessage = service.lastErrorMessage ?? "Не удалось сохранить ответ."
        }

        return didSave
    }

    func clear() {
        selectedAnswer = nil
        dailyAnswer = ""
    }
}
