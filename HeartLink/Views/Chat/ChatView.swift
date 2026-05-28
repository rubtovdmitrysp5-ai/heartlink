import PhotosUI
import SwiftUI
import UIKit

struct ChatView: View {
    let currentUser: UserProfile
    var onClose: () -> Void = {}

    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var storageService: StorageService
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var openedImage: OpenedChatImage?

    var body: some View {
        ZStack {
            RomanticBackground()

            VStack(spacing: 0) {
                ChatHeader(partner: firestoreService.partner, isSyncing: firestoreService.isSyncing)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(firestoreService.messages.enumerated()), id: \.element.id) { index, message in
                                if shouldShowDate(before: message, at: index) {
                                    MessageDayDivider(date: message.sentAt)
                                }

                                MessageBubble(
                                    message: message,
                                    isMine: message.authorId == currentUser.id,
                                    onReact: { emoji in
                                        Task {
                                            await viewModel.react(emoji, message: message, using: firestoreService, authorId: currentUser.id)
                                        }
                                    },
                                    onDelete: {
                                        Task {
                                            await firestoreService.deleteMessage(message)
                                        }
                                    },
                                    onOpenImage: { url in
                                        openedImage = OpenedChatImage(url: url)
                                    }
                                )
                                .id(message.id)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await firestoreService.deleteMessage(message)
                                        }
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        scrollToLastMessage(with: proxy, animated: false)
                    }
                    .onChange(of: firestoreService.messages.count) { _, _ in
                        scrollToLastMessage(with: proxy, animated: true)
                    }
                }

                ChatComposer(
                    draft: $viewModel.draft,
                    selectedPhoto: $selectedPhoto,
                    isSending: viewModel.isSending || viewModel.isUploadingImage,
                    isRecordingVoice: viewModel.isRecordingVoice,
                    sendText: {
                        Task {
                            if viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                await viewModel.toggleVoiceRecording(using: firestoreService, coupleId: firestoreService.couple.id, authorId: currentUser.id)
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onClose()
                } label: {
                    Label("Закрыть", systemImage: "chevron.left")
                }
            }
        }
        .task {
            while !Task.isCancelled {
                await firestoreService.refreshLocalCoupleData()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }

            Task {
                viewModel.selectedImageData = try? await newValue.loadTransferable(type: Data.self)
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.selectedImageData != nil },
            set: { if !$0 { viewModel.selectedImageData = nil } }
        )) {
            if let imageData = viewModel.selectedImageData {
                ImagePreviewSheet(
                    imageData: imageData,
                    isSending: viewModel.isUploadingImage,
                    send: {
                        Task {
                            await viewModel.sendImage(
                                imageData,
                                firestoreService: firestoreService,
                                storageService: storageService,
                                coupleId: firestoreService.couple.id,
                                authorId: currentUser.id
                            )
                        }
                    },
                    cancel: {
                        viewModel.selectedImageData = nil
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(item: $openedImage) { image in
            FullScreenPhotoView(url: image.url)
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil || firestoreService.lastErrorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil; firestoreService.lastErrorMessage = nil } }
        )) {
            Button("Понятно", role: .cancel) {
                viewModel.errorMessage = nil
                firestoreService.lastErrorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? firestoreService.lastErrorMessage ?? "Не удалось выполнить действие.")
        }
    }

    private func shouldShowDate(before message: ChatMessage, at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = firestoreService.messages[index - 1]
        return !Calendar.current.isDate(previous.sentAt, inSameDayAs: message.sentAt)
    }

    private func scrollToLastMessage(with proxy: ScrollViewProxy, animated: Bool) {
        guard let last = firestoreService.messages.last else { return }
        let action = {
            proxy.scrollTo(last.id, anchor: .bottom)
        }

        if animated {
            withAnimation(.smooth(duration: 0.25)) {
                action()
            }
        } else {
            action()
        }
    }
}

private struct OpenedChatImage: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ChatHeader: View {
    let partner: UserProfile
    let isSyncing: Bool

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

            if isSyncing {
                ProgressView()
                    .controlSize(.small)
                    .tint(.pink)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.regularMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

private struct MessageDayDivider: View {
    let date: Date

    var body: some View {
        Text(date.heartLinkShortDate)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .padding(.vertical, 4)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let onReact: (String) -> Void
    let onDelete: () -> Void
    let onOpenImage: (URL) -> Void

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
                        Button("❤️") { onReact("❤️") }
                        Button("🔥") { onReact("🔥") }
                        Button("🥰") { onReact("🥰") }
                        Button("✨") { onReact("✨") }
                        Divider()
                        Button("Удалить", role: .destructive) { onDelete() }
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(message.sentAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                    case .failure:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.22))
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                    Text("Фото недоступно")
                                        .font(.caption)
                                }
                            }
                    default:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.22))
                            .overlay {
                                ProgressView()
                                    .tint(isMine ? .white : .pink)
                            }
                    }
                }
                .frame(width: 220, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture {
                    if let url = message.mediaURL {
                        onOpenImage(url)
                    }
                }

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
    let isSending: Bool
    let isRecordingVoice: Bool
    let sendText: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if isRecordingVoice {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("Идёт запись. Нажмите микрофон ещё раз, чтобы отправить.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.headline)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .disabled(isSending || isRecordingVoice)
                .accessibilityLabel("Выбрать фото")

                TextField("Напишите нежное сообщение", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .disabled(isSending || isRecordingVoice)

                Button {
                    sendText()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRecordingVoice ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: isRecordingVoice ? "stop.fill" : (draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "paperplane.fill"))
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(isSending)
                .accessibilityLabel(draft.isEmpty ? "Голосовое сообщение" : "Отправить")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

private struct ImagePreviewSheet: View {
    let imageData: Data
    let isSending: Bool
    let send: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                RomanticBackground()

                VStack(spacing: 16) {
                    if let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 440)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .padding(.horizontal, 16)
                    } else {
                        EmptyStateView(title: "Фото не открылось", subtitle: "Выберите другое изображение.", systemImage: "photo")
                            .padding(16)
                    }

                    PrimaryActionButton(title: "Отправить фото", systemImage: "paperplane.fill", isLoading: isSending, action: send)
                        .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Предпросмотр")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: cancel)
                }
            }
        }
    }
}

private struct FullScreenPhotoView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    EmptyStateView(title: "Фото недоступно", subtitle: "Проверьте сервер и подключение.", systemImage: "photo")
                        .padding(24)
                default:
                    ProgressView()
                        .tint(.white)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(20)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(currentUser: .sample)
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
            .environmentObject(StorageService(isFirebaseEnabled: false))
    }
}
