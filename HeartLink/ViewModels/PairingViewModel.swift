import Foundation
import Combine

@MainActor
final class PairingViewModel: ObservableObject {
    @Published var partnerCode = ""
    @Published var displayName = ""
    @Published var partnerName = ""
    @Published var relationshipStartedAt = Calendar.current.date(byAdding: .day, value: -100, to: .now) ?? .now
    @Published var serverURL = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func prepare(using service: LocalPairingService) async {
        serverURL = service.baseURLString
        await service.startSession()
    }

    func saveServerURL(using service: LocalPairingService) async {
        service.updateBaseURL(serverURL)
        if service.session == nil {
            await service.startSession()
        }
    }

    func linkPartner(using service: LocalPairingService) async {
        guard !partnerCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Введите код партнера."
            return
        }

        await run {
            await saveServerURL(using: service)
            try await service.linkPartner(code: partnerCode)
        }
    }

    func createTestPartner(using service: LocalPairingService) async {
        await run {
            await saveServerURL(using: service)
            try await service.createTestPartner()
        }
    }

    func completeSetup(using service: LocalPairingService) async {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Введите свое имя."
            return
        }

        guard !partnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Введите имя партнера."
            return
        }

        await run {
            try await service.completeSetup(
                displayName: displayName,
                partnerName: partnerName,
                startedAt: relationshipStartedAt
            )
        }
    }

    private func run(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = "Не удалось выполнить действие. Проверьте адрес сервера и подключение."
        }
    }
}
