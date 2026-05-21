import Foundation
import Observation
import FirebaseStorage
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class StorageService {
    private let isFirebaseEnabled: Bool

    init(isFirebaseEnabled: Bool) {
        self.isFirebaseEnabled = isFirebaseEnabled
    }

    func uploadImage(_ item: PhotosPickerItem?, path: String) async throws -> URL? {
        guard let item, let data = try await item.loadTransferable(type: Data.self) else {
            return nil
        }

        guard isFirebaseEnabled else {
            return nil
        }

        let reference = Storage.storage().reference().child(path)
        _ = try await reference.putDataAsync(data, metadata: nil)
        return try await reference.downloadURL()
    }
}
