import SwiftUI

struct RootTabsView: View {
    let currentUser: UserProfile

    @State private var selectedTab: AppTab = .home
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                TabNavigationRoot(
                    tab: tab,
                    currentUser: currentUser,
                    selectedTab: $selectedTab,
                    router: tabRouter.router(for: tab)
                )
                .tabItem { tab.label }
                .tag(tab)
            }
        }
        .tint(.pink)
    }
}

private struct TabNavigationRoot: View {
    let tab: AppTab
    let currentUser: UserProfile
    @Binding var selectedTab: AppTab
    @ObservedObject var router: RouterPath

    var body: some View {
        NavigationStack(path: Binding(
            get: { router.path },
            set: { router.path = $0 }
        )) {
            tab.makeContentView(currentUser: currentUser, selectedTab: $selectedTab)
                .environmentObject(router)
                .withAppRouter()
                .withSheetDestinations(sheet: $router.presentedSheet)
        }
    }
}

private extension View {
    func withAppRouter() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .memory(let id):
                MemoryDetailView(memoryId: id)
            case .goal(let id):
                GoalDetailView(goalId: id)
            case .game(let id):
                GameDetailView(gameId: id)
            case .adultGames:
                AdultGamesHubView()
            }
        }
    }

    func withSheetDestinations(sheet: Binding<SheetDestination?>) -> some View {
        self.sheet(item: sheet) { destination in
            switch destination {
            case .addMemory:
                AddMemoryView()
                    .presentationDetents([.medium, .large])
            case .addGoal:
                AddGoalView()
                    .presentationDetents([.medium, .large])
            case .profile:
                PairProfileView()
                    .presentationDetents([.medium, .large])
            case .settings:
                SecuritySettingsView()
                    .presentationDetents([.medium])
            }
        }
    }
}
