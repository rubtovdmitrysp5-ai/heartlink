import Foundation
import Observation
import LocalAuthentication

@MainActor
@Observable
final class SecurityService {
    var isLocked = false
    var privateModeEnabled = false
    var passcode = ""
    var failedReason: String?

    func unlockWithBiometrics() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            failedReason = "Face ID недоступен. Введите код-пароль."
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Разблокируйте личное пространство HeartLink."
            )
            isLocked = !success
            failedReason = success ? nil : "Не удалось разблокировать."
        } catch {
            failedReason = "Не удалось подтвердить личность."
        }
    }

    func unlockWithPasscode(_ enteredPasscode: String) {
        let normalized = enteredPasscode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !passcode.isEmpty else {
            guard !normalized.isEmpty else {
                failedReason = "Введите код-пароль."
                return
            }
            passcode = normalized
            isLocked = false
            failedReason = nil
            return
        }

        if normalized == passcode {
            isLocked = false
            failedReason = nil
        } else {
            failedReason = "Код-пароль не совпадает."
        }
    }

    func lock() {
        isLocked = true
    }
}
