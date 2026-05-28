import SwiftUI

struct GamesView: View {
    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var router: RouterPath

    private var regularGames: [LoveGame] {
        firestoreService.games.filter { !$0.kind.isAdult }
    }

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 16) {
                    SectionTitle("Игры любви", subtitle: "Вопросы, квизы и задания для двоих", systemImage: "sparkles")

                    DailyQuestionHero(game: firestoreService.games.first { $0.kind == .dailyQuestion })

                    Button {
                        router.navigate(to: .adultGames)
                    } label: {
                        AdultGamesEntryCard()
                    }
                    .buttonStyle(.plain)

                    if regularGames.isEmpty {
                        EmptyStateView(title: "Игры загружаются", subtitle: "Проверьте сервер или откройте экран чуть позже.", systemImage: "sparkles")
                    } else {
                        ForEach(regularGames) { game in
                            Button {
                                router.navigate(to: .game(game.id))
                            } label: {
                                GameCard(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Игры")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await firestoreService.refreshLocalCoupleData()
        }
    }
}

private struct AdultGamesEntryCard: View {
    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(
                        LinearGradient(colors: [.red, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Игры 18+")
                            .font(.headline)
                        Text("отдельно")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(.red.opacity(0.82), in: Capsule())
                    }
                    Text("Правда или действие, делай или пей, карты желаний с ходами и раундами.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
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
                    Text(game?.completedToday == true ? "Сохранено" : "Новое")
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

    private var answerCount: Int {
        game.answers?.count ?? 0
    }

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
                    HStack(spacing: 8) {
                        Text(game.kind.title)
                            .font(.headline)
                        if game.completedToday {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    Text(game.prompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if answerCount > 0 {
                        Text("Ответов: \(answerCount)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.pink)
                    }
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
    @EnvironmentObject private var authenticationService: AuthenticationService
    @StateObject private var viewModel = GamesViewModel()

    private var game: LoveGame? {
        firestoreService.games.first { $0.id == gameId }
    }

    private var userId: String {
        if case .signedIn(let user) = authenticationService.state {
            return user.id
        }
        return SampleDataStore.currentUser.id
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

                                PrimaryActionButton(
                                    title: game.completedToday ? "Отправить ещё ответ" : "Отправить партнёру",
                                    systemImage: "paperplane.fill",
                                    isLoading: viewModel.isSaving
                                ) {
                                    Task {
                                        _ = await viewModel.submit(game: game, userId: userId, using: firestoreService)
                                    }
                                }
                            }
                        }

                        GameAnswersHistory(answers: game.answers ?? [])
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
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Понятно", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Не удалось выполнить действие.")
        }
    }
}

private struct GameAnswersHistory: View {
    let answers: [LoveGameAnswer]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("История ответов")
                    .font(.headline)

                if answers.isEmpty {
                    Text("Пока нет ответов. Ответьте первым.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(answers.sorted(by: { $0.createdAt > $1.createdAt })) { answer in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(answer.text)
                                .font(.subheadline.weight(.semibold))
                            Text(answer.createdAt.heartLinkShortDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }
}

struct AdultGamesHubView: View {
    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 16) {
                    SectionTitle("Игры 18+", subtitle: "Только по взаимному согласию", systemImage: "flame.fill")

                    Text("Перед началом договоритесь о стоп-слове. Любой игрок может пропустить ход без объяснений.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    ForEach(AdultGameDefinition.all) { definition in
                        NavigationLink {
                            AdultGameSessionView(definition: definition)
                        } label: {
                            AdultGameDefinitionCard(definition: definition)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Игры 18+")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdultGameDefinitionCard: View {
    let definition: AdultGameDefinition

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: definition.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(
                        LinearGradient(colors: definition.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(definition.title)
                        .font(.headline)
                    Text(definition.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text("\(definition.prompts.count) карточек")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.pink)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AdultGameSessionView: View {
    let definition: AdultGameDefinition

    @EnvironmentObject private var authenticationService: AuthenticationService
    @EnvironmentObject private var firestoreService: FirestoreService
    @State private var currentPlayerIndex = 0
    @State private var round = 1
    @State private var selectedKind: AdultPromptKind?
    @State private var currentPrompt: AdultPrompt?
    @State private var completedCount = 0
    @State private var skippedCount = 0

    private var players: [String] {
        let currentName: String
        if case .signedIn(let user) = authenticationService.state {
            currentName = user.displayName
        } else {
            currentName = "Вы"
        }
        return [currentName, firestoreService.partner.displayName.isEmpty ? "Партнёр" : firestoreService.partner.displayName]
    }

    private var currentPlayer: String {
        players[currentPlayerIndex % players.count]
    }

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 16) {
                    sessionHeader

                    if definition.requiresChoice, currentPrompt == nil {
                        choiceCard
                    } else {
                        promptCard
                    }

                    scoreboard
                }
                .padding(16)
            }
        }
        .navigationTitle(definition.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !definition.requiresChoice && currentPrompt == nil {
                drawPrompt(kind: definition.defaultKind)
            }
        }
    }

    private var sessionHeader: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Раунд \(round)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .foregroundStyle(.pink)
                    Spacer()
                    Text("Ходит")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(currentPlayer)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)

                HStack(spacing: 8) {
                    ForEach(players.indices, id: \.self) { index in
                        Text(players[index])
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .foregroundStyle(index == currentPlayerIndex ? .white : .secondary)
                            .background(index == currentPlayerIndex ? AnyShapeStyle(.pink.gradient) : AnyShapeStyle(.regularMaterial), in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var choiceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Выберите тип хода")
                    .font(.headline)

                HStack(spacing: 10) {
                    AdultChoiceButton(title: "Правда", icon: "questionmark.bubble.fill", tint: .purple) {
                        drawPrompt(kind: .truth)
                    }
                    AdultChoiceButton(title: "Действие", icon: "flame.fill", tint: .pink) {
                        drawPrompt(kind: .dare)
                    }
                }

                Button {
                    skipTurn()
                } label: {
                    Label("Пропустить ход", systemImage: "forward.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(13)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var promptCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label(currentPrompt?.kind.title ?? definition.defaultKind.title, systemImage: currentPrompt?.kind.symbolName ?? definition.symbolName)
                    .font(.headline)
                    .foregroundStyle(.pink)

                Text(currentPrompt?.text ?? "Нажмите, чтобы взять карточку.")
                    .font(.title2.bold())
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if definition.kind == .drinkOrDare {
                    HStack(spacing: 10) {
                        AdultChoiceButton(title: "Сделаю", icon: "checkmark.heart.fill", tint: .pink) {
                            completeTurn()
                        }
                        AdultChoiceButton(title: "Пью", icon: "wineglass.fill", tint: .indigo) {
                            skipTurn()
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        AdultChoiceButton(title: "Выполнено", icon: "checkmark.circle.fill", tint: .pink) {
                            completeTurn()
                        }
                        AdultChoiceButton(title: "Пас", icon: "forward.fill", tint: .orange) {
                            skipTurn()
                        }
                    }
                }

                Button {
                    drawPrompt(kind: selectedKind ?? definition.defaultKind)
                } label: {
                    Label("Другая карточка", systemImage: "shuffle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(13)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scoreboard: some View {
        GlassCard {
            HStack(spacing: 14) {
                StatPill(title: "Выполнено", value: completedCount, tint: .pink)
                StatPill(title: "Пас", value: skippedCount, tint: .orange)
                StatPill(title: "Раунд", value: round, tint: .purple)
            }
        }
    }

    private func drawPrompt(kind: AdultPromptKind) {
        selectedKind = kind
        let matching = definition.prompts.filter { $0.kind == kind }
        currentPrompt = (matching.isEmpty ? definition.prompts : matching).randomElement()
    }

    private func completeTurn() {
        completedCount += 1
        nextTurn()
    }

    private func skipTurn() {
        skippedCount += 1
        nextTurn()
    }

    private func nextTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        if currentPlayerIndex == 0 {
            round += 1
        }
        currentPrompt = nil
        selectedKind = nil
        if !definition.requiresChoice {
            drawPrompt(kind: definition.defaultKind)
        }
    }
}

private struct AdultChoiceButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct StatPill: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.bold())
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AdultGameDefinition: Identifiable {
    enum Kind: Equatable {
        case truthOrDare
        case drinkOrDare
        case desireCards
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let symbolName: String
    let colors: [Color]
    let defaultKind: AdultPromptKind
    let requiresChoice: Bool
    let prompts: [AdultPrompt]

    static let all: [AdultGameDefinition] = [
        AdultGameDefinition(
            id: "truth-or-dare",
            kind: .truthOrDare,
            title: "Правда или действие",
            subtitle: "Каждый ход игрок выбирает вопрос или действие.",
            symbolName: "flame.fill",
            colors: [.red, .pink, .purple],
            defaultKind: .truth,
            requiresChoice: true,
            prompts: [
                AdultPrompt(kind: .truth, text: "Какой жест партнёра сильнее всего заставляет тебя хотеть быть ближе?"),
                AdultPrompt(kind: .truth, text: "Какой поцелуй ты вспоминаешь чаще всего?"),
                AdultPrompt(kind: .truth, text: "Какая деталь во внешности партнёра тебя особенно притягивает?"),
                AdultPrompt(kind: .truth, text: "Какое романтичное желание ты давно хотел(а) предложить?"),
                AdultPrompt(kind: .truth, text: "Что помогает тебе чувствовать себя желанным рядом с партнёром?"),
                AdultPrompt(kind: .dare, text: "Сделай партнёру комплимент шёпотом, глядя в глаза."),
                AdultPrompt(kind: .dare, text: "Поцелуй партнёра так, как будто это первое свидание."),
                AdultPrompt(kind: .dare, text: "Сделай партнёру массаж плеч одну минуту."),
                AdultPrompt(kind: .dare, text: "Обними партнёра на 30 секунд без телефона и разговоров."),
                AdultPrompt(kind: .dare, text: "Выбери песню и пригласи партнёра на медленный танец.")
            ]
        ),
        AdultGameDefinition(
            id: "drink-or-dare",
            kind: .drinkOrDare,
            title: "Делай или пей",
            subtitle: "Выполни карточку или сделай глоток. Напиток может быть безалкогольным.",
            symbolName: "wineglass.fill",
            colors: [.purple, .indigo, .pink],
            defaultKind: .drinkTask,
            requiresChoice: false,
            prompts: [
                AdultPrompt(kind: .drinkTask, text: "Скажи партнёру три вещи, которые тебе в нём очень нравятся, или пей."),
                AdultPrompt(kind: .drinkTask, text: "Поцелуй партнёра в выбранное им место выше плеч, или пей."),
                AdultPrompt(kind: .drinkTask, text: "Покажи своё любимое движение для медленного танца, или пей."),
                AdultPrompt(kind: .drinkTask, text: "Сделай партнёру мини-массаж рук, или пей."),
                AdultPrompt(kind: .drinkTask, text: "Произнеси романтичное обещание на эту неделю, или пей."),
                AdultPrompt(kind: .drinkTask, text: "Дай партнёру выбрать следующее свидание, или пей."),
                AdultPrompt(kind: .drinkTask, text: "Расскажи о самом тёплом моменте ваших отношений, или пей.")
            ]
        ),
        AdultGameDefinition(
            id: "desire-cards",
            kind: .desireCards,
            title: "Карты желаний",
            subtitle: "Карточки с мягкими желаниями для вечера вдвоём.",
            symbolName: "heart.rectangle.fill",
            colors: [.pink, .purple, .red],
            defaultKind: .desire,
            requiresChoice: false,
            prompts: [
                AdultPrompt(kind: .desire, text: "Карта желания: 10 минут объятий без отвлечений."),
                AdultPrompt(kind: .desire, text: "Карта желания: партнёр выбирает фильм, ты выбираешь перекус."),
                AdultPrompt(kind: .desire, text: "Карта желания: обменяйтесь тремя честными комплиментами."),
                AdultPrompt(kind: .desire, text: "Карта желания: медленный танец под одну песню."),
                AdultPrompt(kind: .desire, text: "Карта желания: массаж плеч или рук на выбор партнёра."),
                AdultPrompt(kind: .desire, text: "Карта желания: вместе придумайте идеальное свидание на выходные."),
                AdultPrompt(kind: .desire, text: "Карта желания: каждый говорит одно желание, а второй выбирает, когда его исполнить.")
            ]
        )
    ]
}

private enum AdultPromptKind: Equatable {
    case truth
    case dare
    case drinkTask
    case desire

    var title: String {
        switch self {
        case .truth: "Правда"
        case .dare: "Действие"
        case .drinkTask: "Делай или пей"
        case .desire: "Карта желания"
        }
    }

    var symbolName: String {
        switch self {
        case .truth: "questionmark.bubble.fill"
        case .dare: "flame.fill"
        case .drinkTask: "wineglass.fill"
        case .desire: "heart.rectangle.fill"
        }
    }
}

private struct AdultPrompt {
    let kind: AdultPromptKind
    let text: String
}

#Preview {
    NavigationStack {
        GamesView()
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
            .environmentObject(RouterPath())
    }
}
