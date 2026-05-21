import Foundation
import Combine

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var isCreatingAccount = false
    @Published var isLoading = false
    @Published var errorMessage: String?

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
