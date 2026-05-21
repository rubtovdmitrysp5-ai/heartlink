import Foundation
import Observation

@MainActor
@Observable
final class MoodViewModel {
    var selectedMood: MoodStatus = .happy

    func updateMood(_ mood: MoodStatus, user: UserProfile, service: FirestoreService) async {
        selectedMood = mood
        await service.updateMood(mood, userId: user.id)
    }
}
