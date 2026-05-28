import Foundation
import Combine
import CoreLocation

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

        let place = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let coordinate = await geocode(place)
        let didSave = await firestoreService.addMemoryWithImageData(
            title: title,
            note: note,
            locationName: place.isEmpty ? "Без места" : place,
            date: date,
            imageData: imageData,
            storageService: storageService,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
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

    private func geocode(_ locationName: String) async -> CLLocationCoordinate2D? {
        guard !locationName.isEmpty, locationName != "Без места" else { return nil }
        let placemarks = try? await CLGeocoder().geocodeAddressString(locationName)
        return placemarks?.first?.location?.coordinate
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
