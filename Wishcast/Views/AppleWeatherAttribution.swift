import SwiftUI
import WeatherKit

/// The Apple Weather mark and legal link that WeatherKit's terms require wherever its data is shown.
struct AppleWeatherAttribution: View {
    let attribution: WeatherAttribution
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text(attribution.serviceName)
            }
            .frame(height: 12)
            .accessibilityLabel(attribution.serviceName)
            Link("Other data sources", destination: attribution.legalPageURL)
        }
    }
}
