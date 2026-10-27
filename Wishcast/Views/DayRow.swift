import SwiftUI

struct DayRow: View {
    let day: WishcastDay
    let timeZone: TimeZone

    var body: some View {
        HStack(spacing: 12) {
            WeatherSymbol(name: day.symbolName)
                .font(.title2)
                .frame(minWidth: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(day.weekday(in: timeZone))
                    .font(.headline)
                // How many forecasts show the high and low in this row, so outliers are obvious.
                Text("H: \(day.high.sameValueCount) of \(day.high.sampleSize) · L: \(day.low.sameValueCount) of \(day.low.sampleSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            // Let the count line use the room it needs before the temperatures do.
            .layoutPriority(1)
            Spacer(minLength: 8)
            Text("\(Metric.temperature.format(day.high.value)) / \(Metric.temperature.format(day.low.value))")
                .font(.headline)
                .monospacedDigit()
                .fixedSize()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("\(day.high.sameValueCount) of \(day.high.sampleSize) forecasts show this high, and \(day.low.sameValueCount) of \(day.low.sampleSize) show this low.")
    }
}
