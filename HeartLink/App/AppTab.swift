import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case chat
    case memories
    case goals
    case games

    var id: String { rawValue }

    @ViewBuilder
    func makeContentView(currentUser: UserProfile, selectedTab: Binding<AppTab>) -> some View {
        switch self {
        case .home:
            HomeView(currentUser: currentUser)
        case .chat:
            ChatView(currentUser: currentUser) {
                selectedTab.wrappedValue = .home
            }
        case .memories:
            MemoriesView(currentUser: currentUser)
        case .goals:
            GoalsView()
        case .games:
            GamesView()
        }
    }

    @ViewBuilder
    var label: some View {
        switch self {
        case .home:
            Label("Главная", systemImage: "heart.fill")
        case .chat:
            Label("Чат", systemImage: "bubble.left.and.bubble.right.fill")
        case .memories:
            Label("Память", systemImage: "photo.on.rectangle.angled")
        case .goals:
            Label("Цели", systemImage: "target")
        case .games:
            Label("Игры", systemImage: "sparkles")
        }
    }
}
