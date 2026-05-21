import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var authenticationService: AuthenticationService
    @StateObject private var viewModel = AuthenticationViewModel()

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 68, weight: .semibold))
                            .foregroundStyle(.white, .pink)
                            .symbolEffect(.pulse)
                        Text("HeartLink")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text(viewModel.isCreatingAccount ? "Создайте пространство для двоих" : "Войдите в ваше пространство")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 52)

                    GlassCard {
                        VStack(spacing: 14) {
                            if viewModel.isCreatingAccount {
                                TextField("Ваше имя", text: $viewModel.name)
                                    .textContentType(.name)
                                    .heartLinkTextField()
                            }

                            TextField("Эл. почта", text: $viewModel.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .heartLinkTextField()

                            SecureField("Пароль", text: $viewModel.password)
                                .textContentType(viewModel.isCreatingAccount ? .newPassword : .password)
                                .heartLinkTextField()

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            PrimaryActionButton(
                                title: viewModel.isCreatingAccount ? "Создать аккаунт" : "Войти",
                                systemImage: "arrow.right.circle.fill",
                                isLoading: viewModel.isLoading
                            ) {
                                Task {
                                    await viewModel.submit(using: authenticationService)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Button {
                        withAnimation(.smooth(duration: 0.25)) {
                            viewModel.isCreatingAccount.toggle()
                            viewModel.errorMessage = nil
                        }
                    } label: {
                        Text(viewModel.isCreatingAccount ? "Уже есть аккаунт" : "Создать новый аккаунт")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.pink)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

private extension View {
    func heartLinkTextField() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.18))
            }
    }
}

#Preview {
        AuthenticationView()
        .environmentObject(AuthenticationService(isFirebaseEnabled: false))
}
