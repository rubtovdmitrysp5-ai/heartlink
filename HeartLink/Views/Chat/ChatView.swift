import AVFoundation
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
    @State private var cropItem: ImageCropItem?
    @State private var openedImage: OpenedChatImage?
    @State private var oneTimeImage: OneTimeImageItem?
    @State private var imageSendMode = ChatImageSendMode.normal
    @State private var oneTimeDuration: TimeInterval = 10
    @StateObject private var voicePlayer = VoiceMessagePlayer()

    var body: some View {
        ZStack {
            RomanticBackground()

            VStack(spacing: 0) {
                ChatHeader(partner: firestoreService.partner, isSyncing: firestoreService.isSyncing)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(firestoreService.messages.enumerated()), id: \.element.id) { index, message in
                                messageRow(message, index: index)
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

                composer
            }
        }
        .navigationTitle("Р›РёС‡РЅС‹Р№ С‡Р°С‚")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onClose()
                } label: {
                    Label("Р—Р°РєСЂС‹С‚СЊ", systemImage: "chevron.left")
                }
            }
        }
        .task {
            while !Task.isCancelled {
                await firestoreService.refreshLocalCoupleData()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        .onDisappear {
            voicePlayer.stop()
            if viewModel.isRecordingVoice {
                viewModel.cancelVoiceRecording()
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }

            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    cropItem = ImageCropItem(imageData: data, title: "РљР°РґСЂРёСЂРѕРІР°С‚СЊ С„РѕС‚Рѕ", aspectRatio: 0.8, maxPixelSize: 1600)
                }
                selectedPhoto = nil
            }
        }
        .sheet(item: $cropItem) { item in
            ImageCropSheet(item: item) { croppedData in
                cropItem = nil
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    viewModel.selectedImageData = croppedData
                }
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
                    mode: $imageSendMode,
                    oneTimeDuration: $oneTimeDuration,
                    send: {
                        Task {
                            await viewModel.sendImage(
                                imageData,
                                firestoreService: firestoreService,
                                storageService: storageService,
                                coupleId: firestoreService.couple.id,
                                authorId: currentUser.id,
                                isOneTime: imageSendMode == .oneTime,
                                oneTimeDuration: oneTimeDuration
                            )
                            if viewModel.selectedImageData == nil {
                                imageSendMode = .normal
                                oneTimeDuration = 10
                            }
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
        .fullScreenCover(item: $oneTimeImage) { item in
            OneTimePhotoView(
                message: item.message,
                currentUserId: currentUser.id,
                onViewed: {
                    Task {
                        await firestoreService.markOneTimeMessageViewed(item.message, userId: currentUser.id)
                    }
                }
            )
        }
        .alert("\u{041E}\u{0448}\u{0438}\u{0431}\u{043A}\u{0430}", isPresented: errorAlertBinding) {
            Button("\u{041F}\u{043E}\u{043D}\u{044F}\u{0442}\u{043D}\u{043E}", role: .cancel) {
                viewModel.errorMessage = nil
                firestoreService.lastErrorMessage = nil
            }
        } message: {
            Text(errorAlertMessage)
        }
    }

    private var composer: some View {
        ChatComposer(
            draft: $viewModel.draft,
            selectedPhoto: $selectedPhoto,
            isSending: viewModel.isSending || viewModel.isUploadingImage,
            isRecordingVoice: viewModel.isRecordingVoice,
            sendText: {
                Task {
                    if viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await viewModel.toggleVoiceRecording(
                            using: firestoreService,
                            storageService: storageService,
                            coupleId: firestoreService.couple.id,
                            authorId: currentUser.id
                        )
                    } else {
                        await viewModel.send(using: firestoreService, coupleId: firestoreService.couple.id, authorId: currentUser.id)
                    }
                }
            },
            hasRetryableVoice: viewModel.retryableVoiceRecording != nil,
            retryVoice: {
                Task {
                    await viewModel.retryVoiceMessage(
                        using: firestoreService,
                        storageService: storageService,
                        coupleId: firestoreService.couple.id,
                        authorId: currentUser.id
                    )
                }
            },
            cancelRecording: {
                viewModel.cancelVoiceRecording()
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || firestoreService.lastErrorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil; firestoreService.lastErrorMessage = nil } }
        )
    }

    private var errorAlertMessage: String {
        viewModel.errorMessage ?? firestoreService.lastErrorMessage ?? "\u{041D}\u{0435} \u{0443}\u{0434}\u{0430}\u{043B}\u{043E}\u{0441}\u{044C} \u{0432}\u{044B}\u{043F}\u{043E}\u{043B}\u{043D}\u{0438}\u{0442}\u{044C} \u{0434}\u{0435}\u{0439}\u{0441}\u{0442}\u{0432}\u{0438}\u{0435}\u{002E}"
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage, index: Int) -> some View {
        if shouldShowDate(before: message, at: index) {
            MessageDayDivider(date: message.sentAt)
        }

        MessageBubble(
            message: message,
            isMine: message.authorId == currentUser.id,
            currentUserId: currentUser.id,
            isPlayingVoice: voicePlayer.playingMessageId == message.id,
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
            },
            onOpenOneTimeImage: {
                oneTimeImage = OneTimeImageItem(message: message)
            },
            onPlayVoice: {
                voicePlayer.togglePlayback(for: message)
            }
        )
        .id(message.id)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    await firestoreService.deleteMessage(message)
                }
            } label: {
                Label("\u{0423}\u{0434}\u{0430}\u{043B}\u{0438}\u{0442}\u{044C}", systemImage: "trash")
            }
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

