import PhotosUI
import SwiftUI

struct ChatView: View {
    let currentUser: UserProfile

    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var storageService: StorageService
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack {
            RomanticBackground()

            VStack(spacing: 0) {
                ChatHeader(partner: firestoreService.partner)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(firestoreService.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isMine: message.authorId == currentUser.id,
                                    onReact: { emoji in
                                        Task {
                                            await viewModel.react(emoji, message: message, using: firestoreService, authorId: currentUser.id)
                                        }
                                    }
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: firestoreService.messages.count) { _, _ in
                        if let last = firestoreService.messages.last {
                            withAnimation(.smooth(duration: 0.25)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                ChatComposer(
                    draft: $viewModel.draft,
                    selectedPhoto: $selectedPhoto,
                    sendText: {
                        Task {
                            if viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                await viewModel.sendVoicePreview(using: firestoreService, coupleId: firestoreService.couple.id, authorId: currentUser.id)
                            } else {
                                await viewModel.send(using: firestoreService, coupleId: firestoreService.couple.id, authorId: currentUser.id)
                            }
                        }
                    }
                )
            }
        }
        .navigationTitle("Личный чат")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                await viewModel.sendImage(
                    newValue,
                    firestoreService: firestoreService,
                    storageService: storageService,
                    coupleId: firestoreService.couple.id,
                    authorId: currentUser.id
                )
                selectedPhoto = nil
            }
        }
    }
}

private struct ChatHeader: View {
    let partner: UserProfile

    var body: some View {
        HStack(spacing: 12) {
            Text(String(partner.displayName.prefix(1)))
                .font(.headline.bold())
                .frame(width: 42, height: 42)
                .foregroundStyle(.white)
                .background(.indigo.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(partner.displayName)
                    .font(.headline)
                Label(partner.currentMood.partnerTitle, systemImage: partner.currentMood.symbolName)
                    .font(.caption)
                    .foregroundStyle(partner.currentMood.tint)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.regularMaterial, in: Circle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let onReact: (String) -> Void

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                bubbleContent
                    .padding(12)
                    .foregroundStyle(isMine ? .white : .primary)
                    .background(
                        isMine
                            ? AnyShapeStyle(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(.ultraThinMaterial),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )

                HStack(spacing: 6) {
                    ForEach(message.reactions) { reaction in
                        Text(reaction.emoji)
                            .font(.caption)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.regularMaterial, in: Capsule())
                    }

                    Menu {
                        Button("Сердце ❤️") { onReact("❤️") }
                        Button("Огонь 🔥") { onReact("🔥") }
                        Button("Нежность 🥰") { onReact("🥰") }
                        Button("Искра ✨") { onReact("✨") }
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !isMine { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.kind {
        case .text:
            Text(message.text)
                .font(.body)
        case .image:
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: message.mediaURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.22))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                            }
                    }
                }
                .frame(width: 210, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(message.text)
                    .font(.subheadline)
            }
        case .voice:
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.caption.bold())
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(isMine ? 0.22 : 0.14), in: Circle())

                Capsule()
                    .fill(.white.opacity(isMine ? 0.5 : 0.22))
                    .frame(width: 118, height: 5)

                Text(durationText(message.voiceDuration ?? 0))
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return "0:\(String(format: "%02d", seconds))"
    }
}

private struct ChatComposer: View {
    @Binding var draft: String
    @Binding var selectedPhoto: PhotosPickerItem?
    let sendText: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Отправить фото")

            TextField("Напишите нежное сообщение", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                sendText()
            } label: {
                Image(systemName: draft.isEmpty ? "mic.fill" : "paperplane.fill")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(draft.isEmpty ? "Записать голосовое" : "Отправить")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    NavigationStack {
        ChatView(currentUser: .sample)
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
            .environmentObject(StorageService(isFirebaseEnabled: false))
    }
}
