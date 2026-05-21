import SwiftUI

struct SecurityLockView: View {
    @Environment(SecurityService.self) private var securityService
    @State private var enteredPasscode = ""

    var body: some View {
        ZStack {
            RomanticBackground()
                .blur(radius: 10)

            VStack(spacing: 20) {
                Spacer()

                GlassCard {
                    VStack(spacing: 18) {
                        Image(systemName: "lock.heart.fill")
                            .font(.system(size: 54, weight: .semibold))
                            .foregroundStyle(.pink)

                        VStack(spacing: 6) {
                            Text("HeartLink защищён")
                                .font(.title2.bold())
                            Text("Разблокируйте личное пространство.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        SecureField("Код-пароль", text: $enteredPasscode)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if let failedReason = securityService.failedReason {
                            Text(failedReason)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        PrimaryActionButton(title: "Разблокировать Face ID", systemImage: "faceid") {
                            Task {
                                await securityService.unlockWithBiometrics()
                            }
                        }

                        Button {
                            securityService.unlockWithPasscode(enteredPasscode)
                        } label: {
                            Text("Открыть по коду")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.pink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

struct SecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SecurityService.self) private var securityService
    @State private var passcode = ""

    var body: some View {
        NavigationStack {
            ZStack {
                RomanticBackground()

                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionTitle("Безопасность", subtitle: "Face ID, код и приватный режим", systemImage: "lock.shield")

                            Toggle("Приватный режим", isOn: $securityService.privateModeEnabled)
                                .tint(.pink)

                            SecureField("Новый код-пароль", text: $passcode)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            PrimaryActionButton(title: "Сохранить код", systemImage: "checkmark.shield") {
                                securityService.unlockWithPasscode(passcode)
                                securityService.lock()
                                dismiss()
                            }
                        }
                    }
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Защита")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SecurityLockView()
        .environment(SecurityService())
}

