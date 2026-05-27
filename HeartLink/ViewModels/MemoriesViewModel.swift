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

        await firestoreService.addMemoryWithImageData(
            title: title,
            note: note,
            locationName: locationName.isEmpty ? "Без места" : locationName,
            imageData: imageData,
            storageService: storageService,
            userId: userId
        )

        title = ""
        note = ""
        locationName = ""
    }
}
