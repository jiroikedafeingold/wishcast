import SwiftUI

extension Wish {
    var tint: Color {
        switch self {
        case .snow: .cyan
        case .sunny: .orange
        case .rainy: .blue
        case .wild: .purple
        case .coolEvenings: .indigo
        case .pleasant: .green
        }
    }
}

/// A weather condition icon: Meteocons artwork where there is one, otherwise an SF Symbol with
/// explicit layer colors (multicolor rendering draws clouds and moons white, which disappears on
/// light backgrounds).
struct WeatherSymbol: View {
    let name: String

    var body: some View {
        if let asset = Self.meteocons[name] {
            // The (hidden) SF Symbol sizes the icon to the surrounding font, so callers keep using
            // `.font(...)`; the Meteocons artwork (MIT, Bas Milius) is drawn over it.
            Image(systemName: name)
                .hidden()
                .overlay {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(1.35)
                        // Meteocons' pale clouds need a faint edge to show on light backgrounds.
                        .shadow(color: .black.opacity(0.18), radius: 0.8, y: 0.5)
                }
                .accessibilityRepresentation { Image(systemName: name) }
        } else {
            Image(systemName: name)
                .symbolRenderingMode(.palette)
                .foregroundStyle(colors.0, colors.1, colors.2)
        }
    }

    /// Meteocons artwork for each condition symbol the app uses.
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

    private var colors: (Color, Color, Color) {
        let cloud = Color.gray
        switch name {
        case "sun.max.fill": return (.yellow, .yellow, .yellow)
        case "moon.stars.fill": return (.indigo, .yellow, .yellow)
        case "cloud.sun.fill": return (cloud, .yellow, .yellow)
        case "cloud.moon.fill": return (cloud, .indigo, .indigo)
        case "cloud.rain.fill", "cloud.drizzle.fill": return (cloud, .blue, .blue)
        case "cloud.snow.fill": return (cloud, .cyan, .cyan)
        case "cloud.bolt.rain.fill": return (cloud, .blue, .yellow)
        default: return (cloud, cloud, cloud)
        }
    }
}

#Preview {
    let names: [String] = ["sun.max.fill", "moon.stars.fill", "cloud.sun.fill", "cloud.moon.fill", "cloud.fill",
                           "cloud.rain.fill", "cloud.snow.fill", "cloud.bolt.rain.fill", "cloud.fog.fill", "wind"]
    HStack {
        ForEach(names, id: \.self) { name in
            WeatherSymbol(name: name)
        }
    }
    .font(.title)
}
