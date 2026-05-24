import Foundation
import Combine

@MainActor
final class PairingViewModel: ObservableObject {
    @Published var partnerCode = ""
    @Published var displayName = ""
    @Published var partnerName = ""
    @Published var relationshipStartedAt = Calendar.current.date(byAdding: .day, value: -100, to: .now) ?? .now
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage = "Подготовка личного кода..."

    func prepare(using service: LocalPairingService) async {
        await service.startSession()
        statusMessage = service.isServerReachable ? "Сервер подключен" : "Сервер недоступен. Можно создать тестового партнера."
    }

    func linkPartner(using service: LocalPairingService) async {
        guard !partnerCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Введите код партнера."
            return
        }

        await run {
            statusMessage = "Ищем партнера..."
            try await service.linkPartner(code: partnerCode)
            statusMessage = "Партнер найден"
        }
    }

    func createTestPartner(using service: LocalPairingService) async {
        await run {
            statusMessage = "Создаем тестового партнера..."
            try await service.createTestPartner()
            statusMessage = "Тестовый партнер создан"
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
            if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
                errorMessage = description
            } else {
                errorMessage = "Не удалось выполнить действие. Проверьте, что iPhone и ПК в одной Wi-Fi сети, а сервер запущен."
            }
        }
    }
}
