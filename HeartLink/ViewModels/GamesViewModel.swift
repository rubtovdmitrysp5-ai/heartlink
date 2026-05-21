import Foundation
import Combine

@MainActor
final class GamesViewModel: ObservableObject {
    @Published var selectedAnswer: String?
    @Published var dailyAnswer = ""

    func clear() {
        selectedAnswer = nil
        dailyAnswer = ""
    }
}
