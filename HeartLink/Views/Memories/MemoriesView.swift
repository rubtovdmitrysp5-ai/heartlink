import MapKit
import PhotosUI
import SwiftUI

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

    private var memory: Memory? {
        firestoreService.memories.first { $0.id == memoryId }
    }

    var body: some View {
        ZStack {
            RomanticBackground()
            if let memory {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        MemoryHeroImage(url: memory.imageURL)
                            .frame(height: 320)

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(memory.title)
                                    .font(.title.bold())
                                Text(memory.note)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Label(memory.locationName, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.pink)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        Task {
                            await firestoreService.deleteMemory(memory)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("������� ������������")
                }
            }
        }
    }
}

private struct MemoryThumbnail: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
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
                    .scaledToFill()
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

    private var userId: String {
        if case .signedIn(let user) = authenticationService.state {
            return user.id
        }
        return SampleDataStore.currentUser.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RomanticBackground()

                VStack(spacing: 14) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
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
                    .buttonStyle(.plain)

                    TextField("Название", text: $viewModel.title)
                        .heartLinkMemoryField()
                    TextField("Описание", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...5)
                        .heartLinkMemoryField()
                    TextField("Место", text: $viewModel.locationName)
                        .heartLinkMemoryField()

                    PrimaryActionButton(title: "Сохранить", systemImage: "heart.fill", isLoading: viewModel.isSaving) {
                        Task {
                            let imageData = try? await selectedPhoto?.loadTransferable(type: Data.self)
                            await viewModel.save(
                                imageData: imageData,
                                firestoreService: firestoreService,
                                storageService: storageService,
                                coupleId: firestoreService.couple.id,
                                userId: userId
                            )
                            selectedPhoto = nil
                            dismiss()
                        }
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Новое воспоминание")
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
