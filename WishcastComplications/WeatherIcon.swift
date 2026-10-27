import SwiftUI
import WidgetKit

/// A weather condition icon for complications and Smart Stack widgets: Wishcast's artwork, shown in
/// full color where the watch face allows it. Keep the table in sync with the watch app's WeatherIcon.
struct WeatherIcon: View {
    let name: String

    var body: some View {
        if let asset = Self.artwork[name] {
            Image(asset)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Image(systemName: name)
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
