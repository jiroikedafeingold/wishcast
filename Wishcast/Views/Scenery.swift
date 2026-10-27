import SwiftUI

/// The weather scene behind iPhone Duo's tabletop pages: a sky behind the day standing up, and the
/// ground seen from above behind the list lying on the table. Everything is drawn in code, kept soft
/// and low in contrast so it stays in the background, and only moves when Reduce Motion is off.
enum Scenery: String, CaseIterable, Identifiable {
    case sunny, partlyCloudy, cloudy, rain, thunderstorm, snow, windy, clearNight, partlyCloudyNight

    var id: Self { self }

    /// From a day's condition symbol (see `conditionSymbol`). Night only changes clear and partly cloudy skies.
    init(symbolName: String, isNight: Bool) {
        switch symbolName {
        case "cloud.snow.fill": self = .snow
        case "cloud.bolt.rain.fill": self = .thunderstorm
        case "cloud.rain.fill": self = .rain
        case "wind": self = .windy
        case "cloud.fill": self = .cloudy
        case "cloud.sun.fill", "cloud.moon.fill": self = isNight ? .partlyCloudyNight : .partlyCloudy
        default: self = isNight ? .clearNight : .sunny
        }
    }

    /// English name, for the gallery preview.
    var debugName: String {
        switch self {
        case .sunny: "Sunny"
        case .partlyCloudy: "Partly Cloudy"
        case .cloudy: "Cloudy"
        case .rain: "Rain"
        case .thunderstorm: "Thunderstorm"
        case .snow: "Snow"
        case .windy: "Windy"
        case .clearNight: "Clear Night"
        case .partlyCloudyNight: "Partly Cloudy Night"
        }
    }

    /// Light or dark appearance for each page, so text and materials contrast with the art.
    var skyColorScheme: ColorScheme {
        switch self {
        case .rain, .thunderstorm, .clearNight, .partlyCloudyNight: .dark
        default: .light
        }
    }

    var groundColorScheme: ColorScheme { self == .snow ? .light : .dark }

    fileprivate var skyGradient: [Color] {
        switch self {
        case .sunny: [rgb(0.24, 0.47, 0.80), rgb(0.50, 0.71, 0.93), rgb(0.82, 0.90, 0.97)]
        case .partlyCloudy: [rgb(0.32, 0.52, 0.78), rgb(0.56, 0.72, 0.89), rgb(0.84, 0.89, 0.94)]
        case .cloudy: [rgb(0.55, 0.60, 0.67), rgb(0.68, 0.72, 0.77), rgb(0.80, 0.82, 0.85)]
        case .rain: [rgb(0.22, 0.26, 0.32), rgb(0.33, 0.37, 0.43), rgb(0.47, 0.50, 0.55)]
        case .thunderstorm: [rgb(0.10, 0.10, 0.16), rgb(0.18, 0.18, 0.25), rgb(0.31, 0.29, 0.34)]
        case .snow: [rgb(0.70, 0.74, 0.80), rgb(0.80, 0.83, 0.88), rgb(0.90, 0.91, 0.94)]
        case .windy: [rgb(0.30, 0.50, 0.75), rgb(0.55, 0.70, 0.86), rgb(0.80, 0.86, 0.92)]
        case .clearNight: [rgb(0.03, 0.05, 0.14), rgb(0.07, 0.11, 0.25), rgb(0.15, 0.20, 0.36)]
        case .partlyCloudyNight: [rgb(0.05, 0.07, 0.16), rgb(0.09, 0.13, 0.26), rgb(0.17, 0.21, 0.34)]
        }
    }

    fileprivate var clouds: CloudStyle? {
        switch self {
        case .sunny: CloudStyle(count: 3, width: 0.22...0.34, height: 0.16, speed: 3...6, band: 0.2...0.55,
                                light: .white.opacity(0.85), shade: Color(white: 0.88).opacity(0.75), blur: 0.04)
        case .partlyCloudy: CloudStyle(count: 6, width: 0.3...0.5, height: 0.17, speed: 4...8, band: 0.12...0.7,
                                       light: .white.opacity(0.9), shade: Color(white: 0.84).opacity(0.8), blur: 0.04)
        case .cloudy: CloudStyle(count: 10, width: 0.6...0.95, height: 0.12, speed: 2...4, band: -0.05...0.85,
                                 light: Color(white: 0.93).opacity(0.45), shade: Color(white: 0.72).opacity(0.4), blur: 0.08)
        case .rain: CloudStyle(count: 10, width: 0.6...0.95, height: 0.13, speed: 4...7, band: -0.05...0.6,
                               light: rgb(0.52, 0.55, 0.60).opacity(0.55), shade: rgb(0.26, 0.29, 0.34).opacity(0.6), blur: 0.08)
        case .thunderstorm: CloudStyle(count: 11, width: 0.6...1.0, height: 0.16, speed: 6...10, band: -0.05...0.55,
                                       light: rgb(0.34, 0.33, 0.40).opacity(0.7), shade: rgb(0.10, 0.10, 0.14).opacity(0.75), blur: 0.07)
        case .snow: CloudStyle(count: 9, width: 0.6...0.95, height: 0.12, speed: 2...4, band: -0.05...0.7,
                               light: Color(white: 0.97).opacity(0.5), shade: Color(white: 0.8).opacity(0.35), blur: 0.09)
        case .windy: CloudStyle(count: 7, width: 0.5...0.85, height: 0.05, speed: 28...45, band: 0.08...0.7,
                                light: .white.opacity(0.6), shade: Color(white: 0.86).opacity(0.45), blur: 0.06, stretch: 3.5)
        case .clearNight: nil
        case .partlyCloudyNight: CloudStyle(count: 5, width: 0.3...0.5, height: 0.15, speed: 3...6, band: 0.15...0.7,
                                            light: rgb(0.36, 0.40, 0.55).opacity(0.75), shade: rgb(0.12, 0.15, 0.25).opacity(0.8), blur: 0.05)
        }
    }
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(red: red, green: green, blue: blue)
}

