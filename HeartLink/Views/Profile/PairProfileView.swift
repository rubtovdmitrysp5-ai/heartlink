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
                        SectionTitle("Профиль пары", subtitle: "Имена, дата отношений и сервер", systemImage: "person.2.fill")

                        GlassCard {
                            VStack(spacing: 12) {
                                profileField("Ваше имя", text: $displayName)
                                profileField("Имя партнера", text: $partnerName)

                                DatePicker("Дата начала отношений", selection: $startedAt, displayedComponents: .date)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(12)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                                HStack {
                                    Label(localPairingService.isServerReachable ? "Сервер доступен" : "Сервер недоступен", systemImage: localPairingService.isServerReachable ? "checkmark.circle.fill" : "wifi.exclamationmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(localPairingService.isServerReachable ? .green : .orange)
                                    Spacer()
                                }

                                Text(localPairingService.baseURLString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                PrimaryActionButton(title: "Сохранить", systemImage: "checkmark.heart", isLoading: isSaving) {
                                    Task { await save() }
                                }
                            }
                        }
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
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        await firestoreService.updateLocalProfile(
            userId: currentUserId,
            displayName: displayName,
            partnerName: partnerName,
            startedAt: startedAt
        )

        try? await localPairingService.completeSetup(
            displayName: displayName,
            partnerName: partnerName,
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
