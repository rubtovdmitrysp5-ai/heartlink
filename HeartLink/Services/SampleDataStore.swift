import Foundation

enum SampleDataStore {
    static let currentUser = UserProfile.sample
    static let partner = UserProfile.partnerSample
    static let couple = Couple.sample
    static let messages = ChatMessage.samples
    static let memories = Memory.samples
    static let goals = CoupleGoal.samples
    static let games = LoveGame.samples
}

