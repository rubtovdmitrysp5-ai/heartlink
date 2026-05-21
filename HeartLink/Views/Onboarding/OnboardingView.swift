import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            title: "HeartLink",
            subtitle: "Личное пространство для ваших сообщений, воспоминаний и планов.",
            symbolName: "heart.text.square.fill"
        ),
        OnboardingPage(
            title: "Каждый день вместе",
            subtitle: "Счётчик отношений, годовщины и нежные напоминания всегда рядом.",
            symbolName: "calendar.badge.heart"
        ),
        OnboardingPage(
            title: "Только для вас двоих",
            subtitle: "Face ID, код-пароль и приватный режим защищают важные моменты.",
            symbolName: "lock.shield.fill"
        )
    ]

    var body: some View {
        ZStack {
            RomanticBackground()

            VStack(spacing: 28) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.pink : Color.secondary.opacity(0.22))
                            .frame(width: index == page ? 26 : 8, height: 8)
                            .animation(.smooth(duration: 0.25), value: page)
                    }
                }

                PrimaryActionButton(
                    title: page == pages.count - 1 ? "Начать" : "Дальше",
                    systemImage: page == pages.count - 1 ? "heart.fill" : "arrow.right"
                ) {
                    if page == pages.count - 1 {
                        hasCompletedOnboarding = true
                    } else {
                        withAnimation(.smooth(duration: 0.35)) {
                            page += 1
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbolName: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 168, height: 168)
                    .overlay {
                        RoundedRectangle(cornerRadius: 44, style: .continuous)
                            .strokeBorder(.white.opacity(0.3))
                    }

                Image(systemName: page.symbolName)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.bounce, value: page.id)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .lineSpacing(3)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}

