import Foundation
import SwiftUI

enum MoodStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case happy
    case sad
    case missYou
    case busy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .happy: "Радость"
        case .sad: "Грустно"
        case .missYou: "Скучаю"
        case .busy: "Занят"
        }
    }

    var partnerTitle: String {
        switch self {
        case .happy: "Радуется"
        case .sad: "Грустит"
        case .missYou: "Скучает"
        case .busy: "Занят"
        }
    }

    var symbolName: String {
        switch self {
        case .happy: "face.smiling"
        case .sad: "cloud.rain"
        case .missYou: "heart"
        case .busy: "moon.zzz"
        }
    }

    var tint: Color {
        switch self {
        case .happy: .pink
        case .sad: .indigo
        case .missYou: .red
        case .busy: .purple
        }
    }
}
