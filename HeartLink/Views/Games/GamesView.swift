import SwiftUI

struct GamesView: View {
    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var router: RouterPath

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 16) {
                    SectionTitle("Игры любви", subtitle: "Вопросы, квизы и нежные задания", systemImage: "sparkles")

                    DailyQuestionHero(game: firestoreService.games.first { $0.kind == .dailyQuestion })

                    ForEach(firestoreService.games) { game in
                        Button {
                            router.navigate(to: .game(game.id))
                        } label: {
                            GameCard(game: game)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Игры")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DailyQuestionHero: View {
    let game: LoveGame?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Сегодня", systemImage: "sun.max.fill")
                        .font(.headline)
                        .foregroundStyle(.pink)
                    Spacer()
                    Text(game?.completedToday == true ? "Готово" : "Новое")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.pink.opacity(0.14), in: Capsule())
                }

                Text(game?.prompt ?? "Какой момент сегодня сделал вас ближе?")
                    .font(.title3.bold())
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GameCard: View {
    let game: LoveGame

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: game.kind.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(game.kind.title)
                        .font(.headline)
                    Text(game.prompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GameDetailView: View {
    let gameId: String

    @EnvironmentObject private var firestoreService: FirestoreService
    @StateObject private var viewModel = GamesViewModel()

    private var game: LoveGame? {
        firestoreService.games.first { $0.id == gameId }
    }

    var body: some View {
        ZStack {
            RomanticBackground()

            if let game {
                ScrollView {
                    VStack(spacing: 18) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label(game.kind.title, systemImage: game.kind.symbolName)
                                    .font(.headline)
                                    .foregroundStyle(.pink)

                                Text(game.prompt)
                                    .font(.title2.bold())
                                    .lineSpacing(4)

                                if game.options.isEmpty {
                                    TextField("Ваш ответ", text: $viewModel.dailyAnswer, axis: .vertical)
                                        .lineLimit(4...7)
                                        .padding(14)
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(game.options, id: \.self) { option in
                                            Button {
                                                withAnimation(.smooth(duration: 0.2)) {
                                                    viewModel.selectedAnswer = option
                                                }
                                            } label: {
                                                HStack {
                                                    Text(option)
                                                        .font(.subheadline.weight(.semibold))
                                                    Spacer()
                                                    if viewModel.selectedAnswer == option {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundStyle(.pink)
                                                    }
                                                }
                                                .padding(14)
                                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                PrimaryActionButton(title: "Отправить партнёру", systemImage: "paperplane.fill") {
                                    viewModel.clear()
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                EmptyStateView(title: "Игра не найдена", subtitle: "Попробуйте открыть её позже.", systemImage: "sparkles")
                    .padding(16)
            }
        }
        .navigationTitle("Игра")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GamesView()
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
            .environmentObject(RouterPath())
    }
}
