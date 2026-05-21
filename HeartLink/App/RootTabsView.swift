import SwiftUI

struct RootTabsView: View {
    let currentUser: UserProfile

    @State private var selectedTab: AppTab = .home
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: tabRouter.binding(for: tab)) {
                    tab.makeContentView(currentUser: currentUser)
                        .withAppRouter()
                        .withSheetDestinations(sheet: Binding(
                            get: { tabRouter.router(for: tab).presentedSheet },
                            set: { tabRouter.router(for: tab).presentedSheet = $0 }
                        ))
                }
                .environmentObject(tabRouter.router(for: tab))
                .tabItem { tab.label }
                .tag(tab)
            }
        }
        .tint(.pink)
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
            }
        }
    }

    func withSheetDestinations(sheet: Binding<SheetDestination?>) -> some View {
        self.sheet(item: sheet) { destination in
            switch destination {
            case .addMemory:
                AddMemoryView()
                    .presentationDetents([.medium, .large])
            case .settings:
                SecuritySettingsView()
                    .presentationDetents([.medium])
            }
        }
    }
}
