import SwiftUI

/// A weather condition icon: Wishcast artwork sized to the surrounding font, or the
/// SF Symbol where there's no artwork. Keep the table in sync with `WeatherSymbol` in the iOS app.
struct WeatherIcon: View {
    let name: String

    var body: some View {
        if let asset = Self.artwork[name] {
            // The hidden SF Symbol sets the size from the font; the artwork is drawn over it.
            Image(systemName: name)
                .hidden()
                .overlay {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(1.2)
                }
                .accessibilityRepresentation { Image(systemName: name) }
        } else {
            Image(systemName: name)
                .symbolRenderingMode(.multicolor)
        }
    }

    private static let artwork: [String: String] = [
        "sun.max.fill": "weather-clear-day",
        "moon.stars.fill": "weather-clear-night",
        "cloud.sun.fill": "weather-partly-cloudy-day",
        "cloud.moon.fill": "weather-partly-cloudy-night",
        "cloud.fill": "weather-cloudy",
        "cloud.fog.fill": "weather-fog",
        "cloud.drizzle.fill": "weather-drizzle",
        "cloud.rain.fill": "weather-rain",
        "cloud.snow.fill": "weather-snow",
        "cloud.bolt.rain.fill": "weather-thunderstorms-rain",
        "wind": "weather-wind"
    ]
}
