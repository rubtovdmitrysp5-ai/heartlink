import Foundation
import Combine
import FirebaseStorage

@MainActor
final class StorageService: ObservableObject {
    private let isFirebaseEnabled: Bool

    init(isFirebaseEnabled: Bool) {
        self.isFirebaseEnabled = isFirebaseEnabled
    }

    func uploadImageData(_ data: Data?, path: String) async throws -> URL? {
        guard let data else {
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
