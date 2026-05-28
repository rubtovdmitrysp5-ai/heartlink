import Foundation
import Combine
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draft = ""
    @Published var selectedReactionMessageId: String?
    @Published var selectedImageData: Data?
    @Published var isSending = false
    @Published var isUploadingImage = false
    @Published var isRecordingVoice = false
    @Published var errorMessage: String?
    private let voiceRecorder = VoiceRecorder()

    func send(using service: FirestoreService, coupleId: String, authorId: String) async {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        draft = ""
        isSending = true
        let didSend = await service.sendTextMessage(text, coupleId: coupleId, authorId: authorId)
        isSending = false

        if !didSend {
            draft = text
            errorMessage = service.lastErrorMessage ?? "Не удалось отправить сообщение."
        }
    }

    func toggleVoiceRecording(using service: FirestoreService, storageService: StorageService, coupleId: String, authorId: String) async {
        if isRecordingVoice {
            do {
                let recording = try voiceRecorder.stop()
                isRecordingVoice = false
                isSending = true
                let didSend = await service.sendVoiceData(
                    recording.data,
                    duration: recording.duration,
                    storageService: storageService,
                    coupleId: coupleId,
                    authorId: authorId
                )
                isSending = false
                if !didSend {
                    errorMessage = service.lastErrorMessage ?? "Голосовое не отправилось."
                }
            } catch {
                isRecordingVoice = false
                isSending = false
                errorMessage = "Не удалось сохранить голосовое."
            }
        } else {
            do {
                try await voiceRecorder.start()
                isRecordingVoice = true
            } catch {
                errorMessage = "Разрешите доступ к микрофону в настройках iPhone."
            }
        }
    }

    func cancelVoiceRecording() {
        voiceRecorder.cancel()
        isRecordingVoice = false
    }

    func sendImage(
        _ imageData: Data?,
        firestoreService: FirestoreService,
        storageService: StorageService,
        coupleId: String,
        authorId: String,
        isOneTime: Bool = false,
        oneTimeDuration: TimeInterval? = nil
    ) async {
        guard let imageData else {
            errorMessage = "Не удалось прочитать фото."
            return
        }

        isUploadingImage = true
        let compressedData = Self.compressImageData(imageData) ?? imageData
        let didSend = await firestoreService.sendImageData(
            compressedData,
            storageService: storageService,
            coupleId: coupleId,
            authorId: authorId,
            isOneTime: isOneTime,
            oneTimeDuration: oneTimeDuration
        )
        isUploadingImage = false

        if didSend {
            selectedImageData = nil
        } else {
            errorMessage = firestoreService.lastErrorMessage ?? "Фото не отправилось."
        }
    }

    func react(_ emoji: String, message: ChatMessage, using service: FirestoreService, authorId: String) async {
        await service.addReaction(emoji, to: message, authorId: authorId)
        selectedReactionMessageId = nil
    }

    private static func compressImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 1600
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resized.jpegData(compressionQuality: 0.78)
    }
}
