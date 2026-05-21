import Foundation
import Combine
import PhotosUI

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var title = ""
    @Published var note = ""
    @Published var locationName = ""
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var isSaving = false

    func save(firestoreService: FirestoreService, storageService: StorageService, coupleId: String, userId: String) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        let imageURL = try? await storageService.uploadImage(
            selectedPhoto,
            path: "couples/\(coupleId)/memories/\(UUID().uuidString).jpg"
        )

        await firestoreService.addMemory(
            title: title,
            note: note,
            locationName: locationName.isEmpty ? "Без места" : locationName,
            imageURL: imageURL,
            userId: userId
        )

        title = ""
        note = ""
        locationName = ""
        selectedPhoto = nil
    }
}
