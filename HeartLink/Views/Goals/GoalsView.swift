import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var router: RouterPath
    @StateObject private var viewModel = GoalsViewModel()

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 16) {
                    SectionTitle("Цели пары", subtitle: "Задачи, желания и накопления", systemImage: "target")

                    ForEach(GoalKind.allCases) { kind in
                        let goals = firestoreService.goals.filter { $0.kind == kind }
                        if !goals.isEmpty {
                            GoalGroupSection(kind: kind, goals: goals) { goal in
                                router.navigate(to: .goal(goal.id))
                            } increase: { goal in
                                Task {
                                    await viewModel.increaseProgress(for: goal, using: firestoreService)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Цели")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.addGoal)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить цель")
            }
        }
    }
}

private struct GoalGroupSection: View {
    let kind: GoalKind
    let goals: [CoupleGoal]
    let open: (CoupleGoal) -> Void
    let increase: (CoupleGoal) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(kind.title, subtitle: nil, systemImage: kind.symbolName)

                ForEach(goals) { goal in
                    GoalRow(
                        goal: goal,
                        open: { open(goal) },
                        increase: { increase(goal) }
                    )
                }
            }
        }
    }
}

private struct GoalRow: View {
    let goal: CoupleGoal
    let open: () -> Void
    let increase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.headline)
                    Text(goal.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button(action: increase) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .frame(width: 30, height: 30)
                        .background(.pink.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить прогресс")
            }

            ProgressView(value: goal.progress)
                .tint(.pink)

            HStack {
                Text("\(Int(goal.progress * 100))%")
                    .font(.caption.weight(.semibold))
                Spacer()
                if let current = goal.currentAmount, let target = goal.targetAmount {
                    Text("\(Int(current).formatted()) / \(Int(target).formatted()) ₽")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }
}

struct GoalDetailView: View {
    let goalId: String
    @EnvironmentObject private var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss

    private var goal: CoupleGoal? {
        firestoreService.goals.first { $0.id == goalId }
    }

    var body: some View {
        ZStack {
            RomanticBackground()

            if let goal {
                VStack(spacing: 18) {
                    GlassCard {
                        VStack(spacing: 16) {
                            Image(systemName: goal.kind.symbolName)
                                .font(.system(size: 54, weight: .semibold))
                                .foregroundStyle(.pink)
                                .frame(width: 104, height: 104)
                                .background(.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                            Text(goal.title)
                                .font(.title.bold())
                                .multilineTextAlignment(.center)
                            Text(goal.detail)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            ProgressView(value: goal.progress)
                                .tint(.pink)
                            Text("\(Int(goal.progress * 100))% выполнено")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    Spacer()
                }
            } else {
                EmptyStateView(title: "Цель не найдена", subtitle: "Она могла быть завершена или еще загружается.", systemImage: "target")
                    .padding(16)
            }
        }
        .navigationTitle("Цель")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let goal {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        Task {
                            await firestoreService.deleteGoal(goal)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Удалить цель")
                }
            }
        }
    }
}

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestoreService: FirestoreService
    @StateObject private var viewModel = GoalsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                RomanticBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        Picker("Тип", selection: $viewModel.kind) {
                            ForEach(GoalKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("Название", text: $viewModel.title)
                            .heartLinkGoalField()
                        TextField("Описание", text: $viewModel.detail, axis: .vertical)
                            .lineLimit(3...5)
                            .heartLinkGoalField()

                        if viewModel.kind == .savings {
                            TextField("Сумма цели", text: $viewModel.targetAmount)
                                .keyboardType(.decimalPad)
                                .heartLinkGoalField()
                        }

                        PrimaryActionButton(title: "Сохранить цель", systemImage: "target", isLoading: viewModel.isSaving) {
                            Task {
                                if await viewModel.createGoal(using: firestoreService) {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Новая цель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

private extension View {
    func heartLinkGoalField() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        GoalsView()
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
            .environmentObject(RouterPath())
    }
}
