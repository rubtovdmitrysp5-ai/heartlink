import Foundation
import Combine

@MainActor
final class LocalPairingService: ObservableObject {
    @Published private(set) var session: LocalPairingSession?
    @Published private(set) var isServerReachable = true
    @Published var baseURLString: String

    private let defaults: UserDefaults
    private let sessionKey = "localPairingSession"
    private let baseURLKey = "localPairingBaseURL"
    private let defaultBaseURLString = "http://192.168.100.4:3000"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.baseURLString = defaults.string(forKey: baseURLKey) ?? defaultBaseURLString
        self.session = Self.decodeSession(from: defaults.data(forKey: sessionKey))
    }

    var needsPairingFlow: Bool {
        session?.setupComplete != true
    }

    func updateBaseURL(_ value: String) {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let didChange = normalizedValue != baseURLString
        baseURLString = normalizedValue
        defaults.set(baseURLString, forKey: baseURLKey)

        if didChange, session?.userId.hasPrefix("offline-") == true {
            reset()
        }
    }

    func startSession() async {
        if let session {
            await refreshSession(userId: session.userId)
            return
        }

        do {
            let response: PairingStartResponse = try await request(
                path: "/api/session/start",
                method: "POST",
                body: ["deviceName": "iPhone"]
            )
            apply(response.session)
            isServerReachable = true
        } catch {
            isServerReachable = false
            apply(Self.makeOfflineSession())
        }
    }

    func refreshSession(userId: String) async {
        do {
            let response: PairingSessionResponse = try await request(path: "/api/session/\(userId)", method: "GET")
            apply(response.session)
            isServerReachable = true
        } catch {
            isServerReachable = false
        }
    }

    func linkPartner(code: String) async throws {
        guard let userId = session?.userId else { return }
        let response: PairingSessionResponse = try await request(
            path: "/api/pairing/link",
            method: "POST",
            body: [
                "userId": userId,
                "partnerCode": code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            ]
        )
        apply(response.session)
        isServerReachable = true
    }

    func createTestPartner() async throws {
        guard let userId = session?.userId else { return }

        do {
            let response: PairingSessionResponse = try await request(
                path: "/api/dev/create-test-partner",
                method: "POST",
                body: ["userId": userId]
            )
            apply(response.session)
            isServerReachable = true
        } catch {
            isServerReachable = false
            var offline = session ?? Self.makeOfflineSession()
            offline.coupleId = "offline-couple"
            offline.partnerId = "offline-partner"
            offline.partnerName = "Партнер"
            apply(offline)
        }
    }

    func completeSetup(displayName: String, partnerName: String, startedAt: Date) async throws {
        guard let userId = session?.userId else { return }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPartnerName = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let response: PairingSessionResponse = try await request(
                path: "/api/profile",
                method: "PATCH",
                body: [
                    "userId": userId,
                    "displayName": trimmedName,
                    "partnerName": trimmedPartnerName,
                    "relationshipStartedAt": Self.isoFormatter.string(from: startedAt)
                ]
            )
            apply(response.session)
            isServerReachable = true
        } catch {
            isServerReachable = false
            var offline = session ?? Self.makeOfflineSession()
            offline.displayName = trimmedName
            offline.partnerName = trimmedPartnerName
            offline.relationshipStartedAt = startedAt
            offline.setupComplete = true
            apply(offline)
        }
    }

    func reset() {
        session = nil
        defaults.removeObject(forKey: sessionKey)
    }

    private func apply(_ session: LocalPairingSession) {
        self.session = session
        if let data = try? Self.encoder.encode(session) {
            defaults.set(data, forKey: sessionKey)
        }
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: [String: String]? = nil
    ) async throws -> Response {
        guard let baseURL = URL(string: baseURLString), let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try Self.decoder.decode(Response.self, from: data)
    }

    private static func decodeSession(from data: Data?) -> LocalPairingSession? {
        guard let data else { return nil }
        return try? decoder.decode(LocalPairingSession.self, from: data)
    }

    private static func makeOfflineSession() -> LocalPairingSession {
        LocalPairingSession(
            userId: "offline-\(UUID().uuidString)",
            personalCode: "HL-\(Int.random(in: 100000...999999))",
            coupleId: nil,
            partnerId: nil,
            displayName: nil,
            partnerName: nil,
            relationshipStartedAt: nil,
            setupComplete: false
        )
    }

    private static let isoFormatter = ISO8601DateFormatter()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
