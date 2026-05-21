import Foundation
import Observation

@MainActor
@Observable
final class GamesViewModel {
    var selectedAnswer: String?
    var dailyAnswer = ""

    func clear() {
        selectedAnswer = nil
        dailyAnswer = ""
    }
}
