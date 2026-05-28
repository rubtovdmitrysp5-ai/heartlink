import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct MemoriesView: View {
    let currentUser: UserProfile

    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var router: RouterPath

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 18) {
                    SectionTitle("Воспоминания", subtitle: "Ваш общий таймлайн", systemImage: "photo.stack")

                    if firestoreService.memories.isEmpty {
                        EmptyStateView(
                            title: "Пока нет воспоминаний",
                            subtitle: "Добавьте первое фото, место или маленькую историю вашего дня.",
                            systemImage: "photo.badge.plus"
                        )
                    } else {
                        MemoryMapCard(memories: firestoreService.memories)

                        ForEach(firestoreService.memories) { memory in
                            Button {
                                router.navigate(to: .memory(memory.id))
                            } label: {
                                MemoryTimelineCard(memory: memory)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Воспоминания")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.addMemory)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить воспоминание")
            }
        }
    }
}

private struct MemoryMapCard: View {
    let memories: [Memory]

    private var pinnedMemories: [Memory] {
        memories.filter { $0.coordinate != nil }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Места")
                        .font(.headline)
                    Spacer()
                    Text("\(pinnedMemories.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Map(initialPosition: .region(MKCoordinateRegion(
                    center: pinnedMemories.first?.coordinate ?? CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
                    span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
                ))) {
                    ForEach(pinnedMemories) { memory in
                        if let coordinate = memory.coordinate {
                            Marker(memory.title, coordinate: coordinate)
                                .tint(.pink)
                        }
                    }
                }
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}

private struct MemoryTimelineCard: View {
    let memory: Memory

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                MemoryThumbnail(url: memory.imageURL)
                    .frame(width: 86, height: 104)

                VStack(alignment: .leading, spacing: 6) {
                    Text(memory.title)
                        .font(.headline)
                    Text(memory.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Label(memory.locationName, systemImage: "mappin.and.ellipse")
                        Text(memory.date.heartLinkShortDate)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }
}

struct MemoryDetailView: View {
    let memoryId: String
    @EnvironmentObject private var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var openedImage: MemoryImageItem?

    private var memory: Memory? {
        firestoreService.memories.first { $0.id == memoryId }
    }

    var body: some View {
        ZStack {
            RomanticBackground()
            if let memory {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Button {
                            if let url = memory.imageURL {
                                openedImage = MemoryImageItem(url: url)
                            }
                        } label: {
                            MemoryHeroImage(url: memory.imageURL)
                                .frame(height: 320)
                        }
                        .buttonStyle(.plain)

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(memory.title)
                                    .font(.title.bold())
                                Text(memory.note.isEmpty ? "Без описания" : memory.note)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Label(memory.locationName, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.pink)
                                Label(memory.date.heartLinkShortDate, systemImage: "calendar")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                }
            } else {
                EmptyStateView(title: "Воспоминание не найдено", subtitle: "Оно могло быть удалено или ещё загружается.", systemImage: "photo")
                    .padding(16)
            }
        }
        .navigationTitle("Воспоминание")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let memory {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Редактировать воспоминание")

                    Button(role: .destructive) {
                        Task {
                            await firestoreService.deleteMemory(memory)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Удалить воспоминание")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let memory {
                EditMemoryView(memory: memory)
                    .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(item: $openedImage) { item in
            MemoryFullScreenPhotoView(url: item.url)
        }
    }
}

private struct MemoryImageItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct MemoryThumbnail: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
            default:
                LinearGradient(colors: [.pink.opacity(0.75), .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        Image(systemName: "photo.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct MemoryHeroImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
            default:
                LinearGradient(colors: [.pink, .purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 76))
                            .foregroundStyle(.white.opacity(0.9))
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

struct AddMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authenticationService: AuthenticationService
    @EnvironmentObject private var firestoreService: FirestoreService
    @EnvironmentObject private var storageService: StorageService
    @StateObject private var viewModel = MemoriesViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var croppedPhotoData: Data?
    @State private var cropItem: ImageCropItem?

    private var userId: String {
        if case .signedIn(let user) = authenticationService.state {
            return user.id
        }
        return SampleDataStore.currentUser.id
    }

    var body: some View {
        NavigationStack {
            MemoryEditorContent(
                viewModel: viewModel,
                selectedPhoto: $selectedPhoto,
                selectedImageData: croppedPhotoData,
                title: "Новое воспоминание",
                saveTitle: "Сохранить",
                save: {
                    let didSave = await viewModel.save(
                        imageData: croppedPhotoData,
                        firestoreService: firestoreService,
                        storageService: storageService,
                        userId: userId
                    )
                    if didSave {
                        selectedPhoto = nil
                        croppedPhotoData = nil
                        dismiss()
                    }
                },
                close: { dismiss() }
            )
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        cropItem = ImageCropItem(imageData: data, title: "Кадрировать воспоминание", aspectRatio: 0.8, maxPixelSize: 1800)
                    }
                    selectedPhoto = nil
                }
            }
            .sheet(item: $cropItem) { item in
                ImageCropSheet(item: item) { data in
                    cropItem = nil
                    croppedPhotoData = data
                }
            }
        }
    }
}

private struct EditMemoryView: View {
    let memory: Memory
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firestoreService: FirestoreService
    @StateObject private var viewModel = MemoriesViewModel()

