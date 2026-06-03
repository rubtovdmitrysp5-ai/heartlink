import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSharedStore {
    private static let suiteName = "group.com.example.heartlink"

    static func update(couple: Couple, partner: UserProfile) {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(couple.startedAt, forKey: "startedAt")
        defaults?.set(partner.displayName.isEmpty ? "Партнёр" : partner.displayName, forKey: "partnerName")
        defaults?.set(partner.currentMood.partnerTitle, forKey: "partnerMood")
        defaults?.set(Date(), forKey: "lastUpdatedAt")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
