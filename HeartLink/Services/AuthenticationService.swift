import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class AuthenticationService {
    private(set) var state: AuthenticationState = .checking
    private(set) var isFirebaseEnabled: Bool
    private var authHandle: AuthStateDidChangeListenerHandle?

    init(isFirebaseEnabled: Bool) {
        self.isFirebaseEnabled = isFirebaseEnabled
    }

    func start() {
        guard isFirebaseEnabled else {
            state = .signedIn(SampleDataStore.currentUser)
            return
        }

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                guard let user else {
                    self.state = .signedOut
                    return
                }

                do {
                    let profile = try await self.fetchProfile(userId: user.uid, email: user.email ?? "")
                    self.state = .signedIn(profile)
                } catch {
                    self.state = .signedIn(UserProfile(
                        id: user.uid,
                        displayName: user.displayName ?? "Партнёр",
                        email: user.email ?? "",
                        avatarURL: user.photoURL,
                        currentMood: .happy,
                        partnerId: nil,
                        coupleId: nil,
                        createdAt: .now
                    ))
                }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        guard isFirebaseEnabled else {
            state = .signedIn(SampleDataStore.currentUser)
            return
        }

        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createAccount(name: String, email: String, password: String) async throws {
        guard isFirebaseEnabled else {
            state = .signedIn(UserProfile(
                id: UUID().uuidString,
                displayName: name,
                email: email,
                avatarURL: nil,
                currentMood: .happy,
                partnerId: nil,
                coupleId: nil,
                createdAt: .now
            ))
            return
        }

        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let request = result.user.createProfileChangeRequest()
        request.displayName = name
        try await request.commitChanges()

        let profile = UserProfile(
            id: result.user.uid,
            displayName: name,
            email: email,
            avatarURL: nil,
            currentMood: .happy,
            partnerId: nil,
            coupleId: nil,
            createdAt: .now
        )
        try await saveProfile(profile)
        state = .signedIn(profile)
    }

    func signOut() {
        guard isFirebaseEnabled else {
            state = .signedOut
            return
        }

        try? Auth.auth().signOut()
        state = .signedOut
    }

    private func fetchProfile(userId: String, email: String) async throws -> UserProfile {
        let snapshot = try await Firestore.firestore().collection("users").document(userId).getDocument()
        let data = snapshot.data() ?? [:]
        return UserProfile(
            id: userId,
            displayName: data["displayName"] as? String ?? "Партнёр",
            email: data["email"] as? String ?? email,
            avatarURL: (data["avatarURL"] as? String).flatMap(URL.init(string:)),
            currentMood: MoodStatus(rawValue: data["currentMood"] as? String ?? "") ?? .happy,
            partnerId: data["partnerId"] as? String,
            coupleId: data["coupleId"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now
        )
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        var data: [String: Any] = [
            "displayName": profile.displayName,
            "email": profile.email,
            "currentMood": profile.currentMood.rawValue,
            "createdAt": Timestamp(date: profile.createdAt)
        ]

        if let avatarURL = profile.avatarURL {
            data["avatarURL"] = avatarURL.absoluteString
        }

        if let partnerId = profile.partnerId {
            data["partnerId"] = partnerId
        }

        if let coupleId = profile.coupleId {
            data["coupleId"] = coupleId
        }

        try await Firestore.firestore().collection("users").document(profile.id).setData(data, merge: true)
    }
}
