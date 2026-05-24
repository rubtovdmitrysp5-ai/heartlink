import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let isFirebaseEnabled: Bool
    let authenticationService: AuthenticationService
    let firestoreService: FirestoreService
    let storageService: StorageService
    let notificationService: NotificationService
    let securityService: SecurityService
    let localPairingService: LocalPairingService

    init() {
        let firebaseEnabled = FirebaseBootstrap.configureIfAvailable()
        isFirebaseEnabled = firebaseEnabled
        authenticationService = AuthenticationService(isFirebaseEnabled: firebaseEnabled)
        firestoreService = FirestoreService(isFirebaseEnabled: firebaseEnabled)
        storageService = StorageService(isFirebaseEnabled: firebaseEnabled)
        notificationService = NotificationService(isFirebaseEnabled: firebaseEnabled)
        securityService = SecurityService()
        localPairingService = LocalPairingService()
    }

    func start() {
        authenticationService.start()
        notificationService.configure()
        restoreLocalPairingIfAvailable()
    }

    func connectSignedInServices(for user: UserProfile) {
        firestoreService.start(user: user)
        WidgetSharedStore.update(couple: firestoreService.couple, partner: firestoreService.partner)
    }

    func applyLocalPairing(_ session: LocalPairingSession) {
        guard session.setupComplete else { return }

        let currentUser = UserProfile(
            id: session.userId,
            displayName: session.displayName ?? "Вы",
            email: "",
            avatarURL: nil,
            currentMood: .happy,
            partnerId: session.partnerId,
            coupleId: session.coupleId,
            createdAt: .now
        )

        let partner = UserProfile(
            id: session.partnerId ?? "partner-local",
            displayName: session.partnerName ?? "Партнер",
            email: "",
            avatarURL: nil,
            currentMood: .missYou,
            partnerId: session.userId,
            coupleId: session.coupleId,
            createdAt: .now
        )

        let startedAt = session.relationshipStartedAt ?? Couple.sample.startedAt
        let components = Calendar.current.dateComponents([.day, .month], from: startedAt)
        let couple = Couple(
            id: session.coupleId ?? "couple-local",
            firstUserId: session.userId,
            secondUserId: partner.id,
            startedAt: startedAt,
            anniversaryDay: components.day ?? 1,
            anniversaryMonth: components.month ?? 1,
            inviteCode: session.personalCode,
            privateModeEnabled: false
        )

        authenticationService.useLocalUser(currentUser)
        firestoreService.applyLocalPairing(couple: couple, partner: partner)
        WidgetSharedStore.update(couple: couple, partner: partner)
    }

    private func restoreLocalPairingIfAvailable() {
        guard let session = localPairingService.session, session.setupComplete else { return }
        applyLocalPairing(session)
    }
}
