import SwiftUI

@main
struct HeartLinkApp: App {
    @UIApplicationDelegateAdaptor(HeartLinkAppDelegate.self) private var appDelegate
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(container)
                .environmentObject(container.authenticationService)
                .environmentObject(container.firestoreService)
                .environmentObject(container.storageService)
                .environmentObject(container.notificationService)
                .environmentObject(container.securityService)
                .task {
                    container.start()
                }
        }
    }
}
