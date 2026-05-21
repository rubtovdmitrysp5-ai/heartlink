import Foundation
import CoreLocation

struct Memory: Identifiable, Codable, Hashable {
    let id: String
    var coupleId: String
    var title: String
    var note: String
    var imageURL: URL?
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var date: Date
    var createdBy: String

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static let samples: [Memory] = [
        Memory(
            id: "memory-1",
            coupleId: "couple-demo",
            title: "Первая поездка",
            note: "Тот самый дождливый день, когда мы смеялись без остановки.",
            imageURL: nil,
            locationName: "Санкт-Петербург",
            latitude: 59.9343,
            longitude: 30.3351,
            date: .now.addingTimeInterval(-86400 * 360),
            createdBy: "user-demo"
        ),
        Memory(
            id: "memory-2",
            coupleId: "couple-demo",
            title: "Кофе у окна",
            note: "Маленькое место, которое стало нашим.",
            imageURL: nil,
            locationName: "Москва",
            latitude: 55.7558,
            longitude: 37.6173,
            date: .now.addingTimeInterval(-86400 * 132),
            createdBy: "partner-demo"
        ),
        Memory(
            id: "memory-3",
            coupleId: "couple-demo",
            title: "Вечер без телефонов",
            note: "Только музыка, свечи и разговоры до ночи.",
            imageURL: nil,
            locationName: "Дом",
            latitude: nil,
            longitude: nil,
            date: .now.addingTimeInterval(-86400 * 24),
            createdBy: "user-demo"
        )
    ]
}