private struct OneTimeImageItem: Identifiable {
    let message: ChatMessage
    var id: String { message.id }
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
    let currentUserId: String
    let isPlayingVoice: Bool
    let onReact: (String) -> Void
    let onDelete: () -> Void
    let onOpenImage: (URL) -> Void
    let onOpenOneTimeImage: () -> Void
    let onPlayVoice: () -> Void

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
                        Button("\u{2764}\u{FE0F}") { onReact("\u{2764}\u{FE0F}") }
                        Button("\u{1F525}") { onReact("\u{1F525}") }
                        Button("\u{1F970}") { onReact("\u{1F970}") }
                        Button("\u{2728}") { onReact("\u{2728}") }
                        Divider()
                        Button("РЈРґР°Р»РёС‚СЊ", role: .destructive) { onDelete() }
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
            imageContent
        case .voice:
            Button(action: onPlayVoice) {
                HStack(spacing: 10) {
                    Image(systemName: isPlayingVoice ? "pause.fill" : "play.fill")
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
            .buttonStyle(.plain)
        }
    }

    private var imageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.isOneTime == true {
                oneTimeImageContent
            } else {
                regularImageContent
            }

            Text(message.text)
                .font(.subheadline)
        }
    }

    private var regularImageContent: some View {
        AsyncImage(url: message.mediaURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                unavailableImagePlaceholder
            default:
                loadingImagePlaceholder
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
    }

    private var oneTimeImageContent: some View {
        let viewed = message.wasViewed(by: currentUserId)
        return ZStack {
            if viewed {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.16))
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash.fill")
                    Text("Р¤РѕС‚Рѕ СѓР¶Рµ РїСЂРѕСЃРјРѕС‚СЂРµРЅРѕ")
                        .font(.caption.weight(.semibold))
                }
            } else {
                AsyncImage(url: message.mediaURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 18)
                    case .failure:
                        unavailableImagePlaceholder
                    default:
                        loadingImagePlaceholder
                    }
                }
                VStack(spacing: 8) {
                    Image(systemName: "1.circle.fill")
                        .font(.title2)
                    Text("РћРґРёРЅ РїСЂРѕСЃРјРѕС‚СЂ")
                        .font(.caption.weight(.bold))
                    Text("\(Int(message.oneTimeDuration ?? 10)) СЃРµРє.")
                        .font(.caption2)
                }
                .padding(10)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            }
        }
        .frame(width: 220, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            if !viewed {
                onOpenOneTimeImage()
            }
        }
    }

    private var unavailableImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(0.22))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Р¤РѕС‚Рѕ РЅРµРґРѕСЃС‚СѓРїРЅРѕ")
                        .font(.caption)
                }
            }
    }

    private var loadingImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(0.22))
            .overlay {
                ProgressView()
                    .tint(isMine ? .white : .pink)
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
    let hasRetryableVoice: Bool
    let retryVoice: () -> Void
    let cancelRecording: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if isRecordingVoice {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("РРґС‘С‚ Р·Р°РїРёСЃСЊ. РќР°Р¶РјРёС‚Рµ РјРёРєСЂРѕС„РѕРЅ РµС‰С‘ СЂР°Р·, С‡С‚РѕР±С‹ РѕС‚РїСЂР°РІРёС‚СЊ.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Р С›РЎвЂљР СР ВµР Р…Р В°", action: cancelRecording)
                        .font(.caption.weight(.semibold))
                }
            }

            if hasRetryableVoice {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .foregroundStyle(.orange)
                    Text("Р вЂњР С•Р В»Р С•РЎРѓР С•Р Р†Р С•Р Вµ Р Р…Р Вµ Р С•РЎвЂљР С—РЎР‚Р В°Р Р†Р С‘Р В»Р С•РЎРѓРЎРЉ. Р СљР С•Р В¶Р Р…Р С• Р С—Р С•Р С—РЎР‚Р С•Р В±Р С•Р Р†Р В°РЎвЂљРЎРЉ Р ВµРЎвЂ°РЎвЂ РЎР‚Р В°Р В·.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Р СџР С•Р Р†РЎвЂљР С•РЎР‚Р С‘РЎвЂљРЎРЉ", action: retryVoice)
                        .font(.caption.weight(.bold))
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
                .accessibilityLabel("Р’С‹Р±СЂР°С‚СЊ С„РѕС‚Рѕ")

                TextField("РќР°РїРёС€РёС‚Рµ РЅРµР¶РЅРѕРµ СЃРѕРѕР±С‰РµРЅРёРµ", text: $draft, axis: .vertical)
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
                .accessibilityLabel(draft.isEmpty ? "Р“РѕР»РѕСЃРѕРІРѕРµ СЃРѕРѕР±С‰РµРЅРёРµ" : "РћС‚РїСЂР°РІРёС‚СЊ")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

@MainActor
private final class VoiceMessagePlayer: ObservableObject {
    @Published private(set) var playingMessageId: String?

    private var player: AVPlayer?
    private var finishObserver: NSObjectProtocol?

    func togglePlayback(for message: ChatMessage) {
        guard let url = message.mediaURL else { return }

        if playingMessageId == message.id {
            stop()
            return
        }

        stop()

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        playingMessageId = message.id

        finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }

        player.play()
    }

    func stop() {
        player?.pause()
        player = nil
        playingMessageId = nil

        if let finishObserver {
            NotificationCenter.default.removeObserver(finishObserver)
            self.finishObserver = nil
        }
    }

    deinit {
        if let finishObserver {
            NotificationCenter.default.removeObserver(finishObserver)
        }
    }
}

