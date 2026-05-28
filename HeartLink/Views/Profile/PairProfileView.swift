import PhotosUI
import SwiftUI
import UIKit

struct PairProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authenticationService: AuthenticationService
    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var storageService: StorageService
    @EnvironmentObject private var localPairingService: LocalPairingService

    @State private var displayName = ""
    @State private var partnerName = ""
    @State private var startedAt = Date()
    @State private var avatarURL: URL?
    @State private var partnerAvatarURL: URL?
    @State private var selectedAvatarPhoto: PhotosPickerItem?
    @State private var selectedPartnerAvatarPhoto: PhotosPickerItem?
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
                        SectionTitle("Профиль пары", subtitle: "Имена, аватарки и подключение", systemImage: "person.2.fill")

                        avatarPickerCard

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
            .onAppear(perform: loadInitialValues)
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

    private var avatarPickerCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                AvatarPicker(
                    title: "Вы",
                    name: displayName.isEmpty ? "Вы" : displayName,
                    url: avatarURL,
                    selection: $selectedAvatarPhoto,
                    colors: [.pink, .purple]
                )

                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)

                AvatarPicker(
                    title: "Партнёр",
                    name: partnerName.isEmpty ? "Партнёр" : partnerName,
                    url: partnerAvatarURL,
                    selection: $selectedPartnerAvatarPhoto,
                    colors: [.indigo, .purple]
                )

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
            }
        }
    }

    private func loadInitialValues() {
        guard displayName.isEmpty else { return }
        if case .signedIn(let user) = authenticationService.state {
            displayName = user.displayName
            avatarURL = user.avatarURL
        } else {
            displayName = localPairingService.session?.displayName ?? ""
            avatarURL = localPairingService.session?.avatarURL
        }
        partnerName = firestoreService.partner.displayName
        partnerAvatarURL = firestoreService.partner.avatarURL
        startedAt = firestoreService.couple.startedAt
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

        let newAvatarURL = await uploadSelectedAvatar(selectedAvatarPhoto) ?? avatarURL
        let newPartnerAvatarURL = await uploadSelectedAvatar(selectedPartnerAvatarPhoto) ?? partnerAvatarURL

        await firestoreService.updateLocalProfile(
            userId: currentUserId,
            displayName: trimmedName,
            partnerName: trimmedPartnerName,
            startedAt: startedAt,
            avatarURL: newAvatarURL,
            partnerAvatarURL: newPartnerAvatarURL
        )

        try? await localPairingService.completeSetup(
            displayName: trimmedName,
            partnerName: trimmedPartnerName,
            startedAt: startedAt
        )

        authenticationService.updateLocalUser(displayName: trimmedName, avatarURL: newAvatarURL)
        avatarURL = newAvatarURL
        partnerAvatarURL = newPartnerAvatarURL
        dismiss()
    }

    private func uploadSelectedAvatar(_ item: PhotosPickerItem?) async -> URL? {
        guard let data = try? await item?.loadTransferable(type: Data.self) else { return nil }
        let compressedData = Self.compressImageData(data) ?? data
        return await firestoreService.uploadAvatarImageData(compressedData, storageService: storageService)
    }

    private static func compressImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        let size = CGSize(width: 512, height: 512)
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let side = min(imageWidth, imageHeight)
        let cropRect = CGRect(
            x: (imageWidth - side) / 2,
            y: (imageHeight - side) / 2,
            width: side,
            height: side
        )
        let squareImage = cgImage.cropping(to: cropRect).map { UIImage(cgImage: $0, scale: image.scale, orientation: image.imageOrientation) } ?? image
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            squareImage.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.82)
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

private struct AvatarPicker: View {
    let title: String
    let name: String
    let url: URL?
    @Binding var selection: PhotosPickerItem?
    let colors: [Color]

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            VStack(spacing: 8) {
                AvatarImage(name: name, url: url, colors: colors, size: 62)
                Label(title, systemImage: "camera.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Выбрать аватар \(title.lowercased())")
    }
}

struct AvatarImage: View {
    let name: String
    let url: URL?
    let colors: [Color]
    var size: CGFloat = 44

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                ZStack {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.background, lineWidth: 3))
    }
}

#Preview {
    PairProfileView()
        .environmentObject(AuthenticationService(isFirebaseEnabled: false))
        .environmentObject(FirestoreService(isFirebaseEnabled: false))
        .environmentObject(StorageService(isFirebaseEnabled: false))
        .environmentObject(LocalPairingService())
}
