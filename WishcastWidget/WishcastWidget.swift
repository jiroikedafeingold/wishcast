import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WishcastEntry {
        .sample
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> WishcastEntry {
        // Real data even in the widget gallery, so it never shows made-up numbers.
        await entry(for: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<WishcastEntry> {
        let entry = await entry(for: configuration)
        // Models update every 6–12 hours. Open-Meteo weighs each ensemble member like extra variables, so
        // a full download costs about 180 of the free 10,000 daily calls; refreshing every 3 hours keeps
        // the widget to about 1,500 a day, leaving room for the app.
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3 * 3600)))
    }

    private func entry(for configuration: ConfigurationAppIntent) async -> WishcastEntry {
        let wish = configuration.wish.resolved
        guard let place = configuration.place?.place ?? SharedSettings.place else {
            return WishcastEntry(date: .now, wish: wish, placeName: nil, current: nil, days: [])
        }
        guard let result = try? await OpenMeteoClient().forecasts(for: place) else {
            return WishcastEntry(date: .now, wish: wish, placeName: place.name, current: nil, days: [])
        }
        let days = WishcastDay.build(from: result.forecasts, wish: wish, preferences: SharedSettings.preferences)
        return WishcastEntry(
            date: .now,
            wish: wish,
            placeName: place.name,
            current: result.conditions.map { .init(temperature: $0.temperature, symbolName: $0.symbolName) },
            days: days.prefix(7).map { day in
                .init(
                    date: day.date,
                    weekday: day.weekday(in: result.timeZone, width: .abbreviated),
                    symbolName: day.symbolName,
                    high: day.high.value,
                    low: day.low.value,
                    highCount: day.high.sameValueCount,
                    lowCount: day.low.sameValueCount,
                    forecastCount: day.forecasts.count
                )
            }
        )
    }
}

/// A trimmed-down snapshot: widgets only need the picks, not all 200-plus forecasts.
struct WishcastEntry: TimelineEntry {
    struct Current {
        let temperature: Double
        let symbolName: String
    }

    struct Day: Identifiable {
        let date: Date
        let weekday: String
        let symbolName: String
        let high: Double
        let low: Double
        let highCount: Int
        let lowCount: Int
        let forecastCount: Int

        var id: Date { date }
        /// How many forecasts show this high and low, as in the app's day rows.
        var matchText: String { String(localized: "H: \(highCount) of \(forecastCount) \u{00B7} L: \(lowCount) of \(forecastCount)") }
    }

    let date: Date
    let wish: Wish
    let placeName: String?
    let current: Current?
    let days: [Day]

    static let sample = WishcastEntry(
        date: .now,
        wish: .pleasant,
        placeName: "Denver",
        current: Current(temperature: 18, symbolName: "sun.max.fill"),
        days: ["Today", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].enumerated().map { index, weekday in
            Day(date: .now.addingTimeInterval(Double(index) * 86_400), weekday: weekday,
                symbolName: index % 3 == 2 ? "cloud.sun.fill" : "sun.max.fill",
                high: 22 + Double(index % 3), low: 8 + Double(index % 2), highCount: 3, lowCount: 9, forecastCount: 220)
        }
    )
}

struct WishcastWidgetEntryView: View {
    var entry: WishcastEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            // A little more breathing room above and below than the default margins.
            .padding(.vertical, family.isAccessory ? 0 : 10)
    }

    @ViewBuilder
    private var content: some View {
        if entry.placeName == nil {
            Label("Open Wishcast to choose a location", systemImage: "mappin.and.ellipse")
                .font(.caption)
        } else if let today = entry.days.first {
            switch family {
            case .systemSmall: small(today)
            case .systemMedium: medium
            case .systemLarge, .systemExtraLarge: large
            #if os(iOS)
            // Lock Screen families exist only on iPhone (see supportedFamilies).
            case .accessoryInline: Label("\(today.weekday) \(temperatures(today))", systemImage: entry.wish.symbolName)
            case .accessoryRectangular: rectangular(today)
            #endif
            default: medium
            }
        } else {
            Label("Forecasts unavailable", systemImage: "exclamationmark.triangle")
                .font(.caption)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.wish.symbolName)
                .foregroundStyle(entry.wish.tint)
            Text(entry.placeName ?? "")
                .lineLimit(1)
            Spacer(minLength: 4)
            if let current = entry.current {
                WeatherSymbol(name: current.symbolName)
                Text(Metric.temperature.format(current.temperature))
            }
        }
        .font(.caption.weight(.semibold))
    }

    private var bestCaseNote: some View {
        Text("Best case for \(Text(entry.wish.title)). Not a prediction.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func small(_ day: WishcastEntry.Day) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            WeatherSymbol(name: day.symbolName)
                .font(.title)
            Text(temperatures(day))
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.7)
            Text(day.matchText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            bestCaseNote
            HStack {
                ForEach(entry.days.prefix(5)) { day in
                    VStack(spacing: 6) {
                        Text(day.weekday)
                            .font(.caption2.weight(.semibold))
                        WeatherSymbol(name: day.symbolName)
                            .font(.title3)
                        Text(Metric.temperature.format(day.high))
                            .font(.callout.weight(.semibold))
                        Text(Metric.temperature.format(day.low))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            bestCaseNote
            ForEach(entry.days) { day in
                HStack {
                    Text(day.weekday)
                        .font(.callout.weight(.semibold))
                        .frame(minWidth: 44, alignment: .leading)
                    WeatherSymbol(name: day.symbolName)
                    Text(day.matchText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(temperatures(day))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func rectangular(_ day: WishcastEntry.Day) -> some View {
        VStack(alignment: .leading) {
            Label {
                Text(entry.wish.title)
            } icon: {
                Image(systemName: entry.wish.symbolName)
            }
            .font(.headline)
            Text("\(day.weekday): \(temperatures(day))")
            Text(day.matchText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func temperatures(_ day: WishcastEntry.Day) -> String {
        "\(Metric.temperature.format(day.high)) / \(Metric.temperature.format(day.low))"
    }
}

struct WishcastWidget: Widget {
    let kind: String = "WishcastWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WishcastWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wishcast")
        .description("Best-case weather for your wish, mixed from many weather models and their ensemble members.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

#Preview(as: .systemSmall) {
    WishcastWidget()
} timeline: {
    WishcastEntry.sample
}

#Preview(as: .systemMedium) {
    WishcastWidget()
} timeline: {
    WishcastEntry.sample
}

#Preview(as: .systemLarge) {
    WishcastWidget()
} timeline: {
    WishcastEntry.sample
}

private extension WidgetFamily {
    var isAccessory: Bool {
        #if os(iOS)
        [.accessoryInline, .accessoryRectangular, .accessoryCircular].contains(self)
        #else
        false
        #endif
    }
}
