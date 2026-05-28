import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class FirestoreService: ObservableObject {
    private let isFirebaseEnabled: Bool
    private var listeners: [ListenerRegistration] = []
    private var localBaseURLString: String?
    private var localUserId: String?

    @Published var couple: Couple = SampleDataStore.couple
    @Published var partner: UserProfile = SampleDataStore.partner
    @Published var messages: [ChatMessage] = SampleDataStore.messages
    @Published var memories: [Memory] = SampleDataStore.memories
    @Published var goals: [CoupleGoal] = SampleDataStore.goals
    @Published var games: [LoveGame] = SampleDataStore.games
    @Published var isSyncing = false
    @Published var lastErrorMessage: String?

    init(isFirebaseEnabled: Bool) {
        self.isFirebaseEnabled = isFirebaseEnabled
    }

    func configureLocalBackend(baseURLString: String, userId: String) {
        guard !isFirebaseEnabled else { return }
        localBaseURLString = baseURLString
        localUserId = userId
        Task {
            await refreshLocalCoupleData()
        }
    }

    func applyLocalPairing(couple: Couple, partner: UserProfile) {
        self.couple = couple
        self.partner = partner
    }

    func refreshLocalCoupleData() async {
        guard !isFirebaseEnabled, localBaseURLString != nil else { return }

        do {
            isSyncing = true
            defer { isSyncing = false }

            let response: LocalCoupleDataResponse = try await localRequest(
                path: "/api/couple/\(couple.id)/data",
                method: "GET"
            )

            messages = response.messages
            memories = response.memories
            goals = response.goals
            games = response.games

            if let partnerSnapshot = response.users.first(where: { $0.id == partner.id }) {
                partner.currentMood = MoodStatus(rawValue: partnerSnapshot.currentMood) ?? partner.currentMood
                if let displayName = partnerSnapshot.displayName, !displayName.isEmpty {
                    partner.displayName = displayName
                }
                partner.avatarURL = partnerSnapshot.avatarURL
            }
        } catch {
            lastErrorMessage = "Сервер недоступен. Проверьте подключение."
            if goals.isEmpty {
                goals = SampleDataStore.goals
            }
        }
    }

    func start(user: UserProfile) {
        guard isFirebaseEnabled else { return }
        removeListeners()
        listenForUser(user)
        Task {
            await loadCoupleAndStreams(for: user)
        }
    }

    func updateMood(_ mood: MoodStatus, userId: String) async {
        guard isFirebaseEnabled else {
            let _: PairingSessionResponse? = try? await localRequest(
                path: "/api/mood",
                method: "POST",
                body: LocalMoodRequest(userId: userId, mood: mood.rawValue)
            )
            return
        }
        try? await Firestore.firestore().collection("users").document(userId).setData([
            "currentMood": mood.rawValue,
            "updatedAt": Timestamp(date: .now)
        ], merge: true)
    }

    @discardableResult
    func sendTextMessage(_ text: String, coupleId: String, authorId: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let message = ChatMessage(
            id: UUID().uuidString,
            coupleId: coupleId,
            authorId: authorId,
            text: trimmed,
            kind: .text,
            mediaURL: nil,
            voiceDuration: nil,
            isOneTime: nil,
            oneTimeDuration: nil,
            viewedBy: nil,
            reactions: [],
            sentAt: .now,
            isRead: false
        )

        return await saveMessage(message)
    }

    @discardableResult
    func sendImageMessage(
        imageURL: URL?,
        coupleId: String,
        authorId: String,
        isOneTime: Bool = false,
        oneTimeDuration: TimeInterval? = nil
    ) async -> Bool {
        guard imageURL != nil else {
            lastErrorMessage = "Фото не загрузилось. Попробуйте ещё раз."
            return false
        }

        let message = ChatMessage(
            id: UUID().uuidString,
            coupleId: coupleId,
            authorId: authorId,
            text: "Фото",
            kind: .image,
            mediaURL: imageURL,
            voiceDuration: nil,
            isOneTime: isOneTime ? true : nil,
            oneTimeDuration: isOneTime ? (oneTimeDuration ?? 10) : nil,
            viewedBy: isOneTime ? [] : nil,
            reactions: [],
            sentAt: .now,
            isRead: false
        )

        return await saveMessage(message)
    }

    @discardableResult
    func sendImageData(
        _ imageData: Data?,
        storageService: StorageService,
        coupleId: String,
        authorId: String,
        isOneTime: Bool = false,
        oneTimeDuration: TimeInterval? = nil
    ) async -> Bool {
        guard let imageData, !imageData.isEmpty else {
            lastErrorMessage = "Не удалось прочитать фото."
            return false
        }

        let imageURL: URL?

        if isFirebaseEnabled {
            imageURL = try? await storageService.uploadImageData(
                imageData,
                path: "couples/\(coupleId)/messages/\(UUID().uuidString).jpg"
            )
        } else {
            imageURL = try? await uploadLocalImageData(imageData, coupleId: coupleId)
        }

        return await sendImageMessage(
            imageURL: imageURL,
            coupleId: coupleId,
            authorId: authorId,
            isOneTime: isOneTime,
            oneTimeDuration: oneTimeDuration
        )
    }

    func deleteMessage(_ message: ChatMessage) async {
        guard isFirebaseEnabled else {
            messages.removeAll { $0.id == message.id }
            let _: LocalOKResponse? = try? await localRequest(path: "/api/messages/\(message.id)", method: "DELETE")
            return
        }

        try? await Firestore.firestore()
            .collection("couples")
            .document(message.coupleId)
            .collection("messages")
            .document(message.id)
            .delete()
    }

    @discardableResult
    func sendVoiceData(
        _ audioData: Data?,
        duration: TimeInterval,
        storageService: StorageService,
        coupleId: String,
        authorId: String
    ) async -> Bool {
        guard let audioData, !audioData.isEmpty else {
            lastErrorMessage = "Не удалось записать голосовое."
            return false
        }

        let audioURL: URL?
        if isFirebaseEnabled {
            audioURL = try? await storageService.uploadImageData(
                audioData,
                path: "couples/\(coupleId)/voice/\(UUID().uuidString).m4a"
            )
        } else {
            audioURL = try? await uploadLocalFileData(audioData, coupleId: coupleId, endpoint: "/api/uploads/audio", fileExtension: "m4a")
        }

        guard audioURL != nil else {
            lastErrorMessage = "Голосовое не загрузилось. Проверьте сервер."
            return false
        }

        let message = ChatMessage(
            id: UUID().uuidString,
            coupleId: coupleId,
            authorId: authorId,
            text: "Голосовое сообщение",
            kind: .voice,
            mediaURL: audioURL,
            voiceDuration: max(1, duration),
            isOneTime: nil,
            oneTimeDuration: nil,
            viewedBy: nil,
            reactions: [],
            sentAt: .now,
            isRead: false
        )

        return await saveMessage(message)
    }

    func sendVoicePreviewMessage(coupleId: String, authorId: String, duration: TimeInterval = 12) async {
        let message = ChatMessage(
            id: UUID().uuidString,
            coupleId: coupleId,
            authorId: authorId,
            text: "Голосовое сообщение",
            kind: .voice,
            mediaURL: nil,
            voiceDuration: max(1, duration),
            isOneTime: nil,
            oneTimeDuration: nil,
            viewedBy: nil,
            reactions: [],
            sentAt: .now,
            isRead: false
        )

        await saveMessage(message)
    }

    func markOneTimeMessageViewed(_ message: ChatMessage, userId: String) async {
        guard message.isOneTime == true, !message.wasViewed(by: userId) else { return }

        guard isFirebaseEnabled else {
            if let response: LocalMessageResponse = try? await localRequest(
                path: "/api/messages/\(message.id)/viewed",
                method: "PATCH",
                body: LocalMessageViewedRequest(userId: userId)
            ), let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = response.message
            }
            return
        }

        try? await Firestore.firestore()
            .collection("couples")
            .document(message.coupleId)
            .collection("messages")
            .document(message.id)
            .updateData(["viewedBy": FieldValue.arrayUnion([userId])])
    }

    func addReaction(_ emoji: String, to message: ChatMessage, authorId: String) async {
        guard isFirebaseEnabled else {
            let reaction = ChatReaction(id: UUID().uuidString, emoji: emoji, authorId: authorId)
            if let response: LocalMessageResponse = try? await localRequest(
                path: "/api/messages/\(message.id)/reactions",
                method: "POST",
                body: LocalReactionRequest(reaction: reaction)
            ), let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = response.message
            } else if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].reactions.append(reaction)
            }
            return
        }

        let reaction: [String: Any] = [
            "id": UUID().uuidString,
            "emoji": emoji,
            "authorId": authorId
        ]

        try? await Firestore.firestore()
            .collection("couples")
            .document(message.coupleId)
            .collection("messages")
            .document(message.id)
            .updateData(["reactions": FieldValue.arrayUnion([reaction])])
    }

    @discardableResult
    func addMemory(
        title: String,
        note: String,
        locationName: String,
        imageURL: URL?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        date: Date = .now,
        userId: String
    ) async -> Bool {
        let memory = Memory(
            id: UUID().uuidString,
            coupleId: couple.id,
            title: title,
            note: note,
            imageURL: imageURL,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            date: date,
            createdBy: userId
        )

        guard isFirebaseEnabled else {
            if let response: LocalMemoryResponse = try? await localRequest(
                path: "/api/memories",
                method: "POST",
                body: LocalMemoryRequest(memory: memory)
            ) {
                memories.insert(response.memory, at: 0)
                return true
            } else {
                lastErrorMessage = "Не удалось сохранить воспоминание."
                return false
            }
        }

        do {
            try await Firestore.firestore()
                .collection("couples")
                .document(couple.id)
                .collection("memories")
                .document(memory.id)
                .setData(memory.dictionary)
            return true
        } catch {
            lastErrorMessage = "Не удалось сохранить воспоминание."
            return false
        }
    }

    @discardableResult
    func addMemoryWithImageData(
        title: String,
        note: String,
        locationName: String,
        date: Date,
        imageData: Data?,
        storageService: StorageService,
        latitude: Double? = nil,
        longitude: Double? = nil,
        userId: String
    ) async -> Bool {
        let imageURL: URL?
        if isFirebaseEnabled {
            imageURL = try? await storageService.uploadImageData(
                imageData,
                path: "couples/\(couple.id)/memories/\(UUID().uuidString).jpg"
            )
        } else {
            imageURL = try? await uploadLocalImageData(imageData, coupleId: couple.id)
        }

        return await addMemory(
            title: title,
            note: note,
            locationName: locationName,
            imageURL: imageURL,
            latitude: latitude,
            longitude: longitude,
            date: date,
            userId: userId
        )
    }

    func deleteMemory(_ memory: Memory) async {
        guard isFirebaseEnabled else {
            memories.removeAll { $0.id == memory.id }
            let _: LocalOKResponse? = try? await localRequest(path: "/api/memories/\(memory.id)", method: "DELETE")
            return
        }

        try? await Firestore.firestore()
            .collection("couples")
            .document(couple.id)
            .collection("memories")
            .document(memory.id)
            .delete()
    }

    @discardableResult
    func updateMemory(_ memory: Memory, title: String, note: String, locationName: String, date: Date) async -> Bool {
        var updated = memory
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Без места" : locationName
        updated.date = date

        guard !updated.title.isEmpty else {
            lastErrorMessage = "Введите название воспоминания."
            return false
        }

        guard isFirebaseEnabled else {
            if let response: LocalMemoryResponse = try? await localRequest(
                path: "/api/memories/\(memory.id)",
                method: "PATCH",
                body: LocalMemoryRequest(memory: updated)
            ), let index = memories.firstIndex(where: { $0.id == memory.id }) {
                memories[index] = response.memory
                memories.sort { $0.date > $1.date }
                return true
            }

            lastErrorMessage = "Не удалось обновить воспоминание."
            return false
        }

        do {
            try await Firestore.firestore()
                .collection("couples")
                .document(couple.id)
                .collection("memories")
                .document(memory.id)
                .setData(updated.dictionary, merge: true)
            return true
        } catch {
            lastErrorMessage = "Не удалось обновить воспоминание."
            return false
        }
    }

    @discardableResult
    func createGoal(title: String, detail: String, kind: GoalKind, targetAmount: Double?) async -> Bool {
        let goal = CoupleGoal(
            id: UUID().uuidString,
            coupleId: couple.id,
            title: title,
            detail: detail,
            kind: kind,
            progress: 0,
            targetAmount: targetAmount,
            currentAmount: targetAmount == nil ? nil : 0,
            dueDate: nil,
            isCompleted: false
        )

        guard isFirebaseEnabled else {
            if let response: LocalGoalResponse = try? await localRequest(
                path: "/api/goals",
                method: "POST",
                body: LocalGoalRequest(goal: goal)
            ) {
                goals.append(response.goal)
                return true
            } else {
                lastErrorMessage = "Не удалось создать цель."
                return false
            }
        }

        do {
            try await Firestore.firestore()
                .collection("couples")
                .document(couple.id)
                .collection("goals")
                .document(goal.id)
                .setData(goal.dictionary)
            return true
        } catch {
            lastErrorMessage = "Не удалось создать цель."
            return false
        }
    }

    func deleteGoal(_ goal: CoupleGoal) async {
        guard isFirebaseEnabled else {
            goals.removeAll { $0.id == goal.id }
            let _: LocalOKResponse? = try? await localRequest(path: "/api/goals/\(goal.id)", method: "DELETE")
            return
        }

        try? await Firestore.firestore()
            .collection("couples")
            .document(couple.id)
            .collection("goals")
            .document(goal.id)
            .delete()
    }

    @discardableResult
    func updateGoal(_ goal: CoupleGoal, title: String, detail: String, kind: GoalKind, targetAmount: Double?) async -> Bool {
        var updated = goal
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.kind = kind
        updated.targetAmount = kind == .savings ? targetAmount : nil
        updated.currentAmount = kind == .savings ? min(updated.currentAmount ?? 0, targetAmount ?? 0) : nil
        updated.progress = kind == .savings && (targetAmount ?? 0) > 0 ? min((updated.currentAmount ?? 0) / (targetAmount ?? 1), 1) : updated.progress

        guard !updated.title.isEmpty else {
            lastErrorMessage = "Введите название цели."
            return false
        }

        guard isFirebaseEnabled else {
            if let response: LocalGoalResponse = try? await localRequest(
                path: "/api/goals/\(goal.id)",
                method: "PATCH",
                body: LocalGoalRequest(goal: updated)
            ), let index = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[index] = response.goal
                return true
            }

            lastErrorMessage = "Не удалось обновить цель."
            return false
        }

        do {
            try await Firestore.firestore()
                .collection("couples")
                .document(goal.coupleId)
                .collection("goals")
                .document(goal.id)
                .setData(updated.dictionary, merge: true)
            return true
        } catch {
            lastErrorMessage = "Не удалось обновить цель."
            return false
        }
    }

    func addSavingsAmount(_ amount: Double, to goal: CoupleGoal) async {
        guard amount > 0, let targetAmount = goal.targetAmount else { return }
        let currentAmount = min((goal.currentAmount ?? 0) + amount, targetAmount)
        await updateGoalProgress(goal: goal, progress: targetAmount > 0 ? currentAmount / targetAmount : goal.progress)
    }

    func completeGoal(_ goal: CoupleGoal) async {
        await updateGoalProgress(goal: goal, progress: 1)
    }

    @discardableResult
    func submitGameAnswer(game: LoveGame, answer: String, userId: String) async -> Bool {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastErrorMessage = "Введите ответ перед отправкой."
            return false
        }

        guard isFirebaseEnabled else {
            if let response: LocalGameResponse = try? await localRequest(
                path: "/api/games/\(game.id)/answers",
                method: "POST",
                body: LocalGameAnswerRequest(userId: userId, answer: trimmed)
            ), let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index] = response.game
                return true
            } else if let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index].completedToday = true
                lastErrorMessage = "Ответ сохранён только на этом устройстве."
                return false
            }
            return false
        }

        return false
    }

    func uploadAvatarImageData(_ imageData: Data?, storageService: StorageService) async -> URL? {
        guard let imageData else { return nil }
        if isFirebaseEnabled {
            return try? await storageService.uploadImageData(
                imageData,
                path: "couples/\(couple.id)/avatars/\(UUID().uuidString).jpg"
            )
        }
        return try? await uploadLocalImageData(imageData, coupleId: couple.id)
    }

    func updateLocalProfile(
        userId: String,
        displayName: String,
        partnerName: String,
        startedAt: Date,
        avatarURL: URL? = nil,
        partnerAvatarURL: URL? = nil
    ) async {
        let response: PairingSessionResponse? = try? await localRequest(
            path: "/api/profile",
            method: "PATCH",
            body: LocalProfileUpdateRequest(
                userId: userId,
                displayName: displayName,
                partnerName: partnerName,
                relationshipStartedAt: Self.localISOFormatter.string(from: startedAt),
                avatarURL: avatarURL?.absoluteString,
                partnerAvatarURL: partnerAvatarURL?.absoluteString
            )
        )

        guard let session = response?.session else { return }
        partner.displayName = session.partnerName ?? partner.displayName
        partner.avatarURL = session.partnerAvatarURL ?? partnerAvatarURL ?? partner.avatarURL
        let components = Calendar.current.dateComponents([.day, .month], from: session.relationshipStartedAt ?? startedAt)
        couple.startedAt = session.relationshipStartedAt ?? startedAt
        couple.anniversaryDay = components.day ?? couple.anniversaryDay
        couple.anniversaryMonth = components.month ?? couple.anniversaryMonth
    }

    func updateGoalProgress(goal: CoupleGoal, progress: Double) async {
        let clamped = min(max(progress, 0), 1)

        guard isFirebaseEnabled else {
            guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
            goals[index].progress = clamped
            goals[index].isCompleted = clamped >= 1
            if let targetAmount = goals[index].targetAmount {
                goals[index].currentAmount = targetAmount * clamped
            }
            if let response: LocalGoalResponse = try? await localRequest(
                path: "/api/goals/\(goal.id)",
                method: "PATCH",
                body: LocalGoalProgressRequest(
                    progress: goals[index].progress,
                    currentAmount: goals[index].currentAmount,
                    isCompleted: goals[index].isCompleted
                )
            ) {
                goals[index] = response.goal
            }
            return
        }

        try? await Firestore.firestore()
            .collection("couples")
            .document(goal.coupleId)
            .collection("goals")
            .document(goal.id)
            .setData([
                "progress": clamped,
                "isCompleted": clamped >= 1,
                "updatedAt": Timestamp(date: .now)
            ], merge: true)
    }

    private func listenForUser(_ user: UserProfile) {
        let listener = Firestore.firestore().collection("users").document(user.id).addSnapshotListener { [weak self] snapshot, _ in
            Task { @MainActor in
                guard let self, let data = snapshot?.data() else { return }
                self.partner = UserProfile(
                    id: data["partnerId"] as? String ?? SampleDataStore.partner.id,
                    displayName: self.partner.displayName,
                    email: self.partner.email,
                    avatarURL: self.partner.avatarURL,
                    currentMood: self.partner.currentMood,
                    partnerId: user.id,
                    coupleId: self.couple.id,
                    createdAt: self.partner.createdAt
                )
            }
        }
        listeners.append(listener)
    }

    private func listenForCouple(coupleId: String) {
        let listener = Firestore.firestore().collection("couples").document(coupleId).addSnapshotListener { [weak self] snapshot, _ in
            Task { @MainActor in
                guard let self, let data = snapshot?.data() else { return }
                self.couple = Couple(data: data, id: coupleId) ?? self.couple
            }
        }
        listeners.append(listener)
    }

    private func listenForMessages(coupleId: String) {
        let listener = Firestore.firestore()
            .collection("couples")
            .document(coupleId)
            .collection("messages")
            .order(by: "sentAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, let documents = snapshot?.documents else { return }
                    self.messages = documents.compactMap { ChatMessage(data: $0.data(), id: $0.documentID) }
                }
            }
        listeners.append(listener)
    }

    private func listenForMemories(coupleId: String) {
        let listener = Firestore.firestore()
            .collection("couples")
            .document(coupleId)
            .collection("memories")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, let documents = snapshot?.documents else { return }
                    self.memories = documents.compactMap { Memory(data: $0.data(), id: $0.documentID) }
                }
            }
        listeners.append(listener)
    }

    private func listenForGoals(coupleId: String) {
        let listener = Firestore.firestore()
            .collection("couples")
            .document(coupleId)
            .collection("goals")
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, let documents = snapshot?.documents else { return }
                    self.goals = documents.compactMap { CoupleGoal(data: $0.data(), id: $0.documentID) }
                }
            }
        listeners.append(listener)
    }

    private func loadCoupleAndStreams(for user: UserProfile) async {
        if let loadedCouple = await fetchCouple(for: user) {
            couple = loadedCouple
        }

        listenForCouple(coupleId: couple.id)
        listenForMessages(coupleId: couple.id)
        listenForMemories(coupleId: couple.id)
        listenForGoals(coupleId: couple.id)

        let partnerId = couple.firstUserId == user.id ? couple.secondUserId : couple.firstUserId
        await fetchPartner(partnerId: partnerId, currentUserId: user.id)
    }

    private func fetchCouple(for user: UserProfile) async -> Couple? {
        if let coupleId = user.coupleId {
            let snapshot = try? await Firestore.firestore().collection("couples").document(coupleId).getDocument()
            if let snapshot, let data = snapshot.data() {
                return Couple(data: data, id: snapshot.documentID)
            }
        }

        let firstUserSnapshot = try? await Firestore.firestore()
            .collection("couples")
            .whereField("firstUserId", isEqualTo: user.id)
            .limit(to: 1)
            .getDocuments()

        if let document = firstUserSnapshot?.documents.first, let couple = Couple(data: document.data(), id: document.documentID) {
            return couple
        }

        let secondUserSnapshot = try? await Firestore.firestore()
            .collection("couples")
            .whereField("secondUserId", isEqualTo: user.id)
            .limit(to: 1)
            .getDocuments()

        if let document = secondUserSnapshot?.documents.first {
            return Couple(data: document.data(), id: document.documentID)
        }

        return nil
    }

    private func fetchPartner(partnerId: String, currentUserId: String) async {
        guard partnerId != currentUserId else { return }
        let snapshot = try? await Firestore.firestore().collection("users").document(partnerId).getDocument()
        guard let data = snapshot?.data() else { return }

        partner = UserProfile(
            id: partnerId,
            displayName: data["displayName"] as? String ?? "Партнёр",
            email: data["email"] as? String ?? "",
            avatarURL: (data["avatarURL"] as? String).flatMap(URL.init(string:)),
            currentMood: MoodStatus(rawValue: data["currentMood"] as? String ?? "") ?? .happy,
            partnerId: currentUserId,
            coupleId: couple.id,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now
        )
    }

    private func removeListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    @discardableResult
    private func saveMessage(_ message: ChatMessage) async -> Bool {
        if isFirebaseEnabled {
            do {
                try await Firestore.firestore()
                    .collection("couples")
                    .document(message.coupleId)
                    .collection("messages")
                    .document(message.id)
                    .setData(message.dictionary)
                return true
            } catch {
                lastErrorMessage = "Не удалось отправить сообщение."
                return false
            }
        } else {
            if let response: LocalMessageResponse = try? await localRequest(
                path: "/api/messages",
                method: "POST",
                body: LocalMessageRequest(message: message)
            ) {
                messages.append(response.message)
                return true
            } else {
                lastErrorMessage = "Не удалось отправить сообщение. Проверьте сервер."
                return false
            }
        }
    }

    private func uploadLocalImageData(_ imageData: Data?, coupleId: String) async throws -> URL? {
        guard let imageData else { return nil }

        return try await uploadLocalFileData(imageData, coupleId: coupleId, endpoint: "/api/uploads/image", fileExtension: "jpg")
    }

    private func uploadLocalFileData(_ fileData: Data, coupleId: String, endpoint: String, fileExtension: String) async throws -> URL? {
        let response: LocalImageUploadResponse = try await localRequest(
            path: endpoint,
            method: "POST",
            body: LocalImageUploadRequest(
                coupleId: coupleId,
                imageBase64: fileData.base64EncodedString(),
                fileExtension: fileExtension
            )
        )

        return URL(string: response.imageURL)
    }

    private func localRequest<Response: Decodable>(
        path: String,
        method: String
    ) async throws -> Response {
        try await localRequest(path: path, method: method, body: Optional<EmptyRequest>.none)
    }

    private func localRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        guard let localBaseURLString, let baseURL = URL(string: localBaseURLString), let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try Self.localEncoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try Self.localDecoder.decode(Response.self, from: data)
    }

    private static let localDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let localEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let localISOFormatter = ISO8601DateFormatter()
}

