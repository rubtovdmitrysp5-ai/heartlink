import SwiftUI

struct PairingFlowView: View {
    let onComplete: (LocalPairingSession) -> Void

    @EnvironmentObject private var pairingService: LocalPairingService
    @StateObject private var viewModel = PairingViewModel()

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    if let session = pairingService.session {
                        switch session.phase {
                        case .waitingForPartner:
                            CodePairingCard(session: session, viewModel: viewModel)
                        case .setupProfile:
                            ProfileSetupCard(session: session, viewModel: viewModel)
                        case .complete:
                            CompletePairingCard(session: session, onComplete: onComplete)
                        }
                    } else {
                        ProgressView("Готовим ваш код")
                            .font(.headline)
                            .tint(.pink)
                            .padding(.top, 40)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(18)
            }
        }
        .task {
            await viewModel.prepare(using: pairingService)
        }
        .onChange(of: pairingService.session) { _, session in
            if let session, session.setupComplete {
                onComplete(session)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 66, weight: .semibold))
                .foregroundStyle(.white, .pink)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("Свяжите ваши сердца")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Покажите код партнеру или создайте тестового партнера для проверки на одном iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
    }
}

private struct CodePairingCard: View {
    let session: LocalPairingSession
    @ObservedObject var viewModel: PairingViewModel
    @EnvironmentObject private var pairingService: LocalPairingService

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    "Ваш персональный код",
                    subtitle: "Партнер может ввести его у себя",
                    systemImage: "link.badge.plus"
                )

                Text(session.personalCode)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .monospaced()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .textSelection(.enabled)

                PairingStatusPill(
                    text: viewModel.statusMessage,
                    isWarning: !pairingService.isServerReachable
                )

                PairingTextField(title: "Код партнера", placeholder: "HL-123456", text: $viewModel.partnerCode)
                    .textInputAutocapitalization(.characters)

                PrimaryActionButton(title: "Связать по коду", systemImage: "heart.fill", isLoading: viewModel.isLoading) {
                    Task { await viewModel.linkPartner(using: pairingService) }
                }

                Button {
                    Task { await viewModel.createTestPartner(using: pairingService) }
                } label: {
                    Label("Создать тестового партнера", systemImage: "person.crop.circle.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    pairingService.reset()
                    Task { await viewModel.prepare(using: pairingService) }
                } label: {
                    Label("Получить новый код", systemImage: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PairingStatusPill: View {
    let text: String
    let isWarning: Bool

    var body: some View {
        Label(text, systemImage: isWarning ? "wifi.exclamationmark" : "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isWarning ? .orange : .green)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProfileSetupCard: View {
    let session: LocalPairingSession
    @ObservedObject var viewModel: PairingViewModel
    @EnvironmentObject private var pairingService: LocalPairingService

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    "Расскажите о вас",
                    subtitle: "Эти данные увидит только ваша пара",
                    systemImage: "person.2.fill"
                )

                if let partnerName = session.partnerName {
                    Label("Партнер найден: \(partnerName)", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }

                PairingTextField(title: "Ваше имя", placeholder: "Например, Дима", text: $viewModel.displayName)
                PairingTextField(title: "Имя партнера", placeholder: "Например, Аня", text: $viewModel.partnerName)

                DatePicker("Дата начала отношений", selection: $viewModel.relationshipStartedAt, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.subheadline.weight(.semibold))
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                PrimaryActionButton(title: "Открыть HeartLink", systemImage: "arrow.right.heart.fill", isLoading: viewModel.isLoading) {
                    Task { await viewModel.completeSetup(using: pairingService) }
                }
            }
        }
    }
}

private struct CompletePairingCard: View {
    let session: LocalPairingSession
    let onComplete: (LocalPairingSession) -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.green)
                Text("Пара создана")
                    .font(.title2.bold())
                Text("Теперь можно открыть ваше общее пространство.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Перейти в приложение", systemImage: "heart.fill") {
                    onComplete(session)
                }
            }
        }
    }
}

private struct PairingTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(placeholder, text: $text)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

#Preview {
    PairingFlowView { _ in }
        .environmentObject(LocalPairingService())
}