// MARK: - Readability over scenery

extension EnvironmentValues {
    /// True on iPhone Duo's tabletop pages, where content sits over `Scenery` art.
    @Entry var onScenery = false
    /// True on iPhone Duo's two-page layouts (tabletop and upright), where each page scrolls on its own.
    @Entry var showsScrollHints = false
}

extension View {
    /// A tile's background: a faint fill normally, frosted over scenery so its text stays readable.
    func tileBackground() -> some View { modifier(TileBackground()) }

    /// Puts loose text (headings, captions) on a frosted card over scenery; unchanged elsewhere.
    func sceneryCard() -> some View { modifier(SceneryCard()) }

    /// A small frosted backing for list headers, footers and the tag line over scenery.
    func sceneryLegible() -> some View { modifier(SceneryLegible()) }

    /// On the Duo's two-page layouts, makes it obvious a page scrolls: the scroll bars flash when it
    /// appears, and a chevron shows at each edge with more content beyond it. Unchanged elsewhere.
    func sceneryScrollHints() -> some View { modifier(SceneryScrollHints()) }
}

private struct SceneryScrollHints: ViewModifier {
    @Environment(\.showsScrollHints) private var showsScrollHints
    @State private var more = MoreContent()

    struct MoreContent: Equatable {
        var above = false
        var below = false
    }

    func body(content: Content) -> some View {
        if showsScrollHints {
            content
                .scrollIndicatorsFlash(onAppear: true)
                .onScrollGeometryChange(for: MoreContent.self) { geometry in
                    let top = -geometry.contentInsets.top
                    let bottom = geometry.contentSize.height + geometry.contentInsets.bottom - geometry.containerSize.height
                    return MoreContent(above: geometry.contentOffset.y > top + 4,
                                       below: geometry.contentOffset.y < bottom - 4)
                } action: { _, newValue in
                    withAnimation(.easeInOut(duration: 0.25)) { more = newValue }
                }
                .overlay(alignment: .top) {
                    if more.above { hint("chevron.compact.up") }
                }
                .overlay(alignment: .bottom) {
                    if more.below { hint("chevron.compact.down") }
                }
        } else {
            content
        }
    }

    private func hint(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 1)
            .background(.thickMaterial, in: .capsule)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
            .padding(6)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.opacity)
    }
}

private struct TileBackground: ViewModifier {
    @Environment(\.onScenery) private var onScenery

    func body(content: Content) -> some View {
        if onScenery {
            content.background(.regularMaterial, in: .rect(cornerRadius: 16))
        } else {
            content.background(.fill.quaternary, in: .rect(cornerRadius: 16))
        }
    }
}

private struct SceneryCard: ViewModifier {
    @Environment(\.onScenery) private var onScenery

    func body(content: Content) -> some View {
        if onScenery {
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: .rect(cornerRadius: 16))
        } else {
            content
        }
    }
}

private struct SceneryLegible: ViewModifier {
    @Environment(\.onScenery) private var onScenery

    func body(content: Content) -> some View {
        if onScenery {
            content
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: .rect(cornerRadius: 10))
        } else {
            content
        }
    }
}

// MARK: - Sky

