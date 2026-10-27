import SwiftUI

extension Wish {
    var tint: Color {
        switch self {
        case .snow: .cyan
        case .sunny: .orange
        case .wild: .purple
        case .coolEvenings: .indigo
        case .pleasant: .green
        }
    }
}

/// A weather symbol with explicit layer colors. Multicolor rendering draws clouds and
/// moons white, which disappears on light backgrounds.
struct WeatherSymbol: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .symbolRenderingMode(.palette)
            .foregroundStyle(colors.0, colors.1, colors.2)
    }

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
