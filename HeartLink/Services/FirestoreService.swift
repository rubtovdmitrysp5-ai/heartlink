import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class FirestoreService {
    private let isFirebaseEnabled: Bool
    private var listeners: [ListenerRegistration] = []

    var couple: Couple = SampleDataStore.couple
    var partner: UserProfile = SampleDataStore.partner
    var messages: [ChatMessage] = SampleDataStore.messages
    var memories: [Memory] = SampleDataStore.memories
    var goals: [CoupleGoal] = SampleDataStore.goals
    var games: [LoveGame] = SampleDataStore.games

    init(isFirebaseEnabled: Bool) {
        self.isFirebaseEnabled = isFirebaseEnabled
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
        guard isFirebaseEnabled else { return }
        try? await Firestore.firestore().collection("users").document(userId).setData([
            "currentMood": mood.rawValue,
            "updatedAt": Timestamp(date: .now)
        ], merge: true)
    }

    func sendTextMessage(_ text: String, coupleId: String, authorId: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = ChatMessage(
            id: UUID().uuidString,
            coupleId: coupleId,
            authorId: authorId,
            text: trimmed,
            kind: .text,
            mediaURL: nil,
            voiceDuration: nil,
            reactions: [],
            sentAt: .now,
            isRead: false
        )

        await saveMessage(message)
    }

    func sendImageMessage(imageURL: URL?, coupleId: String, authorId: String) async {
        let message = ChatMessage(
            id: UUID().uuidString,
            coupleId: coupleId,
            authorId: authorId,
            text: "Фото",
            kind: .image,
            mediaURL: imageURL,
            voiceDuration: nil,
            reactions: [],
            sentAt: .now,
            isRead: false
        )

        await saveMessage(message)
    }

    func sendVoicePreviewMessage(coupleId: String, authorId: String) async {
        let message = ChatMessage(
            id: UUID().uuidString,
            coupleId: coupleId,
            authorId: authorId,
            text: "Голосовое сообщение",
            kind: .voice,
            mediaURL: nil,
            voiceDuration: 12,
            reactions: [],
            sentAt: .now,
            isRead: false
        )

        await saveMessage(message)
    }

    func addReaction(_ emoji: String, to message: ChatMessage, authorId: String) async {
        guard isFirebaseEnabled else {
            guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
            messages[index].reactions.append(ChatReaction(id: UUID().uuidString, emoji: emoji, authorId: authorId))
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

    func addMemory(title: String, note: String, locationName: String, imageURL: URL?, userId: String) async {
        let memory = Memory(
            id: UUID().uuidString,
            coupleId: couple.id,
            title: title,
            note: note,
            imageURL: imageURL,
            locationName: locationName,
            latitude: nil,
            longitude: nil,
            date: .now,
            createdBy: userId
        )

        guard isFirebaseEnabled else {
            memories.insert(memory, at: 0)
            return
        }

        try? await Firestore.firestore()
            .collection("couples")
            .document(couple.id)
            .collection("memories")
            .document(memory.id)
            .setData(memory.dictionary)
    }

    func updateGoalProgress(goal: CoupleGoal, progress: Double) async {
        let clamped = min(max(progress, 0), 1)

        guard isFirebaseEnabled else {
            guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
            goals[index].progress = clamped
            goals[index].isCompleted = clamped >= 1
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

    private func saveMessage(_ message: ChatMessage) async {
        if isFirebaseEnabled {
            try? await Firestore.firestore()
                .collection("couples")
                .document(message.coupleId)
                .collection("messages")
                .document(message.id)
                .setData(message.dictionary)
        } else {
            messages.append(message)
        }
    }
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