/// The upper page: a sky for the scene, with sun or moon, clouds, and rain, snow or lightning.
struct SkyScenery: View {
    let scenery: Scenery
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: scenery.skyGradient, startPoint: .top, endPoint: .bottom)
            switch scenery {
            case .sunny:
                Glow(center: UnitPoint(x: 0.85, y: 0.08), color: rgb(1, 0.97, 0.85), opacity: 0.8, radius: 260)
            case .partlyCloudy:
                Glow(center: UnitPoint(x: 0.8, y: 0.1), color: rgb(1, 0.96, 0.85), opacity: 0.55, radius: 220)
            case .windy:
                Glow(center: UnitPoint(x: 0.85, y: 0.08), color: rgb(1, 0.97, 0.88), opacity: 0.45, radius: 200)
            case .clearNight, .partlyCloudyNight:
                Glow(center: UnitPoint(x: 0.8, y: 0.12), color: rgb(0.75, 0.82, 1), opacity: 0.3, radius: 180)
            default:
                EmptyView()
            }
            animated { time in
                SkyLayers(scenery: scenery, time: time, flashes: !reduceMotion)
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func animated<Content: View>(@ViewBuilder _ content: @escaping (Double) -> Content) -> some View {
        if reduceMotion {
            content(0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                content(timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

private struct Glow: View {
    let center: UnitPoint
    let color: Color
    let opacity: Double
    let radius: CGFloat

    var body: some View {
        RadialGradient(colors: [color.opacity(opacity), .clear], center: center, startRadius: 0, endRadius: radius)
            .blendMode(.screen)
    }
}

/// Everything in the sky that moves, drawn in one canvas.
private struct SkyLayers: View {
    let scenery: Scenery
    let time: Double
    /// Lightning flashes, off with Reduce Motion.
    let flashes: Bool

    var body: some View {
        Canvas { context, size in
            if scenery == .clearNight || scenery == .partlyCloudyNight {
                drawStars(in: &context, size: size, count: scenery == .clearNight ? 90 : 45)
                drawMoon(in: &context, size: size)
            }
            if let style = scenery.clouds {
                drawClouds(in: &context, size: size, style: style)
            }
            switch scenery {
            case .rain: drawRain(in: &context, size: size, count: 80, opacity: 0.22)
            case .thunderstorm:
                drawRain(in: &context, size: size, count: 110, opacity: 0.26)
                if flashes { drawLightning(in: &context, size: size) }
            case .snow: drawSnow(in: &context, size: size)
            default: break
            }
        }
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, count: Int) {
        var random = SeededRandom(state: 0x57A25)
        for _ in 0..<count {
            let x = Double.random(in: 0...1, using: &random) * size.width
            // Fewer stars toward the horizon, where the sky is lighter.
            let y = pow(Double.random(in: 0...1, using: &random), 1.6) * size.height * 0.85
            let radius = Double.random(in: 0.5...1.4, using: &random)
            let phase = Double.random(in: 0...(2 * .pi), using: &random)
            let twinkle = 0.55 + 0.45 * sin(time * Double.random(in: 0.6...1.6, using: &random) + phase)
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(.white.opacity(0.75 * twinkle)))
        }
    }

    private func drawMoon(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.8, y: size.height * 0.12)
        let radius = 16.0
        var moon = context
        moon.addFilter(.blur(radius: 0.6))
        moon.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                  with: .color(rgb(0.95, 0.95, 0.88).opacity(0.92)))
        // A few soft maria so it reads as the moon rather than a white dot.
        for (dx, dy, r) in [(-4.0, -3.0, 4.5), (5.0, 2.0, 3.5), (-1.0, 6.0, 2.5)] {
            moon.fill(Path(ellipseIn: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2)),
                      with: .color(rgb(0.78, 0.79, 0.76).opacity(0.5)))
        }
    }

    private func drawClouds(in context: inout GraphicsContext, size: CGSize, style: CloudStyle) {
        var random = SeededRandom(state: 0xC10D5 &+ UInt64(style.count))
        for _ in 0..<style.count {
            let width = Double.random(in: style.width, using: &random) * size.width
            let speed = Double.random(in: style.speed, using: &random)
            let span = size.width + width * 2
            let startX = Double.random(in: 0...span, using: &random)
            let left = (startX + time * speed).truncatingRemainder(dividingBy: span) - width
            let base = Double.random(in: style.band, using: &random) * size.height
            var cloud = context
            cloud.addFilter(.blur(radius: width * style.blur))
            // A flat, shaded underside, then rounded puffs piled higher in the middle.
            cloud.fill(Path(ellipseIn: CGRect(x: left, y: base - width * style.height * 0.5,
                                              width: width, height: width * style.height)),
                       with: .color(style.shade))
            let puffs = 7
            for index in 0..<puffs {
                let along = (Double(index) + 0.5) / Double(puffs)
                let lift = sin(along * .pi)
                let diameter = width * style.height * (1.1 + 1.2 * lift) * Double.random(in: 0.85...1.15, using: &random)
                let center = CGPoint(x: left + along * width,
                                     y: base - width * style.height * (0.3 + 0.7 * lift) + Double.random(in: -3...3, using: &random))
                let puffWidth = diameter * style.stretch
                cloud.fill(Path(ellipseIn: CGRect(x: center.x - puffWidth / 2, y: center.y - diameter / 2,
                                                  width: puffWidth, height: diameter * 0.85)),
                           with: .color(style.light))
            }
        }
    }

    private func drawRain(in context: inout GraphicsContext, size: CGSize, count: Int, opacity: Double) {
        var random = SeededRandom(state: 0x7A1)
        for _ in 0..<count {
            let x = Double.random(in: -20...size.width, using: &random)
            let startY = Double.random(in: 0...1, using: &random)
            let speed = Double.random(in: 520...820, using: &random)
            let length = Double.random(in: 12...22, using: &random)
            let fall = size.height + length
            let y = (startY * fall + time * speed).truncatingRemainder(dividingBy: fall) - length
            // Rain slants a little with the wind; drift x along with the fall.
            let slant = 0.18
            var streak = Path()
            streak.move(to: CGPoint(x: x + (y + length) * slant * 0.2, y: y))
            streak.addLine(to: CGPoint(x: x + (y + length) * slant * 0.2 + length * slant, y: y + length))
            context.stroke(streak, with: .color(.white.opacity(opacity)), lineWidth: 1)
        }
    }

    private func drawSnow(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(state: 0x5A0)
        for _ in 0..<70 {
            let x = Double.random(in: 0...size.width, using: &random)
            let startY = Double.random(in: 0...1, using: &random)
            let speed = Double.random(in: 18...42, using: &random)
            let radius = Double.random(in: 1...2.8, using: &random)
            let phase = Double.random(in: 0...(2 * .pi), using: &random)
            let fall = size.height + 10
            let y = (startY * fall + time * speed).truncatingRemainder(dividingBy: fall) - 5
            let sway = 10 * sin(time * 0.6 + phase)
            context.fill(Path(ellipseIn: CGRect(x: x + sway - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(.white.opacity(0.85)))
        }
    }

    private func drawLightning(in context: inout GraphicsContext, size: CGSize) {
        let flash = lightningIntensity(at: time)
        guard flash > 0 else { return }
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.22 * flash)))
        guard flash > 0.4 else { return }
        // A new jagged bolt each cycle, from the clouds partway down the sky.
        var random = SeededRandom(state: UInt64(time / lightningPeriod) &* 0x9E37)
        var point = CGPoint(x: Double.random(in: 0.2...0.8, using: &random) * size.width, y: size.height * 0.15)
        var bolt = Path()
        bolt.move(to: point)
        let bottom = size.height * Double.random(in: 0.55...0.8, using: &random)
        while point.y < bottom {
            point = CGPoint(x: point.x + Double.random(in: -18...18, using: &random),
                            y: point.y + Double.random(in: 10...24, using: &random))
            bolt.addLine(to: point)
        }
        var glow = context
        glow.addFilter(.blur(radius: 4))
        glow.stroke(bolt, with: .color(rgb(0.8, 0.85, 1).opacity(0.6 * flash)), lineWidth: 4)
        context.stroke(bolt, with: .color(.white.opacity(0.85 * flash)), lineWidth: 1.4)
    }
}

