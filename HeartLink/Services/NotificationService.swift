import Foundation
import Combine
import FirebaseMessaging
import UserNotifications
import UIKit

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    private let isFirebaseEnabled: Bool
    @Published private(set) var permissionGranted = false
    @Published private(set) var fcmToken: String?

    init(isFirebaseEnabled: Bool) {
        self.isFirebaseEnabled = isFirebaseEnabled
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        guard isFirebaseEnabled else { return }
        Messaging.messaging().delegate = self
    }

    func requestPermission() async {
        do {
            permissionGranted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            guard permissionGranted else { return }
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            permissionGranted = false
        }
    }

    func scheduleDailyLoveQuestionPreview() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-love-question"])

        let content = UNMutableNotificationContent()
        content.title = "HeartLink"
        content.body = "Новый вопрос дня уже ждёт вас двоих."
        content.sound = .default

        var date = DateComponents()
        date.hour = 20
        date.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-love-question", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
