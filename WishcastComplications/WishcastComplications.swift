import WidgetKit
import SwiftUI

/// Complications show the last summary the iPhone sent: they don't download anything themselves.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: .now, summary: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        completion(SummaryEntry(date: .now, summary: WatchSummary.saved))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        // The watch app reloads complications whenever a new summary arrives from the iPhone.
        completion(Timeline(entries: [SummaryEntry(date: .now, summary: WatchSummary.saved)], policy: .never))
    }
}

struct SummaryEntry: TimelineEntry {
    let date: Date
    let summary: WatchSummary?
}

struct WishcastComplicationsEntryView: View {
    var entry: SummaryEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let summary = entry.summary, let today = summary.days.first {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: today.symbol)
                        .font(.caption)
                    Text(today.high)
                        .font(.headline)
                        .minimumScaleFactor(0.6)
                }
                .widgetAccentable()
            case .accessoryCorner:
                Image(systemName: today.symbol)
                    .font(.title3)
                    .widgetLabel { Text(verbatim: "\(today.high) / \(today.low)") }
            case .accessoryInline:
                Label {
                    Text(verbatim: "\(today.high) / \(today.low)")
                } icon: {
                    Image(systemName: summary.wishSymbol)
                }
            default:
                VStack(alignment: .leading, spacing: 1) {
                    Label(summary.wishTitle, systemImage: summary.wishSymbol)
                        .font(.caption2)
                        .foregroundStyle(wishTint(summary.wish))
                        .widgetAccentable()
                    HStack(spacing: 4) {
                        WeatherIcon(name: today.symbol)
                            .frame(width: 22, height: 22)
                        Text(verbatim: "\(summary.place) \(today.high) / \(today.low)")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(today.matchText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Image(systemName: "leaf")
                .accessibilityLabel("Wishcast")
        }
    }
}

struct WishcastComplications: Widget {
    let kind: String = "WishcastComplications"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WishcastComplicationsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wishcast")
        .description("Today's best case for your wish, from your iPhone.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

/// A Smart Stack widget: today and the next three days, each with its icon, high and low.
struct WishcastWeekWidget: Widget {
    let kind: String = "WishcastWeek"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WeekView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wishcast Week")
        .description("The best case for your wish over the next four days, from your iPhone.")
        .supportedFamilies([.accessoryRectangular])
    }
}

private struct WeekView: View {
    let entry: SummaryEntry

    var body: some View {
        if let summary = entry.summary, !summary.days.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: summary.wishSymbol)
                        .foregroundStyle(wishTint(summary.wish))
                    Text(summary.place)
                        .lineLimit(1)
                }
                .font(.caption2.weight(.semibold))
                .widgetAccentable()
                HStack(spacing: 0) {
                    ForEach(Array(summary.days.prefix(4).enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 0) {
                            Text(day.weekday)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            WeatherIcon(name: day.symbol)
                                .frame(width: 20, height: 20)
                            Text(day.high)
                                .font(.system(size: 13, weight: .semibold))
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        } else {
            Text("Open Wishcast on your iPhone.")
                .font(.caption2)
        }
    }
}

#Preview(as: .accessoryRectangular) {
    WishcastWeekWidget()
} timeline: {
    SummaryEntry(date: .now, summary: WatchSummary(
        place: "Denver", wishTitle: "nice and pleasant", wishSymbol: "leaf.fill", wish: "pleasant",
        note: "", updated: .now,
        days: ["Today", "Wed", "Thu", "Fri"].map { .init(weekday: $0, symbol: "sun.max.fill", high: "68°", low: "47°", matchText: "") }))
}

#Preview(as: .accessoryRectangular) {
    WishcastComplications()
} timeline: {
    SummaryEntry(date: .now, summary: WatchSummary(
        place: "Denver", wishTitle: "Nice & Pleasant", wishSymbol: "leaf.fill", wish: "pleasant",
        note: "Best case for Nice & Pleasant. Not a prediction.", updated: .now,
        days: [.init(weekday: "Today", symbol: "sun.max.fill", high: "68°", low: "47°", matchText: "H: 2 of 220 · L: 1 of 220")]))
}