private struct CloudStyle {
    let count: Int
    /// Width as a fraction of the sky's width.
    let width: ClosedRange<Double>
    /// Puff height relative to the cloud's width: small values make long, streaky clouds.
    let height: Double
    /// Points per second, left to right.
    let speed: ClosedRange<Double>
    /// Vertical band (fraction of the height) the clouds sit in.
    let band: ClosedRange<Double>
    let light: Color
    let shade: Color
    /// Blur relative to the cloud's width.
    let blur: Double
    /// How much wider than tall each puff is; wind draws clouds out into streaks.
    var stretch: Double = 1
}

private let lightningPeriod = 9.0

/// 0…1: a quick double flash once every `lightningPeriod` seconds, shared by sky and ground.
private func lightningIntensity(at time: Double) -> Double {
    let phase = time.truncatingRemainder(dividingBy: lightningPeriod)
    if phase < 0.15 { return 1 - phase / 0.15 }
    if phase > 0.25 && phase < 0.4 { return 0.7 * (1 - (phase - 0.25) / 0.15) }
    return 0
}

// MARK: - Hinge

/// The strip over iPhone Duo's hinge, with the app's name set like a title card between fine rules.
/// On a table (the default) it's the horizon where the sky page meets the ground page: the sky's
/// color fading into far-off rolling hills. With `blendsIn` (the upright layout, where the pages have
/// plain backgrounds) it's a simple band in the scene's colors that fades into the pages.
struct HingeHorizon: View {
    let scenery: Scenery
    var blendsIn = false

