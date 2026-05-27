import Foundation
import Combine

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var title = ""
    @Published var note = ""
    @Published var locationName = ""
    @Published var date = Date()
    @Published var isSaving = false
    @Published var errorMessage: String?

    func configure(with memory: Memory) {
        title = memory.title
        note = memory.note
        locationName = memory.locationName
        date = memory.date
    }

    func save(imageData: Data?, firestoreService: FirestoreService, storageService: StorageService, userId: String) async -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Введите название воспоминания."
            return false
        }
        isSaving = true
        defer { isSaving = false }

        let didSave = await firestoreService.addMemoryWithImageData(
            title: title,
            note: note,
            locationName: locationName.isEmpty ? "Без места" : locationName,
            date: date,
            imageData: imageData,
            storageService: storageService,
            userId: userId
        )

        if didSave {
            title = ""
            note = ""
            locationName = ""
            date = .now
        } else {
            errorMessage = firestoreService.lastErrorMessage ?? "Не удалось сохранить воспоминание."
        }

        return didSave
    }

    func update(memory: Memory, using service: FirestoreService) async -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Введите название воспоминания."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let didSave = await service.updateMemory(
            memory,
            title: title,
            note: note,
            locationName: locationName,
            date: date
        )

        if !didSave {
            errorMessage = service.lastErrorMessage ?? "Не удалось обновить воспоминание."
        }

        return didSave
    }
}
