import Foundation
import Combine

@MainActor
final class GoalsViewModel: ObservableObject {
    func increaseProgress(for goal: CoupleGoal, using service: FirestoreService) async {
        await service.updateGoalProgress(goal: goal, progress: goal.progress + 0.12)
    }
}