    var body: some View {
        let colors = scenery.horizon
        GeometryReader { proxy in
            let size = min(max(proxy.size.height * 0.5, 15), 30)
            HStack(spacing: size * 0.5) {
                rule(colors.title, leading: true)
                Text(verbatim: "Sunnyside")
                    .font(.system(size: size, weight: .medium, design: .serif).smallCaps())
                    .italic()
                    .tracking(size * 0.12)
                    .lineLimit(1)
                rule(colors.title, leading: false)
            }
            .foregroundStyle(titleStyle(colors.title))
            .shadow(color: colors.title == .white ? .black.opacity(0.3) : .white.opacity(0.5), radius: 2)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if blendsIn {
                    LinearGradient(colors: [colors.far, colors.near], startPoint: .top, endPoint: .bottom)
                        .mask {
                            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.35),
                                                   .init(color: .black, location: 0.65), .init(color: .clear, location: 1)],
                                           startPoint: .top, endPoint: .bottom)
                        }
                } else {
                    ZStack {
                        LinearGradient(colors: [scenery.skyGradient.last ?? .white, colors.far.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom)
                        Canvas { context, size in
                            context.fill(hills(in: size, crest: 0.35, seed: 0xFA2), with: .color(colors.far))
                            context.fill(hills(in: size, crest: 0.6, seed: 0x4EA2), with: .color(colors.near))
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Light titles get a faint warm sheen, like gilt lettering; dark ones stay solid.
    private func titleStyle(_ color: Color) -> AnyShapeStyle {
        guard color == .white else { return AnyShapeStyle(color) }
        return AnyShapeStyle(LinearGradient(colors: [.white, rgb(1, 0.92, 0.74), .white],
                                            startPoint: .leading, endPoint: .trailing))
    }

    /// A soft line of hills whose crests sit around `crest` (fraction of the height from the top).
    private func hills(in size: CGSize, crest: Double, seed: UInt64) -> Path {
        var random = SeededRandom(state: seed)
        let waves = (0..<3).map { _ in
            (length: Double.random(in: 60...180, using: &random), phase: Double.random(in: 0...(2 * .pi), using: &random))
        }
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for x in Array(stride(from: 0.0, to: size.width, by: 4)) + [size.width] {
            let wave = waves.reduce(0) { $0 + sin(x / $1.length * 2 * .pi + $1.phase) } / Double(waves.count)
            path.addLine(to: CGPoint(x: x, y: size.height * (crest + 0.18 * wave)))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }

    /// A hairline that fades away from the title.
    private func rule(_ color: Color, leading: Bool) -> some View {
        LinearGradient(colors: [color.opacity(0), color.opacity(0.7)],
                       startPoint: leading ? .leading : .trailing, endPoint: leading ? .trailing : .leading)
            .frame(maxWidth: 90, maxHeight: 1)
    }
}

private extension Scenery {
    /// Far and near hills (also the upright band's gradient), tinted by the weather, and a title color that stands out on them.
    var horizon: (far: Color, near: Color, title: Color) {
        switch self {
        case .sunny, .partlyCloudy, .windy: (rgb(0.42, 0.58, 0.45), rgb(0.20, 0.36, 0.18), .white)
        case .cloudy: (rgb(0.50, 0.56, 0.54), rgb(0.26, 0.34, 0.25), .white)
        case .rain: (rgb(0.36, 0.42, 0.43), rgb(0.16, 0.24, 0.17), .white)
        case .thunderstorm: (rgb(0.24, 0.24, 0.30), rgb(0.08, 0.13, 0.09), .white)
        case .snow: (rgb(0.80, 0.84, 0.90), rgb(0.91, 0.93, 0.97), rgb(0.30, 0.35, 0.45))
        case .clearNight, .partlyCloudyNight: (rgb(0.12, 0.16, 0.28), rgb(0.04, 0.08, 0.10), .white)
        }
    }
}

// MARK: - Ground

/// The lower page: the ground seen from above, lit to match the sky.
struct GroundScenery: View {
    let scenery: Scenery
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch scenery {
            case .sunny:
                GrassBlades(palette: .shade)
                GrassBlades(palette: .sun).mask { animated { DappleMask(time: $0, strength: 1) } }
            case .partlyCloudy:
                // Sunlit patches only in full sun; under passing clouds the light is soft and even.
                GrassBlades(palette: .bright)
            case .cloudy:
                GrassBlades(palette: .dull)
            case .rain:
                Asphalt(isStorm: false)
                animated { PuddleRipples(time: $0, flash: 0) }
            case .thunderstorm:
                Asphalt(isStorm: true)
                animated { PuddleRipples(time: $0, flash: reduceMotion ? 0 : lightningIntensity(at: $0)) }
            case .snow:
                SnowField()
            case .windy:
                // The blades themselves bend as gusts sweep across the lawn; the light doesn't change.
                animated { GrassBlades(palette: .overcast, time: $0) }
            case .clearNight:
                GrassBlades(palette: .night)
                GrassBlades(palette: .moonlit).mask {
                    RadialGradient(colors: [.white.opacity(0.6), .clear], center: UnitPoint(x: 0.8, y: 0), startRadius: 0, endRadius: 420)
                }
            case .partlyCloudyNight:
                GrassBlades(palette: .night)
                GrassBlades(palette: .moonlit).mask {
                    animated { time in
                        RadialGradient(colors: [.white.opacity(0.25 + 0.2 * (0.5 + 0.5 * sin(time * 0.12))), .clear],
                                       center: UnitPoint(x: 0.8, y: 0), startRadius: 0, endRadius: 420)
                    }
                }
            }
            // A soft scrim under the navigation title so it reads over the art.
            LinearGradient(colors: [scenery.groundColorScheme == .dark ? .black.opacity(0.35) : .white.opacity(0.45), .clear],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3))
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func animated<Content: View>(@ViewBuilder _ content: @escaping (Double) -> Content) -> some View {
        if reduceMotion {
            content(0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                content(timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

private struct GrassPalette {
    let ground: [Color]
    let hueShift: Double
    let saturation: Double
    let brightness: Double

    static let shade = GrassPalette(ground: [rgb(0.10, 0.25, 0.08), rgb(0.05, 0.16, 0.05)], hueShift: 0, saturation: 0.75, brightness: 0.8)
    static let sun = GrassPalette(ground: [rgb(0.42, 0.62, 0.18), rgb(0.25, 0.45, 0.10)], hueShift: -0.04, saturation: 0.62, brightness: 1.75)
    static let overcast = GrassPalette(ground: [rgb(0.17, 0.30, 0.13), rgb(0.10, 0.21, 0.09)], hueShift: 0, saturation: 0.5, brightness: 1.05)
    /// Under a full overcast: dark, grey-green and flat.
    static let dull = GrassPalette(ground: [rgb(0.10, 0.16, 0.10), rgb(0.06, 0.10, 0.07)], hueShift: 0.02, saturation: 0.3, brightness: 0.72)
    static let bright = GrassPalette(ground: [rgb(0.20, 0.34, 0.14), rgb(0.12, 0.24, 0.09)], hueShift: -0.01, saturation: 0.55, brightness: 1.2)
    static let night = GrassPalette(ground: [rgb(0.04, 0.09, 0.10), rgb(0.02, 0.05, 0.07)], hueShift: 0.12, saturation: 0.45, brightness: 0.5)
    static let moonlit = GrassPalette(ground: [rgb(0.12, 0.20, 0.24), rgb(0.08, 0.14, 0.18)], hueShift: 0.15, saturation: 0.3, brightness: 0.95)
}

/// A tiny deterministic random generator, so the art looks the same on every redraw.
private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A lawn seen from above. The same blades every time (same seed); the palette sets the light.
/// With a `time`, wind bends the blades: gusts roll across left to right over a gentle flutter.
private struct GrassBlades: View {
    let palette: GrassPalette
    var time: Double?

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: palette.ground), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var random = SeededRandom(state: 0x5EED)
            // Back to front, so nearer (lower, longer, brighter) blades overlap farther ones.
            let count = Int(size.width * size.height / 38)
            for index in 0..<count {
                let depth = Double(index) / Double(count)
                let x = Double.random(in: -10...(size.width + 10), using: &random)
                let base = size.height * (0.05 + 0.98 * depth) + Double.random(in: -12...12, using: &random)
                let length = (10 + 26 * depth) * Double.random(in: 0.7...1.3, using: &random)
                var lean = Double.random(in: -0.45...0.45, using: &random) * length
                var reach = length
                if let time {
                    // A gust is a soft crest travelling across the lawn; blades it reaches lie over and
                    // look shorter from above.
                    let gust = pow(0.5 + 0.5 * sin((x - time * 110) / 85 + base * 0.012), 3)
                    let flutter = 0.07 * sin(time * 3.1 + x * 0.09 + base * 0.05)
                    lean += length * (0.55 * gust + flutter)
                    reach = length * (1 - 0.25 * gust)
                }
                var blade = Path()
                blade.move(to: CGPoint(x: x - 1.6, y: base))
                blade.addQuadCurve(to: CGPoint(x: x + lean, y: base - reach),
                                   control: CGPoint(x: x + lean * 0.2, y: base - reach * 0.6))
                blade.addQuadCurve(to: CGPoint(x: x + 1.6, y: base),
                                   control: CGPoint(x: x + lean * 0.3, y: base - reach * 0.5))
                blade.closeSubpath()
                let hue = Double.random(in: 0.25...0.32, using: &random)
                let shade = (0.30 + 0.30 * depth) * Double.random(in: 0.8...1.15, using: &random)
                context.fill(blade, with: .color(Color(hue: hue + palette.hueShift, saturation: palette.saturation,
                                                       brightness: min(shade * palette.brightness, 0.98))))
            }
        }
    }
}

/// Where sunlight gets through the leaves overhead: soft, irregular patches that sway and brighten.
private struct DappleMask: View {
    let time: Double
    /// 0…1, how strong the sunlight is.
    let strength: Double

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let span = max(size.width, size.height)
            var random = SeededRandom(state: 0xD4991E)
            for _ in 0..<22 {
                let anchor = CGPoint(x: Double.random(in: -0.05...1.05, using: &random) * size.width,
                                     y: Double.random(in: -0.05...1.05, using: &random) * size.height)
                let speed = Double.random(in: 0.2...0.5, using: &random)
                let phase = Double.random(in: 0...(2 * .pi), using: &random)
                let sway = CGPoint(x: 9 * sin(time * speed + phase), y: 6 * cos(time * speed * 0.7 + phase))
                let flicker = (0.75 + 0.25 * sin(time * speed * 2.1 + phase)) * strength
                for _ in 0..<3 {
                    let offset = CGPoint(x: Double.random(in: -0.04...0.04, using: &random) * span,
                                         y: Double.random(in: -0.03...0.03, using: &random) * span)
                    let radius = Double.random(in: 0.04...0.1, using: &random) * span
                    let center = CGPoint(x: anchor.x + offset.x + sway.x, y: anchor.y + offset.y + sway.y)
                    context.fill(Path(rect), with: .radialGradient(
                        Gradient(stops: [.init(color: .white.opacity(0.95 * flicker), location: 0),
                                         .init(color: .white.opacity(0.6 * flicker), location: 0.55),
                                         .init(color: .clear, location: 1)]),
                        center: center, startRadius: 0, endRadius: radius))
                }
            }
        }
    }
}

/// Puddles on the asphalt, the same for every redraw so the ripples land inside them.
private struct Puddle {
    let center: CGPoint
    let radius: Double
    let path: Path
}

private func puddles(in size: CGSize) -> [Puddle] {
    var random = SeededRandom(state: 0xB0D1E)
    // One per cell of a 2 × 3 grid, jittered, so they spread across the whole surface.
    return (0..<6).map { index in
        let column = Double(index % 2), row = Double(index / 2)
        let center = CGPoint(x: (column + Double.random(in: 0.2...0.8, using: &random)) / 2 * size.width,
                             y: (row + Double.random(in: 0.25...0.75, using: &random)) / 3 * size.height)
        let radius = Double.random(in: 10...28, using: &random)
        // A few overlapping waves around the rim make the outline irregular.
        let lobes = (0..<3).map { _ in
            (count: Double(Int.random(in: 2...5, using: &random)), depth: Double.random(in: 0.06...0.2, using: &random),
             phase: Double.random(in: 0...(2 * .pi), using: &random))
        }
        var path = Path()
        for step in 0...60 {
            let angle = Double(step) / 60 * 2 * .pi
            let scale = 1 + lobes.reduce(0) { $0 + $1.depth * sin($1.count * angle + $1.phase) }
            // Wider than deep, as puddles spread along the surface.
            let point = CGPoint(x: center.x + radius * scale * cos(angle) * 1.5, y: center.y + radius * scale * sin(angle) * 0.8)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return Puddle(center: center, radius: radius, path: path)
    }
}

/// Wet asphalt seen from above: fine aggregate, a couple of hairline cracks and puddles reflecting the sky.
private struct Asphalt: View {
    let isStorm: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let base = isStorm ? [rgb(0.11, 0.115, 0.125), rgb(0.08, 0.085, 0.095)] : [rgb(0.17, 0.18, 0.19), rgb(0.12, 0.13, 0.14)]
            context.fill(Path(rect), with: .linearGradient(Gradient(colors: base), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var random = SeededRandom(state: 0xA5FA17)
            // Aggregate: tiny light and dark stones.
            for _ in 0..<Int(size.width * size.height / 14) {
                let x = Double.random(in: 0...size.width, using: &random)
                let y = Double.random(in: 0...size.height, using: &random)
                let radius = Double.random(in: 0.4...1.1, using: &random)
                let tone = Double.random(in: 0.05...0.42, using: &random)
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(Color(white: tone).opacity(0.45)))
            }
            // Hairline cracks.
            for _ in 0..<3 {
                var point = CGPoint(x: Double.random(in: 0...size.width, using: &random), y: Double.random(in: 0...size.height, using: &random))
                var crack = Path()
                crack.move(to: point)
                for _ in 0..<Int.random(in: 6...12, using: &random) {
                    point = CGPoint(x: point.x + Double.random(in: -14...14, using: &random), y: point.y + Double.random(in: 4...16, using: &random))
                    crack.addLine(to: point)
                }
                context.stroke(crack, with: .color(.black.opacity(0.35)), lineWidth: 0.8)
            }
            // A wet sheen across the surface.
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [.white.opacity(0.06), .clear, .white.opacity(0.04)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            // Puddles: darker water reflecting the grey sky, with a soft bright rim.
            let reflection = isStorm ? [rgb(0.22, 0.22, 0.28), rgb(0.12, 0.12, 0.16)] : [rgb(0.40, 0.44, 0.50), rgb(0.24, 0.27, 0.32)]
            for puddle in puddles(in: size) {
                var water = context
                water.addFilter(.blur(radius: 1.5))
                water.fill(puddle.path, with: .linearGradient(
                    Gradient(colors: reflection),
                    startPoint: CGPoint(x: puddle.center.x, y: puddle.center.y - puddle.radius),
                    endPoint: CGPoint(x: puddle.center.x, y: puddle.center.y + puddle.radius)))
                water.stroke(puddle.path, with: .color(.white.opacity(0.1)), lineWidth: 1)
            }
        }
    }
}

/// Raindrops landing in the puddles (spreading rings) and on the asphalt (brief splashes).
/// `flash` lights the puddles when lightning strikes.
private struct PuddleRipples: View {
    let time: Double
    let flash: Double

    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(state: 0x219)
            for puddle in puddles(in: size) {
                var water = context
                water.clip(to: puddle.path)
                if flash > 0 {
                    water.fill(puddle.path, with: .color(rgb(0.85, 0.9, 1).opacity(0.4 * flash)))
                }
                for _ in 0..<5 {
                    let center = CGPoint(x: puddle.center.x + Double.random(in: -1...1, using: &random) * puddle.radius,
                                         y: puddle.center.y + Double.random(in: -0.5...0.5, using: &random) * puddle.radius)
                    let period = Double.random(in: 1.2...2.4, using: &random)
                    let phase = Double.random(in: 0...period, using: &random)
                    let progress = (time + phase).truncatingRemainder(dividingBy: period) / period
                    let radius = 1.5 + 14 * progress
                    let fade = (1 - progress) * (1 - progress)
                    water.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.6,
                                                        width: radius * 2, height: radius * 1.2)),
                                 with: .color(.white.opacity(0.35 * fade)), lineWidth: 1)
                }
            }
            // Splashes on the open asphalt.
            for _ in 0..<40 {
                let point = CGPoint(x: Double.random(in: 0...size.width, using: &random), y: Double.random(in: 0...size.height, using: &random))
                let period = Double.random(in: 0.8...1.8, using: &random)
                let phase = Double.random(in: 0...period, using: &random)
                let progress = (time + phase).truncatingRemainder(dividingBy: period) / period
                guard progress < 0.18 else { continue }
                let radius = 0.8 + 2 * progress / 0.18
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius * 0.7, width: radius * 2, height: radius * 1.4)),
                             with: .color(.white.opacity(0.3 * (1 - progress / 0.18))))
            }
            if flash > 0 {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(rgb(0.85, 0.9, 1).opacity(0.08 * flash)))
            }
        }
    }
}

