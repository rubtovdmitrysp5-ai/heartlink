import Foundation
import FirebaseCore
import FirebaseFirestore

enum FirebaseBootstrap {
    static func configureIfAvailable() -> Bool {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return false
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()

            let settings = Firestore.firestore().settings
            settings.isPersistenceEnabled = true
            settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
            Firestore.firestore().settings = settings
        }

        return true
    }
}

