import Foundation
import Observation

@MainActor
@Observable
final class GoalsViewModel {
    func increaseProgress(for goal: CoupleGoal, using service: FirestoreService) async {
        await service.updateGoalProgress(goal: goal, progress: goal.progress + 0.12)
    }
}