private struct EmptyRequest: Encodable {}

private struct LocalCoupleDataResponse: Decodable {
    let messages: [ChatMessage]
    let memories: [Memory]
    let goals: [CoupleGoal]
    let games: [LoveGame]
    let users: [LocalUserSnapshot]
}

private struct LocalUserSnapshot: Decodable {
    let id: String
    let displayName: String?
    let currentMood: String
    let avatarURL: URL?
}

private struct LocalMessageRequest: Encodable {
    let message: ChatMessage
}

private struct LocalMessageResponse: Decodable {
    let message: ChatMessage
}

private struct LocalReactionRequest: Encodable {
    let reaction: ChatReaction
}

private struct LocalMessageViewedRequest: Encodable {
    let userId: String
}

private struct LocalImageUploadRequest: Encodable {
    let coupleId: String
    let imageBase64: String
    let fileExtension: String
}

private struct LocalImageUploadResponse: Decodable {
    let imageURL: String
}

private struct LocalMemoryRequest: Encodable {
    let memory: Memory
}

private struct LocalMemoryResponse: Decodable {
    let memory: Memory
}

private struct LocalGoalRequest: Encodable {
    let goal: CoupleGoal
}

private struct LocalGoalProgressRequest: Encodable {
    let progress: Double
    let currentAmount: Double?
    let isCompleted: Bool
}

