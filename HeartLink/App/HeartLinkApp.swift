import SwiftUI

@main
struct HeartLinkApp: App {
    @UIApplicationDelegateAdaptor(HeartLinkAppDelegate.self) private var appDelegate
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(container)
                .environment(container.authenticationService)
                .environment(container.firestoreService)
                .environment(container.storageService)
                .environment(container.notificationService)
                .environment(container.securityService)
                .task {
                    container.start()
                }
        }
    }
}

