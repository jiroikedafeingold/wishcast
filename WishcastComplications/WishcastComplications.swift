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
                    Text(verbatim: "\(summary.place) \(today.high) / \(today.low)")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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

#Preview(as: .accessoryRectangular) {
    WishcastComplications()
} timeline: {
    SummaryEntry(date: .now, summary: WatchSummary(
        place: "Denver", wishTitle: "Nice & Pleasant", wishSymbol: "leaf.fill", wish: "pleasant",
        note: "Best case for Nice & Pleasant. Not a prediction.", updated: .now,
        days: [.init(weekday: "Today", symbol: "sun.max.fill", high: "68°", low: "47°", matchText: "H: 2 of 220 · L: 1 of 220")]))
}