private struct LocalGoalResponse: Decodable {
    let goal: CoupleGoal
}

private struct LocalGameAnswerRequest: Encodable {
    let userId: String
    let answer: String
}

private struct LocalGameResponse: Decodable {
    let game: LoveGame
}

private struct LocalProfileUpdateRequest: Encodable {
    let userId: String
    let displayName: String
    let partnerName: String
    let relationshipStartedAt: String
    let avatarURL: String?
    let partnerAvatarURL: String?
}

private struct LocalOKResponse: Decodable {
    let ok: Bool
}

private struct LocalMoodRequest: Encodable {
    let userId: String
    let mood: String
}

private extension Couple {
    init?(data: [String: Any], id: String) {
        guard
            let firstUserId = data["firstUserId"] as? String,
            let secondUserId = data["secondUserId"] as? String,
            let startedAt = (data["startedAt"] as? Timestamp)?.dateValue(),
            let anniversaryDay = data["anniversaryDay"] as? Int,
            let anniversaryMonth = data["anniversaryMonth"] as? Int,
            let inviteCode = data["inviteCode"] as? String
        else { return nil }

        self.init(
            id: id,
            firstUserId: firstUserId,
            secondUserId: secondUserId,
            startedAt: startedAt,
            anniversaryDay: anniversaryDay,
            anniversaryMonth: anniversaryMonth,
            inviteCode: inviteCode,
            privateModeEnabled: data["privateModeEnabled"] as? Bool ?? false
        )
    }
}

