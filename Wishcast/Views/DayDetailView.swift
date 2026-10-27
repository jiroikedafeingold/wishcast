import SwiftUI
import Charts

/// The best-case day, with every value's rule and source spelled out, and an honest look at the rest.
struct DayDetailView: View {
    let day: WishcastDay
    let wish: Wish
    let preferences: Preferences
    let timeZone: TimeZone
    /// Sunrise/sunset, UV and precipitation chance from Open-Meteo's best-match model, when available.
    let official: Conditions.Daily?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                pickedValues
                if let pick = day.hourlyPick, let source = pick.source, !source.hours.isEmpty {
                    hourly(from: source, pick: pick)
                } else if day.forecasts.allSatisfy({ $0.hours.isEmpty }) {
                    // Long-range forecasts are daily only.
                    Text("Only daily values are available this far out: no hourly forecast or evening temperature, and cloud cover is a 24-hour average.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                realityCheck
                ForecastSpreadChart(day: day, wish: wish)
                if let official {
                    officialDetails(official)
                }
            }
            .padding()
            // Keep a readable line length on iPad and Mac.
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(day.weekday(in: timeZone))
    }

    private var range: ForecastRange { ForecastRange(date: day.date, timeZone: timeZone) }

    private var header: some View {
        VStack(spacing: 8) {
            WeatherSymbol(name: day.symbolName)
                .font(.system(.largeTitle))
                .imageScale(.large)
            Text("\(Metric.temperature.format(day.high.value)) / \(Metric.temperature.format(day.low.value))")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
            Label {
                Text("\(Text(range.title)) for \(Text(wish.title))")
            } icon: {
                Image(systemName: range == .near ? wish.symbolName : "questionmark.circle")
            }
            .font(.subheadline.weight(.semibold))
            Text(range.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
            if range != .near {
                Text("\(day.forecasts.count) forecasts reach this date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Past the first week the title already includes the date.
            if range == .near {
                Text(day.shortDate(in: timeZone))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var pickedValues: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(day.values, id: \.field) { picked in
                ValueTile(picked: picked)
            }
        }
    }

    private func hourly(from source: DayForecast, pick: PickedValue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly: \(source.source)")
                .font(.headline)
            Group {
                if pick.sameValueCount > 1 {
                    Text("One of the \(pick.sameValueCount) forecasts that show this day's \(Text(pick.field.title)) value. The other values above may come from different forecasts, so these hours can look worse than the best case above.")
                } else {
                    Text("The forecast that supplied this day's \(Text(pick.field.title)) value. The other values above may come from different forecasts, so these hours can look worse than the best case above.")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HourlyStrip(hours: source.hours, timeZone: timeZone)
        }
    }

    private var realityCheck: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reality Check")
                .font(.headline)
            Text("\(day.matchCount) of \(day.forecasts.count) single forecasts match your wish.")
            ProgressView(value: day.matchFraction)
                .tint(wish.tint)
            Text("A match means one unmixed forecast shows: \(wish.matchDescription(preferences: preferences)) This is a count of forecasts, not a probability.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if let high = day.median({ $0.high }), let low = day.median({ $0.low }), let precipitation = day.median({ $0.precipitation }) {
                Text("Across all forecasts, the median high is \(Metric.temperature.format(high)), the median low is \(Metric.temperature.format(low)), and the median precipitation is \(Metric.rainfall.format(precipitation)).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
    }

    private func officialDetails(_ official: Conditions.Daily) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From Open-Meteo's Best-Match Forecast")
                .font(.headline)
            Text("Not part of the wish: these come from a single standard forecast.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                StatTile(title: "Sunrise", value: time(official.sunrise), symbol: "sunrise.fill")
                StatTile(title: "Sunset", value: time(official.sunset), symbol: "sunset.fill")
                if let uv = official.uvIndexMax {
                    StatTile(title: "UV Index", value: uv.formatted(.number.precision(.fractionLength(0))), symbol: "sun.max.fill")
                }
                if let chance = official.precipitationChance {
                    StatTile(title: "Precip Chance", value: (chance / 100).formatted(.percent.precision(.fractionLength(0))), symbol: "umbrella.fill")
                }
            }
        }
    }

    private func time(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}

/// One picked value, with how it was chosen and where it came from.
private struct ValueTile: View {
    let picked: PickedValue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                // Long-range (daily-only) forecasts report a 24-hour cloud average, not 8 AM–5 PM.
                if picked.field == .cloudCover, picked.source?.hours.isEmpty == true {
                    Text("Clouds (24-hr avg)")
                } else {
                    Text(picked.field.title)
                }
            } icon: {
                Image(systemName: picked.field.symbolName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(picked.field.metric.format(picked.value))
                .font(.title3.weight(.semibold))
            Text(picked.choice.describe(picked.field))
                .font(.caption)
            Text(picked.sourceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Reserve two lines so tiles side by side stay the same height.
                .lineLimit(2, reservesSpace: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

/// Hour-by-hour view of one forecast.
private struct HourlyStrip: View {
    let hours: [HourForecast]
    let timeZone: TimeZone

    /// For today, start from the current hour.
    private var visibleHours: [HourForecast] {
        let upcoming = hours.filter { $0.date > .now.addingTimeInterval(-3600) }
        return upcoming.isEmpty ? hours : upcoming
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                ForEach(visibleHours) { hour in
                    VStack(spacing: 8) {
                        Text(label(for: hour.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        WeatherSymbol(name: hour.symbolName)
                        Text(Metric.temperature.format(hour.temperature))
                            .font(.callout.weight(.medium))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
    }

    private func label(for date: Date) -> String {
        var style = Date.FormatStyle.dateTime.hour()
        style.timeZone = timeZone
        return date.formatted(style)
    }
}

/// Every forecast's value for the wish's key field, sorted, with the picked value highlighted.
private struct ForecastSpreadChart: View {
    let day: WishcastDay
    let wish: Wish

    private struct Point: Identifiable {
        let id: String
        let rank: Int
        let value: Double
        let isPick: Bool
    }

    private var points: [Point] {
        let field = wish.keyField
        let pickedID = day.value(field)?.source?.id
        return day.forecasts
            .compactMap { forecast in field.value(forecast).map { (forecast, field.metric.displayValue($0)) } }
            .sorted { $0.1 < $1.1 }
            .enumerated()
            .map { rank, entry in Point(id: entry.0.id, rank: rank, value: entry.1, isPick: entry.0.id == pickedID) }
    }

    var body: some View {
        let points = points
        let metric = wish.keyField.metric
        VStack(alignment: .leading, spacing: 8) {
            Text("Every Forecast: \(Text(wish.keyField.title))")
                .font(.headline)
            Text("Each dot is one of \(points.count) forecasts, sorted low to high. The big dot is the one picked, even when it's far from the rest.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart(points) { point in
                PointMark(x: .value("Forecast", point.rank), y: .value(metric.unitSymbol, point.value))
                    .symbolSize(point.isPick ? 200 : 20)
                    .foregroundStyle(point.isPick ? AnyShapeStyle(wish.tint) : AnyShapeStyle(.secondary.opacity(0.5)))
                    .annotation(position: .top, alignment: .trailing) {
                        // Label the pick so an outlier reads as intentional, not a glitch.
                        if point.isPick {
                            Text("Picked")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(wish.tint)
                        }
                    }
            }
            .chartXAxis(.hidden)
            // Keep the big highlighted dot clear of the y-axis labels.
            .chartXScale(range: .plotDimension(padding: 16))
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel(metric.unitSymbol)
            .frame(minHeight: 200)
        }
        .padding()
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
    }
}
