import SwiftUI

struct HomeView: View {
    let currentUser: UserProfile

    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var router: RouterPath
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var securityService: SecurityService
    @EnvironmentObject private var localPairingService: LocalPairingService
    @StateObject private var viewModel = HomeViewModel()
    @State private var showsResetConfirmation = false

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 18) {
                    HeaderView(currentUser: currentUser, partner: firestoreService.partner)

                    RelationshipCounterCard(
                        days: viewModel.animatedDays,
                        targetDays: firestoreService.couple.daysTogether
                    )
                    .task(id: firestoreService.couple.daysTogether) {
                        await viewModel.animateCounter(to: firestoreService.couple.daysTogether)
                    }

                    AnniversaryCard(couple: firestoreService.couple)
                    MoodSnapshotCard(partner: firestoreService.partner)

                    QuickActionsCard {
                        Task {
                            await notificationService.requestPermission()
                            await notificationService.scheduleDailyLoveQuestionPreview()
                        }
                    } openSecurity: {
                        router.present(.settings)
                    } lock: {
                        securityService.lock()
                    } resetPairing: {
                        showsResetConfirmation = true
                    }

                    RecentHighlightsCard(
                        memories: Array(firestoreService.memories.prefix(2)),
                        goals: Array(firestoreService.goals.prefix(2))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Главная")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Начать заново?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
            Button("Сбросить пару", role: .destructive) {
                localPairingService.reset()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Приложение вернется к экрану кода. Данные на локальном сервере останутся.")
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
                AvatarCircle(name: currentUser.displayName, color: .pink)
                AvatarCircle(name: partner.displayName, color: .indigo)
            }
            .accessibilityLabel("Вы и партнер")
        }
    }
}

private struct AvatarCircle: View {
    let name: String
    let color: Color

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.headline.bold())
            .frame(width: 44, height: 44)
            .foregroundStyle(.white)
            .background(color.gradient, in: Circle())
            .overlay(Circle().stroke(.background, lineWidth: 3))
    }
}

private struct RelationshipCounterCard: View {
    let days: Int
    let targetDays: Int

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Вы вместе")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                        .symbolEffect(.pulse)
                }

                Text(days.formatted())
                    .font(.system(size: 70, weight: .heavy, design: .rounded))
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
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.pink)
                    .frame(width: 58, height: 58)
                    .background(.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("До годовщины")
                        .font(.headline)
                    Text("\(couple.daysUntilAnniversary) \(daysText(couple.daysUntilAnniversary))")
                        .font(.title2.bold())
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

private struct MoodSnapshotCard: View {
    let partner: UserProfile

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: partner.currentMood.symbolName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(partner.currentMood.tint)
                    .frame(width: 54, height: 54)
                    .background(partner.currentMood.tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(partner.displayName) сейчас")
                        .font(.headline)
                    Text(partner.currentMood.partnerTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(partner.currentMood.tint)
                }

                Spacer()
            }
        }
    }
}

private struct QuickActionsCard: View {
    let enableNotifications: () -> Void
    let openSecurity: () -> Void
    let lock: () -> Void
    let resetPairing: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                SectionTitle("Быстрые действия", subtitle: nil, systemImage: "bolt.heart")

                HStack(spacing: 10) {
                    ActionIconButton(title: "Уведомления", systemImage: "bell.badge", action: enableNotifications)
                    ActionIconButton(title: "Защита", systemImage: "lock.shield", action: openSecurity)
                    ActionIconButton(title: "Скрыть", systemImage: "eye.slash", action: lock)
                    ActionIconButton(title: "Сброс", systemImage: "arrow.counterclockwise", action: resetPairing)
                }
            }
        }
    }
}

private struct ActionIconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RecentHighlightsCard: View {
    let memories: [Memory]
    let goals: [CoupleGoal]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Недавнее", subtitle: "Воспоминания и цели", systemImage: "sparkle.magnifyingglass")

                ForEach(memories) { memory in
                    HStack {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.pink)
                        VStack(alignment: .leading) {
                            Text(memory.title)
                                .font(.subheadline.weight(.semibold))
                            Text(memory.locationName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                ForEach(goals) { goal in
                    HStack {
                        Image(systemName: goal.kind.symbolName)
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading) {
                            Text(goal.title)
                                .font(.subheadline.weight(.semibold))
                            ProgressView(value: goal.progress)
                                .tint(.pink)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(currentUser: .sample)
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
            .environmentObject(RouterPath())
            .environmentObject(NotificationService(isFirebaseEnabled: false))
            .environmentObject(SecurityService())
            .environmentObject(LocalPairingService())
    }
}
