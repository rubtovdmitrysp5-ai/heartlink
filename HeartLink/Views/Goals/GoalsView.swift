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

                    if firestoreService.goals.isEmpty {
                        EmptyStateView(
                            title: "Целей пока нет",
                            subtitle: "Создайте первую общую цель: свидание, поездку или список желаний.",
                            systemImage: "target"
                        )
                    } else {
                        ForEach(GoalKind.allCases) { kind in
                            let goals = firestoreService.goals.filter { $0.kind == kind && !$0.isCompleted }
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

                        let completedGoals = firestoreService.goals.filter(\.isCompleted)
                        if !completedGoals.isEmpty {
                            GoalGroupSection(kind: .task, title: "Завершено", goals: completedGoals) { goal in
                                router.navigate(to: .goal(goal.id))
                            } increase: { _ in }
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
    var title: String?
    let goals: [CoupleGoal]
    let open: (CoupleGoal) -> Void
    let increase: (CoupleGoal) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title ?? kind.title, subtitle: nil, systemImage: title == nil ? kind.symbolName : "checkmark.seal")

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
                    Text(goal.detail.isEmpty ? "Без описания" : goal.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if !goal.isCompleted {
                    Button(action: increase) {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .frame(width: 30, height: 30)
                            .background(.pink.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Добавить прогресс")
                }
            }

            ProgressView(value: goal.progress)
                .tint(goal.isCompleted ? .green : .pink)

            HStack {
                Text(goal.isCompleted ? "Выполнено" : "\(Int(goal.progress * 100))%")
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
    @StateObject private var viewModel = GoalsViewModel()
    @State private var isEditing = false

    private var goal: CoupleGoal? {
        firestoreService.goals.first { $0.id == goalId }
    }

    var body: some View {
        ZStack {
            RomanticBackground()

            if let goal {
                ScrollView {
                    VStack(spacing: 18) {
                        GlassCard {
                            VStack(spacing: 16) {
                                Image(systemName: goal.kind.symbolName)
                                    .font(.system(size: 54, weight: .semibold))
                                    .foregroundStyle(goal.isCompleted ? .green : .pink)
                                    .frame(width: 104, height: 104)
                                    .background((goal.isCompleted ? Color.green : Color.pink).opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                                Text(goal.title)
                                    .font(.title.bold())
                                    .multilineTextAlignment(.center)
                                Text(goal.detail.isEmpty ? "Без описания" : goal.detail)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                ProgressView(value: goal.progress)
                                    .tint(goal.isCompleted ? .green : .pink)
                                Text(goal.isCompleted ? "Цель выполнена" : "\(Int(goal.progress * 100))% выполнено")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if goal.kind == .savings, !goal.isCompleted {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Пополнить накопление")
                                        .font(.headline)
                                    TextField("Сумма", text: $viewModel.amountToAdd)
                                        .keyboardType(.decimalPad)
                                        .heartLinkGoalField()
                                    PrimaryActionButton(title: "Добавить сумму", systemImage: "plus", isLoading: viewModel.isSaving) {
                                        Task {
                                            await viewModel.addAmount(to: goal, using: firestoreService)
                                        }
                                    }
                                }
                            }
                        }

                        if !goal.isCompleted {
                            PrimaryActionButton(title: "Отметить выполненной", systemImage: "checkmark.seal.fill") {
                                Task {
                                    await firestoreService.completeGoal(goal)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                EmptyStateView(title: "Цель не найдена", subtitle: "Она могла быть завершена или ещё загружается.", systemImage: "target")
                    .padding(16)
            }
        }
        .navigationTitle("Цель")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let goal {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Редактировать цель")

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
        .sheet(isPresented: $isEditing) {
            if let goal {
                EditGoalView(goal: goal)
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Понятно", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Не удалось выполнить действие.")
        }
    }
}

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestoreService: FirestoreService
    @StateObject private var viewModel = GoalsViewModel()

    var body: some View {
        NavigationStack {
            GoalEditorContent(
                viewModel: viewModel,
                title: "Новая цель",
                saveTitle: "Сохранить цель",
                save: {
                    if await viewModel.createGoal(using: firestoreService) {
                        dismiss()
                    }
                },
                close: { dismiss() }
            )
        }
    }
}

private struct EditGoalView: View {
    let goal: CoupleGoal
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestoreService: FirestoreService
    @StateObject private var viewModel = GoalsViewModel()

    var body: some View {
        NavigationStack {
            GoalEditorContent(
                viewModel: viewModel,
                title: "Редактировать цель",
                saveTitle: "Обновить цель",
                save: {
                    if await viewModel.updateGoal(goal, using: firestoreService) {
                        dismiss()
                    }
                },
                close: { dismiss() }
            )
            .onAppear {
                if viewModel.title.isEmpty {
                    viewModel.configure(with: goal)
                }
            }
        }
    }
}

private struct GoalEditorContent: View {
    @ObservedObject var viewModel: GoalsViewModel
    let title: String
    let saveTitle: String
    let save: () async -> Void
    let close: () -> Void

    var body: some View {
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

                    PrimaryActionButton(title: saveTitle, systemImage: "target", isLoading: viewModel.isSaving) {
                        Task { await save() }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть", action: close)
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Понятно", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Не удалось выполнить действие.")
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
