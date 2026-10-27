import SwiftUI

/// A weather condition icon: Meteocons artwork (MIT, Bas Milius) sized to the surrounding font, or the
/// SF Symbol where there's no artwork. Keep the table in sync with `WeatherSymbol` in the iOS app.
struct WeatherIcon: View {
    let name: String

    var body: some View {
        if let asset = Self.meteocons[name] {
            // The hidden SF Symbol sets the size from the font; the artwork is drawn over it.
            Image(systemName: name)
                .hidden()
                .overlay {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(1.35)
                }
                .accessibilityRepresentation { Image(systemName: name) }
        } else {
            Image(systemName: name)
                .symbolRenderingMode(.multicolor)
        }
    }

    private static let meteocons: [String: String] = [
        "sun.max.fill": "meteocon-clear-day",
        "moon.stars.fill": "meteocon-clear-night",
        "cloud.sun.fill": "meteocon-partly-cloudy-day",
        "cloud.moon.fill": "meteocon-partly-cloudy-night",
        "cloud.fill": "meteocon-cloudy",
        "cloud.fog.fill": "meteocon-fog",
        "cloud.drizzle.fill": "meteocon-drizzle",
        "cloud.rain.fill": "meteocon-rain",
        "cloud.snow.fill": "meteocon-snow",
        "cloud.bolt.rain.fill": "meteocon-thunderstorms-rain",
        "wind": "meteocon-wind"
    ]
}
