import SwiftUI

struct AppView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AuthenticationService.self) private var authenticationService
    @Environment(SecurityService.self) private var securityService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                switch authenticationService.state {
                case .checking:
                    SplashLoadingView()
                case .signedOut:
                    AuthenticationView()
                case .signedIn(let user):
                    ZStack {
                        RootTabsView(currentUser: user)
                            .task(id: user.id) {
                                container.connectSignedInServices(for: user)
                            }

                        if securityService.isLocked {
                            SecurityLockView()
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.smooth(duration: 0.35), value: securityService.isLocked)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, securityService.privateModeEnabled {
                securityService.lock()
            }
        }
    }
}

private struct SplashLoadingView: View {
    var body: some View {
        ZStack {
            RomanticBackground()
            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white, .pink)
                    .symbolEffect(.pulse)
                Text("Готовим ваше пространство")
                    .font(.headline)
                    .foregroundStyle(.primary)
                ProgressView()
                    .tint(.pink)
            }
        }
    }
}

#Preview {
    AppView()
        .environment(AppContainer())
        .environment(AuthenticationService(isFirebaseEnabled: false))
        .environment(FirestoreService(isFirebaseEnabled: false))
        .environment(StorageService(isFirebaseEnabled: false))
        .environment(NotificationService(isFirebaseEnabled: false))
        .environment(SecurityService())
}
