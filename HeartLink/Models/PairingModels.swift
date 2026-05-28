import Foundation

enum PairingPhase: String, Codable {
    case waitingForPartner
    case setupProfile
    case complete
}

struct LocalPairingSession: Codable, Equatable {
    var userId: String
    var personalCode: String
    var coupleId: String?
    var partnerId: String?
    var displayName: String?
    var partnerName: String?
    var avatarURL: URL?
    var partnerAvatarURL: URL?
    var relationshipStartedAt: Date?
    var setupComplete: Bool

    var phase: PairingPhase {
        if setupComplete { return .complete }
        if coupleId != nil { return .setupProfile }
        return .waitingForPartner
    }
}

struct PairingStartResponse: Codable {
    let session: LocalPairingSession
}

struct PairingSessionResponse: Codable {
    let session: LocalPairingSession
}