/// Fresh snow seen from above: soft drifts with blue shadows, a few grass tips, and a line of
/// footprints crossing it.
private struct SnowField: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [rgb(0.93, 0.95, 0.98), rgb(0.83, 0.87, 0.93)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var random = SeededRandom(state: 0x5D0)
            // Drifts: soft shadowed hollows and brighter crests.
            var drifts = context
            drifts.addFilter(.blur(radius: 18))
            for _ in 0..<26 {
                let center = CGPoint(x: Double.random(in: 0...size.width, using: &random),
                                     y: Double.random(in: 0...size.height, using: &random))
                let width = Double.random(in: 80...200, using: &random)
                let height = width * Double.random(in: 0.25...0.45, using: &random)
                let shadow = Bool.random(using: &random)
                drifts.fill(Path(ellipseIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)),
                            with: .color(shadow ? rgb(0.66, 0.73, 0.86).opacity(0.35) : .white.opacity(0.7)))
            }
            // A few grass tips poking through.
            for _ in 0..<Int(size.width * size.height / 2500) {
                let x = Double.random(in: 0...size.width, using: &random)
                let y = Double.random(in: 0...size.height, using: &random)
                let length = Double.random(in: 3...6, using: &random)
                let lean = Double.random(in: -3...3, using: &random)
                var tip = Path()
                tip.move(to: CGPoint(x: x, y: y))
                tip.addQuadCurve(to: CGPoint(x: x + lean, y: y - length), control: CGPoint(x: x, y: y - length * 0.6))
                context.stroke(tip, with: .color(rgb(0.38, 0.45, 0.32).opacity(0.28)), lineWidth: 1.2)
            }
            drawFootprints(in: &context, size: size)
        }
    }

    /// Someone walked across: left and right boot prints along a gentle curve from bottom left to top right.
    private func drawFootprints(in context: inout GraphicsContext, size: CGSize) {
        let start = CGPoint(x: size.width * 0.08, y: size.height * 1.02)
        let control = CGPoint(x: size.width * 0.35, y: size.height * 0.35)
        let end = CGPoint(x: size.width * 1.02, y: size.height * 0.12)
        func point(_ t: Double) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                           y: u * u * start.y + 2 * u * t * control.y + t * t * end.y)
        }
        // About one print every 18 points along the way.
        let length = hypot(control.x - start.x, control.y - start.y) + hypot(end.x - control.x, end.y - control.y)
        let steps = Int(length * 0.85 / 18)
        for step in 0..<steps {
            let t = (Double(step) + 0.5) / Double(steps)
            let here = point(t)
            let ahead = point(min(t + 0.01, 1))
            let heading = atan2(ahead.y - here.y, ahead.x - here.x)
            // Feet sit a little either side of the path, alternating.
            let side: Double = step.isMultiple(of: 2) ? 1 : -1
            let center = CGPoint(x: here.x - sin(heading) * 5 * side, y: here.y + cos(heading) * 5 * side)
            var footprint = context
            footprint.translateBy(x: center.x, y: center.y)
            footprint.rotate(by: .radians(heading + .pi / 2))
            footprint.addFilter(.blur(radius: 0.8))
            let shadow = GraphicsContext.Shading.color(rgb(0.58, 0.65, 0.80).opacity(0.45))
            // Sole (toward the heading) and heel, with a brighter lip where snow was pushed up.
            let sole = Path(ellipseIn: CGRect(x: -4, y: -9, width: 8, height: 10))
            let heel = Path(ellipseIn: CGRect(x: -3.2, y: 2.5, width: 6.4, height: 6))
            footprint.fill(sole, with: shadow)
            footprint.fill(heel, with: shadow)
            footprint.stroke(Path(ellipseIn: CGRect(x: -4.6, y: -9.8, width: 9.2, height: 11.4)), with: .color(.white.opacity(0.7)), lineWidth: 0.8)
        }
    }
}

