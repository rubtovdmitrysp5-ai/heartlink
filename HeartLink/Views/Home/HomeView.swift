import SwiftUI

struct HomeView: View {
    let currentUser: UserProfile

    @EnvironmentObject private var authenticationService: AuthenticationService
    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var router: RouterPath
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var securityService: SecurityService
    @EnvironmentObject private var localPairingService: LocalPairingService
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var moodViewModel = MoodViewModel()
    @State private var showsResetConfirmation = false

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    HeaderView(currentUser: currentUser, partner: firestoreService.partner)

                    RelationshipCounterCard(
                        days: viewModel.animatedDays,
                        targetDays: firestoreService.couple.daysTogether
                    )
                    .task(id: firestoreService.couple.daysTogether) {
                        await viewModel.animateCounter(to: firestoreService.couple.daysTogether)
                    }

                    AnniversaryCard(couple: firestoreService.couple)

                    MoodQuickCard(
                        currentMood: moodViewModel.selectedMood,
                        partner: firestoreService.partner
                    ) { mood in
                        Task {
                            await moodViewModel.updateMood(mood, user: currentUser, service: firestoreService)
                            authenticationService.updateLocalUser(mood: mood)
                        }
                    }

                    QuickActionsCard {
                        Task {
                            await notificationService.requestPermission()
                            await notificationService.scheduleDailyLoveQuestionPreview()
                        }
                    } openSecurity: {
                        router.present(.settings)
                    } openProfile: {
                        router.present(.profile)
                    } lock: {
                        securityService.lock()
                    } resetPairing: {
                        showsResetConfirmation = true
                    }

                    TodayFocusCard(
                        nextGoal: firestoreService.goals.first(where: { !$0.isCompleted }),
                        dailyGame: firestoreService.games.first(where: { $0.kind == .dailyQuestion }),
                        isServerReachable: localPairingService.isServerReachable
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Главная")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            moodViewModel.selectedMood = currentUser.currentMood
        }
        .confirmationDialog("Начать заново?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
            Button("Сбросить пару", role: .destructive) {
                localPairingService.reset()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Приложение вернётся к экрану кода. Данные на локальном сервере останутся.")
        }
    }
}

private struct HeaderView: View {
    let currentUser: UserProfile
    let partner: UserProfile

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Привет, \(currentUser.displayName)")
                    .font(.title2.bold())
                Text("Сегодня хороший день, чтобы стать ближе.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: -10) {
                AvatarImage(name: currentUser.displayName, url: currentUser.avatarURL, colors: [.pink, .purple], size: 46)
                AvatarImage(name: partner.displayName, url: partner.avatarURL, colors: [.indigo, .purple], size: 46)
            }
            .accessibilityLabel("Вы и партнёр")
        }
    }
}

private struct RelationshipCounterCard: View {
    let days: Int
    let targetDays: Int

    var body: some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack {
                    Text("Вы вместе")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                }

                Text(days.formatted())
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .purple, .indigo], startPoint: .leading, endPoint: .trailing)
                    )
                    .minimumScaleFactor(0.7)

                Text(dayWord(targetDays))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func dayWord(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "дней вместе" }
        if last == 1 { return "день вместе" }
        if (2...4).contains(last) { return "дня вместе" }
        return "дней вместе"
    }
}

private struct AnniversaryCard: View {
    let couple: Couple

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                Image(systemName: "calendar.badge.heart")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.pink)
                    .frame(width: 54, height: 54)
                    .background(.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("До годовщины")
                        .font(.headline)
                    Text("\(couple.daysUntilAnniversary) \(daysText(couple.daysUntilAnniversary))")
                        .font(.title3.bold())
                    Text(couple.nextAnniversary.heartLinkLongDate)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private func daysText(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "дней" }
        if last == 1 { return "день" }
        if (2...4).contains(last) { return "дня" }
        return "дней"
    }
}

private struct MoodQuickCard: View {
    let currentMood: MoodStatus
    let partner: UserProfile
    let selectMood: (MoodStatus) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle("Настроение", subtitle: "Ваш статус и партнёр", systemImage: "face.smiling")
                    Spacer()
                    Label(partner.currentMood.partnerTitle, systemImage: partner.currentMood.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(partner.currentMood.tint)
                }

                HStack(spacing: 8) {
                    ForEach(MoodStatus.allCases) { mood in
                        Button {
                            selectMood(mood)
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: mood.symbolName)
                                    .font(.headline)
                                Text(mood.title)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(currentMood == mood ? .white : mood.tint)
                            .background(
                                currentMood == mood
                                    ? AnyShapeStyle(LinearGradient(colors: [mood.tint, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(.regularMaterial),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct QuickActionsCard: View {
    let enableNotifications: () -> Void
    let openSecurity: () -> Void
    let openProfile: () -> Void
    let lock: () -> Void
    let resetPairing: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                SectionTitle("Быстрые действия", subtitle: nil, systemImage: "bolt.heart")

                LazyVGrid(columns: columns, spacing: 10) {
                    ActionIconButton(title: "Уведомления", systemImage: "bell.badge", action: enableNotifications)
                    ActionIconButton(title: "Защита", systemImage: "lock.shield", action: openSecurity)
                    ActionIconButton(title: "Профиль пары", systemImage: "person.2", action: openProfile)
                    ActionIconButton(title: "Скрыть экран", systemImage: "eye.slash", action: lock)
                    ActionIconButton(title: "Сброс пары", systemImage: "arrow.counterclockwise", role: .destructive, action: resetPairing)
                }
            }
        }
    }
}

private struct ActionIconButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TodayFocusCard: View {
    let nextGoal: CoupleGoal?
    let dailyGame: LoveGame?
    let isServerReachable: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Сегодня", subtitle: "Что важно сейчас", systemImage: "sparkles")

                FocusRow(
                    icon: isServerReachable ? "checkmark.circle.fill" : "wifi.exclamationmark",
                    title: isServerReachable ? "Сервер подключён" : "Сервер недоступен",
                    subtitle: isServerReachable ? "Данные будут синхронизироваться." : "Проверьте ПК и Wi-Fi.",
                    tint: isServerReachable ? .green : .orange
                )

                if let nextGoal {
                    FocusRow(
                        icon: nextGoal.kind.symbolName,
                        title: nextGoal.title,
                        subtitle: "Цель выполнена на \(Int(nextGoal.progress * 100))%",
                        tint: .pink
                    )
                }

                if let dailyGame {
                    FocusRow(
                        icon: dailyGame.kind.symbolName,
                        title: "Вопрос дня",
                        subtitle: dailyGame.completedToday ? "Ответ сохранён." : dailyGame.prompt,
                        tint: .indigo
                    )
                }
            }
        }
    }
}

private struct FocusRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(currentUser: .sample)
            .environmentObject(AuthenticationService(isFirebaseEnabled: false))
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
            .environmentObject(RouterPath())
            .environmentObject(NotificationService(isFirebaseEnabled: false))
            .environmentObject(SecurityService())
            .environmentObject(LocalPairingService())
    }
}