private extension ChatMessage {
    var dictionary: [String: Any] {
        var data: [String: Any] = [
            "coupleId": coupleId,
            "authorId": authorId,
            "text": text,
            "kind": kind.rawValue,
            "reactions": reactions.map { ["id": $0.id, "emoji": $0.emoji, "authorId": $0.authorId] },
            "sentAt": Timestamp(date: sentAt),
            "isRead": isRead
        ]

        if let mediaURL {
            data["mediaURL"] = mediaURL.absoluteString
        }

        if let voiceDuration {
            data["voiceDuration"] = voiceDuration
        }

        if isOneTime == true {
            data["isOneTime"] = true
            data["oneTimeDuration"] = oneTimeDuration ?? 10
            data["viewedBy"] = viewedBy ?? []
        }

        return data
    }

    init?(data: [String: Any], id: String) {
        guard
            let coupleId = data["coupleId"] as? String,
            let authorId = data["authorId"] as? String,
            let text = data["text"] as? String,
            let kindRaw = data["kind"] as? String,
            let kind = MessageKind(rawValue: kindRaw),
            let sentAt = (data["sentAt"] as? Timestamp)?.dateValue()
        else { return nil }

        let reactionData = data["reactions"] as? [[String: Any]] ?? []
        self.init(
            id: id,
            coupleId: coupleId,
            authorId: authorId,
            text: text,
            kind: kind,
            mediaURL: (data["mediaURL"] as? String).flatMap(URL.init(string:)),
            voiceDuration: data["voiceDuration"] as? TimeInterval,
            isOneTime: data["isOneTime"] as? Bool,
            oneTimeDuration: data["oneTimeDuration"] as? TimeInterval,
            viewedBy: data["viewedBy"] as? [String],
            reactions: reactionData.compactMap { item in
                guard let id = item["id"] as? String, let emoji = item["emoji"] as? String, let authorId = item["authorId"] as? String else { return nil }
                return ChatReaction(id: id, emoji: emoji, authorId: authorId)
            },
            sentAt: sentAt,
            isRead: data["isRead"] as? Bool ?? false
        )
    }
}