    var body: some View {
        NavigationStack {
            MemoryEditorContent(
                viewModel: viewModel,
                selectedPhoto: .constant(nil),
                selectedImageData: nil,
                title: "Редактировать",
                saveTitle: "Обновить",
                allowsPhotoSelection: false,
                save: {
                    if await viewModel.update(memory: memory, using: firestoreService) {
                        dismiss()
                    }
                },
                close: { dismiss() }
            )
            .onAppear {
                if viewModel.title.isEmpty {
                    viewModel.configure(with: memory)
                }
            }
        }
    }
}

private struct MemoryEditorContent: View {
    @ObservedObject var viewModel: MemoriesViewModel
    @Binding var selectedPhoto: PhotosPickerItem?
    let selectedImageData: Data?
    let title: String
    let saveTitle: String
    var allowsPhotoSelection = true
    let save: () async -> Void
    let close: () -> Void

    var body: some View {
        ZStack {
            RomanticBackground()

            ScrollView {
                VStack(spacing: 14) {
                    if allowsPhotoSelection {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 180)
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .frame(height: 154)
                                        .overlay {
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.largeTitle)
                                                Text("Добавить фото")
                                                    .font(.headline)
                                            }
                                            .foregroundStyle(.pink)
                                        }
                                }

                                if selectedImageData != nil {
                                    VStack(spacing: 8) {
                                        Image(systemName: "crop")
                                        Text("Изменить кадр")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .foregroundStyle(.pink)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Название", text: $viewModel.title)
                        .heartLinkMemoryField()
                    TextField("Описание", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...5)
                        .heartLinkMemoryField()
                    TextField("Место", text: $viewModel.locationName)
                        .heartLinkMemoryField()
                    Text("Можно написать адрес или город. При сохранении HeartLink попробует поставить точку на карте.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DatePicker("Дата", selection: $viewModel.date, displayedComponents: .date)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    PrimaryActionButton(title: saveTitle, systemImage: "heart.fill", isLoading: viewModel.isSaving) {
                        Task { await save() }
                    }

                    Spacer(minLength: 12)
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

private struct MemoryFullScreenPhotoView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    EmptyStateView(title: "Фото недоступно", subtitle: "Проверьте сервер и подключение.", systemImage: "photo")
                        .padding(24)
                default:
                    ProgressView()
                        .tint(.white)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(20)
        }
    }
}

private extension View {
    func heartLinkMemoryField() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        MemoriesView(currentUser: .sample)
            .environmentObject(FirestoreService(isFirebaseEnabled: false))
            .environmentObject(StorageService(isFirebaseEnabled: false))
            .environmentObject(RouterPath())
            .environmentObject(AuthenticationService(isFirebaseEnabled: false))
    }
}
