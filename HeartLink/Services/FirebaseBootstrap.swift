import Foundation
import FirebaseCore

enum FirebaseBootstrap {
    static func configureIfAvailable() -> Bool {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return false
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        return true
    }
}