private struct ImagePreviewSheet: View {
    let imageData: Data
    let isSending: Bool
    @Binding var mode: ChatImageSendMode
    @Binding var oneTimeDuration: TimeInterval
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
                        EmptyStateView(title: "Р¤РѕС‚Рѕ РЅРµ РѕС‚РєСЂС‹Р»РѕСЃСЊ", subtitle: "Р’С‹Р±РµСЂРёС‚Рµ РґСЂСѓРіРѕРµ РёР·РѕР±СЂР°Р¶РµРЅРёРµ.", systemImage: "photo")
                            .padding(16)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Р РµР¶РёРј С„РѕС‚Рѕ", selection: $mode) {
                                ForEach(ChatImageSendMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            if mode == .oneTime {
                                Picker("Р’СЂРµРјСЏ РїСЂРѕСЃРјРѕС‚СЂР°", selection: $oneTimeDuration) {
                                    Text("5 СЃРµРє").tag(TimeInterval(5))
                                    Text("10 СЃРµРє").tag(TimeInterval(10))
                                    Text("15 СЃРµРє").tag(TimeInterval(15))
                                }
                                .pickerStyle(.segmented)

                                Text("Р¤РѕС‚Рѕ Р±СѓРґРµС‚ Р·Р°Р±Р»СЋСЂРµРЅРѕ РІ С‡Р°С‚Рµ Рё РѕС‚РєСЂРѕРµС‚СЃСЏ С‚РѕР»СЊРєРѕ РѕРґРёРЅ СЂР°Р·.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    PrimaryActionButton(title: "РћС‚РїСЂР°РІРёС‚СЊ С„РѕС‚Рѕ", systemImage: "paperplane.fill", isLoading: isSending, action: send)
                        .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("РџСЂРµРґРїСЂРѕСЃРјРѕС‚СЂ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("РћС‚РјРµРЅР°", action: cancel)
                }
            }
        }
    }
}

private enum ChatImageSendMode: String, CaseIterable, Identifiable {
    case normal
    case oneTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "РћР±С‹С‡РЅРѕРµ"
        case .oneTime: "РћРґРёРЅ СЂР°Р·"
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
                    EmptyStateView(title: "Р¤РѕС‚Рѕ РЅРµРґРѕСЃС‚СѓРїРЅРѕ", subtitle: "РџСЂРѕРІРµСЂСЊС‚Рµ СЃРµСЂРІРµСЂ Рё РїРѕРґРєР»СЋС‡РµРЅРёРµ.", systemImage: "photo")
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

private struct OneTimePhotoView: View {
    let message: ChatMessage
    let currentUserId: String
    let onViewed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var secondsLeft: Int
    @State private var isScreenCaptured = UIScreen.main.isCaptured

    init(message: ChatMessage, currentUserId: String, onViewed: @escaping () -> Void) {
        self.message = message
        self.currentUserId = currentUserId
        self.onViewed = onViewed
        _secondsLeft = State(initialValue: Int(message.oneTimeDuration ?? 10))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if isScreenCaptured {
                VStack(spacing: 14) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 52))
                    Text("Р¤РѕС‚Рѕ СЃРєСЂС‹С‚Рѕ РІРѕ РІСЂРµРјСЏ Р·Р°РїРёСЃРё СЌРєСЂР°РЅР°")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(24)
            } else if let url = message.mediaURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .failure:
                        EmptyStateView(title: "Р¤РѕС‚Рѕ РЅРµРґРѕСЃС‚СѓРїРЅРѕ", subtitle: "РџСЂРѕРІРµСЂСЊС‚Рµ СЃРµСЂРІРµСЂ Рё РїРѕРґРєР»СЋС‡РµРЅРёРµ.", systemImage: "photo")
                            .padding(24)
                    default:
                        ProgressView()
                            .tint(.white)
                    }
                }
            }

            HStack(spacing: 12) {
                Label("\(secondsLeft) СЃРµРє.", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(20)
        }
        .onAppear {
            onViewed()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isScreenCaptured = UIScreen.main.isCaptured
        }
        .task {
            while secondsLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                secondsLeft -= 1
            }
            dismiss()
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
