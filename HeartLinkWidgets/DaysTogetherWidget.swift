import SwiftUI
import WidgetKit

struct DaysTogetherEntry: TimelineEntry {
    let date: Date
    let startedAt: Date
    let partnerName: String
    let partnerMood: String

    var daysTogether: Int {
        Calendar.current.dateComponents([.day], from: startedAt, to: date).day ?? 0
    }
}

struct DaysTogetherProvider: TimelineProvider {
    private let suiteName = "group.com.example.heartlink"

    func placeholder(in context: Context) -> DaysTogetherEntry {
        DaysTogetherEntry(date: .now, startedAt: .now.addingTimeInterval(-86400 * 486), partnerName: "Марк", partnerMood: "Скучает")
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysTogetherEntry) -> Void) {
        completion(makeEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysTogetherEntry>) -> Void) {
        let now = Date()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [makeEntry(date: now)], policy: .after(nextUpdate)))
    }

    private func makeEntry(date: Date) -> DaysTogetherEntry {
        let defaults = UserDefaults(suiteName: suiteName)
        return DaysTogetherEntry(
            date: date,
            startedAt: defaults?.object(forKey: "startedAt") as? Date ?? .now.addingTimeInterval(-86400 * 486),
            partnerName: defaults?.string(forKey: "partnerName") ?? "Партнёр",
            partnerMood: defaults?.string(forKey: "partnerMood") ?? "Скучает"
        )
    }
}

struct DaysTogetherWidget: Widget {
    let kind = "DaysTogetherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DaysTogetherProvider()) { entry in
            DaysTogetherWidgetView(entry: entry)
        }
        .configurationDisplayName("Дни вместе")
        .description("Показывает, сколько дней вы вместе.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct DaysTogetherWidgetView: View {
    let entry: DaysTogetherEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            Text("\(entry.daysTogether) \(daysText(entry.daysTogether)) вместе")
        default:
            smallView
        }
    }

    private var smallView: some View {
        ZStack {
            widgetGradient
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                Text("\(entry.daysTogether)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text(daysText(entry.daysTogether))
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .foregroundStyle(.white)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var mediumView: some View {
        ZStack {
            widgetGradient
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Вы вместе")
                        .font(.headline)
                    Text("\(entry.daysTogether)")
                        .font(.system(size: 50, weight: .heavy, design: .rounded))
                    Text(daysText(entry.daysTogether))
                        .font(.caption.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: "face.smiling")
                        .font(.title2)
                    Text(entry.partnerName)
                        .font(.headline)
                    Text(entry.partnerMood)
                        .font(.caption)
                }
            }
            .padding()
            .foregroundStyle(.white)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "heart.fill")
                Text("\(entry.daysTogether)")
                    .font(.headline.bold())
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("HeartLink")
                .font(.caption.bold())
            Text("\(entry.daysTogether) \(daysText(entry.daysTogether)) вместе")
                .font(.headline)
        }
    }

    private var widgetGradient: some View {
        LinearGradient(colors: [.pink, .purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func daysText(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "дней" }
        if last == 1 { return "день" }
        if (2...4).contains(last) { return "дня" }
        return "дней"
    }
}

#Preview(as: .systemSmall) {
    DaysTogetherWidget()
} timeline: {
    DaysTogetherEntry(date: .now, startedAt: .now.addingTimeInterval(-86400 * 486), partnerName: "Марк", partnerMood: "Скучает")
}

