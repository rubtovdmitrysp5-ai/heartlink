import SwiftUI

struct PairProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authenticationService: AuthenticationService
    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var localPairingService: LocalPairingService

    @State private var displayName = ""
    @State private var partnerName = ""
    @State private var startedAt = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var currentUserId: String {
        if case .signedIn(let user) = authenticationService.state {
            return user.id
        }
        return localPairingService.session?.userId ?? SampleDataStore.currentUser.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RomanticBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        SectionTitle("Профиль пары", subtitle: "Имена, дата отношений и подключение", systemImage: "person.2.fill")

                        pairPreview

                        GlassCard {
                            VStack(spacing: 12) {
                                profileField("Ваше имя", text: $displayName)
                                profileField("Имя партнёра", text: $partnerName)

                                DatePicker("Дата начала отношений", selection: $startedAt, displayedComponents: .date)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(12)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                                PrimaryActionButton(title: "Сохранить", systemImage: "checkmark.heart", isLoading: isSaving) {
                                    Task { await save() }
                                }
                            }
                        }

                        serverStatusCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .onAppear {
                if displayName.isEmpty {
                    if case .signedIn(let user) = authenticationService.state {
                        displayName = user.displayName
                    } else {
                        displayName = localPairingService.session?.displayName ?? ""
                    }
                    partnerName = firestoreService.partner.displayName
                    startedAt = firestoreService.couple.startedAt
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Понятно", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Не удалось выполнить действие.")
            }
        }
    }

    private var pairPreview: some View {
        GlassCard {
            HStack(spacing: 14) {
                avatar(displayName.isEmpty ? "Вы" : displayName, colors: [.pink, .purple])
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                avatar(partnerName.isEmpty ? "Партнёр" : partnerName, colors: [.indigo, .purple])

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(firestoreService.couple.daysTogether)")
                        .font(.title.bold())
                    Text("дней вместе")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var serverStatusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        localPairingService.isServerReachable ? "Сервер доступен" : "Сервер недоступен",
                        systemImage: localPairingService.isServerReachable ? "checkmark.circle.fill" : "wifi.exclamationmark"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(localPairingService.isServerReachable ? .green : .orange)

                    Spacer()

                    Button {
                        Task {
                            if let userId = localPairingService.session?.userId {
                                await localPairingService.refreshSession(userId: userId)
                            }
                            await firestoreService.refreshLocalCoupleData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Проверить сервер")
                }

                Text(localPairingService.baseURLString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text("Если сервер недоступен, чат и фото не будут синхронизироваться между устройствами.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func avatar(_ name: String, colors: [Color]) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(width: 54, height: 54)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
    }

    private func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPartnerName = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPartnerName.isEmpty else {
            errorMessage = "Введите оба имени."
            return
        }

        isSaving = true
        defer { isSaving = false }

        await firestoreService.updateLocalProfile(
            userId: currentUserId,
            displayName: trimmedName,
            partnerName: trimmedPartnerName,
            startedAt: startedAt
        )

        try? await localPairingService.completeSetup(
            displayName: trimmedName,
            partnerName: trimmedPartnerName,
            startedAt: startedAt
        )

        dismiss()
    }

    private func profileField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(title, text: text)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

#Preview {
    PairProfileView()
        .environmentObject(AuthenticationService(isFirebaseEnabled: false))
        .environmentObject(FirestoreService(isFirebaseEnabled: false))
        .environmentObject(LocalPairingService())
}
