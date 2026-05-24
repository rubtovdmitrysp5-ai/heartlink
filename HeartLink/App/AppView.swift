import SwiftUI

struct AppView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var authenticationService: AuthenticationService
    @EnvironmentObject private var securityService: SecurityService
    @EnvironmentObject private var localPairingService: LocalPairingService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if localPairingService.needsPairingFlow {
                PairingFlowView { session in
                    container.applyLocalPairing(session)
                }
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
        .animation(.smooth(duration: 0.35), value: localPairingService.needsPairingFlow)
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
        .environmentObject(AppContainer())
        .environmentObject(AuthenticationService(isFirebaseEnabled: false))
        .environmentObject(FirestoreService(isFirebaseEnabled: false))
        .environmentObject(StorageService(isFirebaseEnabled: false))
        .environmentObject(NotificationService(isFirebaseEnabled: false))
        .environmentObject(SecurityService())
        .environmentObject(LocalPairingService())
}
