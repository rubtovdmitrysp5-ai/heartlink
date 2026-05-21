import Foundation
import Combine

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var title = ""
    @Published var note = ""
    @Published var locationName = ""
    @Published var isSaving = false

    func save(imageData: Data?, firestoreService: FirestoreService, storageService: StorageService, coupleId: String, userId: String) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        let imageURL = try? await storageService.uploadImageData(
            imageData,
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
    }
}