#Preview("Scenery") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(Scenery.allCases) { scenery in
                VStack(spacing: 2) {
                    SkyScenery(scenery: scenery).frame(height: 150)
                    GroundScenery(scenery: scenery).frame(height: 150)
                    Text(verbatim: scenery.debugName).font(.caption2)
                }
            }
        }
        .padding(8)
    }
}

#Preview("Readability") {
    HStack(spacing: 4) {
        ForEach([Scenery.sunny, .thunderstorm, .snow]) { scenery in
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(spacing: 4) {
                        Text(verbatim: "62° / 48°").font(.title.bold())
                        Text(verbatim: "Best case for Nice & Pleasant").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .sceneryCard()
                    Text(verbatim: "H: 3 of 220").padding().tileBackground()
                }
                .padding(8)
                .frame(maxHeight: .infinity, alignment: .top)
                .background { SkyScenery(scenery: scenery) }
                .environment(\.colorScheme, scenery.skyColorScheme)
                List {
                    Section {
                        Text(verbatim: "Tue   61° / 47°").listRowBackground(Rectangle().fill(.regularMaterial))
                        Text(verbatim: "Wed   58° / 45°").listRowBackground(Rectangle().fill(.regularMaterial))
                        ForEach(0..<8, id: \.self) { _ in
                            Text(verbatim: "Thu   57° / 44°").listRowBackground(Rectangle().fill(.regularMaterial))
                        }
                    } header: {
                        Text(verbatim: "7-Day Outlook").sceneryLegible()
                    } footer: {
                        Text(verbatim: "This is a wish, not a prediction.").sceneryLegible()
                    }
                }
                .scrollContentBackground(.hidden)
                .sceneryScrollHints()
                .background { GroundScenery(scenery: scenery) }
                .environment(\.colorScheme, scenery.groundColorScheme)
            }
        }
    }
    .environment(\.onScenery, true)
}

#Preview("Hinge") {
    VStack(spacing: 6) {
        ForEach(Scenery.allCases) { scenery in
            HingeHorizon(scenery: scenery).frame(height: 28)
        }
    }
}
