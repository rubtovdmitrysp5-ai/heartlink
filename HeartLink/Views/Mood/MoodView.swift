import SwiftUI

struct MoodView: View {
    let currentUser: UserProfile

    @EnvironmentObject private var firestoreService: FirestoreService
    @StateObject private var viewModel = MoodViewModel()

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 18) {
                    SectionTitle("Настроение", subtitle: "Партнёр увидит ваш текущий статус", systemImage: "face.smiling")

                    PartnerMoodCard(partner: firestoreService.partner)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Как вы сейчас?")
                                .font(.title3.bold())

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(MoodStatus.allCases) { mood in
                                    Button {
                                        Task {
                                            await viewModel.updateMood(mood, user: currentUser, service: firestoreService)
                                        }
                                    } label: {
                                        MoodOptionCard(mood: mood, isSelected: viewModel.selectedMood == mood)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Настроение")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectedMood = currentUser.currentMood
        }
    }
}

private struct PartnerMoodCard: View {
    let partner: UserProfile

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: partner.currentMood.symbolName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(partner.currentMood.tint)
                    .frame(width: 76, height: 76)
                    .background(partner.currentMood.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(partner.displayName) сейчас")
                        .font(.headline)
                    Text(partner.currentMood.partnerTitle)
                        .font(.title2.bold())
                        .foregroundStyle(partner.currentMood.tint)
                    Text("Статус обновляется автоматически.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }
}

private struct MoodOptionCard: View {
    let mood: MoodStatus
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: mood.symbolName)
                .font(.system(size: 30, weight: .semibold))
            Text(mood.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(isSelected ? .white : mood.tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            isSelected
                ? AnyShapeStyle(LinearGradient(colors: [mood.tint, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(.regularMaterial),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isSelected ? .white.opacity(0.35) : mood.tint.opacity(0.16))
        }
    }
}

#Preview {
    NavigationStack {
        MoodView(currentUser: .sample)
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
    }
}
