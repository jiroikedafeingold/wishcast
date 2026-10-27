import SwiftUI
import Charts
import WeatherKit

/// One official weather alert, as issued: what it is, who issued it, and a link to the full text.
struct WeatherAlertRow: View {
    let alert: WeatherAlert

    var body: some View {
        Link(destination: alert.detailsURL) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.summary)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    // The issuing agency is required attribution.
                    Text([alert.severity.description.capitalized, alert.source, alert.region].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHint("Opens the full alert.")
    }

    private var color: Color {
        switch alert.severity {
        case .extreme, .severe: .red
        case .moderate: .orange
        default: .yellow
        }
    }
}

/// Apple Weather's minute-by-minute precipitation for the next hour, as a summary and a small chart.
struct NextHourView: View {
    let forecast: Forecast<MinuteWeather>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(forecast.summary, systemImage: "cloud.rain")
                .font(.subheadline.weight(.semibold))
            Chart(Array(forecast.forecast.prefix(61).enumerated()), id: \.offset) { minute, weather in
                BarMark(x: .value("Minute", minute),
                        y: .value("Intensity", weather.precipitationIntensity.value))
                    .foregroundStyle(.blue.gradient)
            }
            .chartXAxis {
                AxisMarks(values: [0, 15, 30, 45, 60]) { value in
                    AxisValueLabel {
                        if let minute = value.as(Int.self) {
                            Text(minute == 0 ? String(localized: "Now") : String(localized: "\(minute) min"))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 60)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}
