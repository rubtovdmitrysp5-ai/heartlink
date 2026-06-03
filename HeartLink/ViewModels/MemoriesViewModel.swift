import Foundation
import Combine
import CoreLocation
import MapKit

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
        let coordinate = await resolveCoordinate(for: place)
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

    private func resolveCoordinate(for locationName: String) async -> CLLocationCoordinate2D? {
        guard !locationName.isEmpty, locationName != "Без места" else { return nil }
        if let placemarks = try? await CLGeocoder().geocodeAddressString(locationName),
           let coordinate = placemarks.first?.location?.coordinate {
            return coordinate
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationName
        request.resultTypes = .pointOfInterest
        let response = try? await MKLocalSearch(request: request).start()
        return response?.mapItems.first?.placemark.coordinate
    }

    func update(memory: Memory, using service: FirestoreService) async -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Введите название воспоминания."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let place = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let coordinate = await resolveCoordinate(for: place)
        let didSave = await service.updateMemory(
            memory,
            title: title,
            note: note,
            locationName: place,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            date: date
        )

        if !didSave {
            errorMessage = service.lastErrorMessage ?? "Не удалось обновить воспоминание."
        }

        return didSave
    }
}
