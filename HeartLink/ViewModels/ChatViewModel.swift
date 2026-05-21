import Foundation
import Observation
import PhotosUI

@MainActor
@Observable
final class ChatViewModel {
    var draft = ""
    var selectedReactionMessageId: String?

    func send(using service: FirestoreService, coupleId: String, authorId: String) async {
        let text = draft
        draft = ""
        await service.sendTextMessage(text, coupleId: coupleId, authorId: authorId)
    }

    func sendVoicePreview(using service: FirestoreService, coupleId: String, authorId: String) async {
        await service.sendVoicePreviewMessage(coupleId: coupleId, authorId: authorId)
    }

    func sendImage(
        _ item: PhotosPickerItem?,
        firestoreService: FirestoreService,
        storageService: StorageService,
        coupleId: String,
        authorId: String
    ) async {
        let imageURL = try? await storageService.uploadImage(
            item,
            path: "couples/\(coupleId)/messages/\(UUID().uuidString).jpg"
        )
        await firestoreService.sendImageMessage(imageURL: imageURL, coupleId: coupleId, authorId: authorId)
    }

    func react(_ emoji: String, message: ChatMessage, using service: FirestoreService, authorId: String) async {
        await service.addReaction(emoji, to: message, authorId: authorId)
        selectedReactionMessageId = nil
    }
}
