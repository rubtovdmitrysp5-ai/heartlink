import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var animatedDays = 0

    func animateCounter(to value: Int) async {
        animatedDays = 0
        guard value > 0 else { return }

        let step = max(1, value / 60)
        var current = 0
        while current < value {
            if Task.isCancelled { return }
            current = min(value, current + step)
            animatedDays = current
            try? await Task.sleep(for: .milliseconds(18))
        }
    }
}
