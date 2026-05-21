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

    init() {
        let firebaseEnabled = FirebaseBootstrap.configureIfAvailable()
        isFirebaseEnabled = firebaseEnabled
        authenticationService = AuthenticationService(isFirebaseEnabled: firebaseEnabled)
        firestoreService = FirestoreService(isFirebaseEnabled: firebaseEnabled)
        storageService = StorageService(isFirebaseEnabled: firebaseEnabled)
        notificationService = NotificationService(isFirebaseEnabled: firebaseEnabled)
        securityService = SecurityService()
    }

    func start() {
        authenticationService.start()
        notificationService.configure()
    }

    func connectSignedInServices(for user: UserProfile) {
        firestoreService.start(user: user)
        WidgetSharedStore.update(couple: firestoreService.couple, partner: firestoreService.partner)
    }
}