private extension Memory {
    var dictionary: [String: Any] {
        var data: [String: Any] = [
            "coupleId": coupleId,
            "title": title,
            "note": note,
            "locationName": locationName,
            "date": Timestamp(date: date),
            "createdBy": createdBy
        ]

        if let imageURL {
            data["imageURL"] = imageURL.absoluteString
        }

        if let latitude {
            data["latitude"] = latitude
        }

        if let longitude {
            data["longitude"] = longitude
        }

        return data
    }

    init?(data: [String: Any], id: String) {
        guard
            let coupleId = data["coupleId"] as? String,
            let title = data["title"] as? String,
            let note = data["note"] as? String,
            let locationName = data["locationName"] as? String,
            let date = (data["date"] as? Timestamp)?.dateValue(),
            let createdBy = data["createdBy"] as? String
        else { return nil }

        self.init(
            id: id,
            coupleId: coupleId,
            title: title,
            note: note,
            imageURL: (data["imageURL"] as? String).flatMap(URL.init(string:)),
            locationName: locationName,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            date: date,
            createdBy: createdBy
        )
    }
}

private extension CoupleGoal {
    var dictionary: [String: Any] {
        var data: [String: Any] = [
            "coupleId": coupleId,
            "title": title,
            "detail": detail,
            "kind": kind.rawValue,
            "progress": progress,
            "isCompleted": isCompleted
        ]

        if let targetAmount {
            data["targetAmount"] = targetAmount
        }

        if let currentAmount {
            data["currentAmount"] = currentAmount
        }

        if let dueDate {
            data["dueDate"] = Timestamp(date: dueDate)
        }

        return data
    }

    init?(data: [String: Any], id: String) {
        guard
            let coupleId = data["coupleId"] as? String,
            let title = data["title"] as? String,
            let detail = data["detail"] as? String,
            let kindRaw = data["kind"] as? String,
            let kind = GoalKind(rawValue: kindRaw),
            let progress = data["progress"] as? Double
        else { return nil }

        self.init(
            id: id,
            coupleId: coupleId,
            title: title,
            detail: detail,
            kind: kind,
            progress: progress,
            targetAmount: data["targetAmount"] as? Double,
            currentAmount: data["currentAmount"] as? Double,
            dueDate: (data["dueDate"] as? Timestamp)?.dateValue(),
            isCompleted: data["isCompleted"] as? Bool ?? false
        )
    }
}
