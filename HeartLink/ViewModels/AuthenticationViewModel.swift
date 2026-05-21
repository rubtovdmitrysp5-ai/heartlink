import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    var name = ""
    var email = ""
    var password = ""
    var isCreatingAccount = false
    var isLoading = false
    var errorMessage: String?

    func submit(using service: AuthenticationService) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isCreatingAccount {
                try await service.createAccount(name: name, email: email, password: password)
            } else {
                try await service.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = "Не удалось войти. Проверьте данные и попробуйте ещё раз."
        }
    }
}
