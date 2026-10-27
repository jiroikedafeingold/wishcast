import SwiftUI

/// What's happening right now. This part, sadly, can't be wished away.
struct CurrentConditionsView: View {
    let conditions: Conditions

    var body: some View {
        HStack(spacing: 16) {
            WeatherSymbol(name: conditions.symbolName)
                .font(.largeTitle)
            VStack(alignment: .leading) {
                Text(Metric.temperature.format(conditions.temperature))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                Text(conditions.summary)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("Feels like \(Metric.temperature.format(conditions.feelsLike))")
                Text("Humidity \((conditions.humidity / 100).formatted(.percent.precision(.fractionLength(0))))")
                Text("Wind \(Metric.wind.format(conditions.windSpeed))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
