import SwiftUI

/// A quiet, animated hint of the day's weather behind the main screens: a drifting sun glow, slow
/// clouds, fine rain, a rare soft flash, falling snow with footprints wandering across it, wind
/// streaks or twinkling stars. Everything is faint and slow so the data on top stays the focus.
/// Still with Reduce Motion; off entirely with the Settings switch.
struct AmbientBackground: View {
    let scenery: Scenery

    /// The same base color the screens use without the animation.
    #if os(iOS)
    private static let base = Color(uiColor: .systemGroupedBackground)
    #else
    private static let base = Color(nsColor: .windowBackgroundColor)
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if reduceMotion {
                AmbientLayer(scenery: scenery, time: 0, isDark: colorScheme == .dark, flashes: false)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
                    AmbientLayer(scenery: scenery, time: timeline.date.timeIntervalSinceReferenceDate,
                                 isDark: colorScheme == .dark, flashes: true)
                }
            }
        }
        .background(Self.base)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct AmbientLayer: View {
    let scenery: Scenery
    let time: Double
    let isDark: Bool
    let flashes: Bool

    var body: some View {
        Canvas { context, size in
            switch scenery {
            case .sunny:
                drawSunGlow(in: &context, size: size, strength: 1)
            case .partlyCloudy:
                drawSunGlow(in: &context, size: size, strength: 0.6)
                drawClouds(in: &context, size: size, count: 4, opacity: 0.55)
            case .cloudy:
                drawClouds(in: &context, size: size, count: 7, opacity: 0.6)
            case .rain:
                drawClouds(in: &context, size: size, count: 5, opacity: 0.45)
                drawRain(in: &context, size: size, count: 55)
            case .thunderstorm:
                drawClouds(in: &context, size: size, count: 6, opacity: 0.5)
                drawRain(in: &context, size: size, count: 70)
                if flashes { drawFlash(in: &context, size: size) }
            case .snow:
                drawFootprints(in: &context, size: size)
                drawSnow(in: &context, size: size)
            case .windy:
                drawWind(in: &context, size: size)
            case .clearNight, .partlyCloudyNight:
                drawStars(in: &context, size: size, count: scenery == .clearNight ? 50 : 28)
                if scenery == .partlyCloudyNight { drawClouds(in: &context, size: size, count: 3, opacity: 0.35) }
            }
        }
    }

    // MARK: - Pieces

    /// A warm glow in the top corner that slowly breathes, with faint rays turning around it.
    private func drawSunGlow(in context: inout GraphicsContext, size: CGSize, strength: Double) {
        let center = CGPoint(x: size.width * 0.88, y: size.height * 0.04)
        let breathe = 0.85 + 0.15 * sin(time * 0.4)
        let radius = max(size.width, 320) * 0.75
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [Color(red: 1, green: 0.84, blue: 0.45).opacity((isDark ? 0.18 : 0.32) * strength * breathe), .clear]),
            center: center, startRadius: 0, endRadius: radius))
        var rays = context
        rays.translateBy(x: center.x, y: center.y)
        rays.rotate(by: .radians(time * 0.03))
        for index in 0..<12 {
            let angle = Double(index) / 12 * 2 * .pi
            var ray = Path()
            ray.move(to: .zero)
            ray.addLine(to: CGPoint(x: cos(angle - 0.05) * radius, y: sin(angle - 0.05) * radius))
            ray.addLine(to: CGPoint(x: cos(angle + 0.05) * radius, y: sin(angle + 0.05) * radius))
            ray.closeSubpath()
            rays.fill(ray, with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.9, blue: 0.6).opacity((isDark ? 0.05 : 0.1) * strength), .clear]),
                center: .zero, startRadius: 0, endRadius: radius))
        }
    }

    private func drawClouds(in context: inout GraphicsContext, size: CGSize, count: Int, opacity: Double) {
        var random = SeededGenerator(seed: 0xA1B2)
        let tone = isDark ? Color(white: 0.55) : Color(white: 0.78)
        var clouds = context
        clouds.addFilter(.blur(radius: 18))
        for _ in 0..<count {
            let width = Double.random(in: 0.45...0.8, using: &random) * size.width
            let speed = Double.random(in: 4...9, using: &random)
            let span = size.width + width * 2
            let x = (Double.random(in: 0...span, using: &random) + time * speed).truncatingRemainder(dividingBy: span) - width
            let y = Double.random(in: 0...0.9, using: &random) * size.height
            let height = width * Double.random(in: 0.18...0.3, using: &random)
            clouds.fill(Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height)),
                        with: .color(tone.opacity(opacity * (isDark ? 0.35 : 0.5))))
        }
    }

    private func drawRain(in context: inout GraphicsContext, size: CGSize, count: Int) {
        var random = SeededGenerator(seed: 0x7A1)
        let color = (isDark ? Color(white: 0.8) : Color(red: 0.35, green: 0.5, blue: 0.7)).opacity(isDark ? 0.16 : 0.2)
        for _ in 0..<count {
            let x = Double.random(in: -20...size.width, using: &random)
            let speed = Double.random(in: 380...620, using: &random)
            let length = Double.random(in: 10...18, using: &random)
            let fall = size.height + length
            let y = (Double.random(in: 0...1, using: &random) * fall + time * speed).truncatingRemainder(dividingBy: fall) - length
            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y))
            streak.addLine(to: CGPoint(x: x + length * 0.15, y: y + length))
            context.stroke(streak, with: .color(color), lineWidth: 1)
        }
    }

    /// A soft brightening every 11 seconds or so, never a hard white flash.
    private func drawFlash(in context: inout GraphicsContext, size: CGSize) {
        let phase = time.truncatingRemainder(dividingBy: 11)
        let flash = phase < 0.25 ? 1 - phase / 0.25 : (phase > 0.4 && phase < 0.6 ? 0.5 * (1 - (phase - 0.4) / 0.2) : 0)
        guard flash > 0 else { return }
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.85, green: 0.9, blue: 1).opacity(0.12 * flash)))
    }

    private func drawSnow(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededGenerator(seed: 0x5A0)
        let color = isDark ? Color.white.opacity(0.35) : Color(red: 0.6, green: 0.7, blue: 0.85).opacity(0.45)
        for _ in 0..<45 {
            let x = Double.random(in: 0...size.width, using: &random)
            let speed = Double.random(in: 14...32, using: &random)
            let radius = Double.random(in: 1...2.4, using: &random)
            let phase = Double.random(in: 0...(2 * .pi), using: &random)
            let fall = size.height + 10
            let y = (Double.random(in: 0...1, using: &random) * fall + time * speed).truncatingRemainder(dividingBy: fall) - 5
            let sway = 8 * sin(time * 0.5 + phase)
            context.fill(Path(ellipseIn: CGRect(x: x + sway - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(color))
        }
    }

    /// Someone walking across the snow: prints appear one by one along a wandering path, linger,
    /// and fade, then a new walk starts somewhere else.
    private func drawFootprints(in context: inout GraphicsContext, size: CGSize) {
        let walk = 16.0
        let cycle = Int(time / walk)
        let progress = time.truncatingRemainder(dividingBy: walk) / walk
        var random = SeededGenerator(seed: UInt64(truncatingIfNeeded: cycle) &* 0x9E37 &+ 7)
        // A gentle curve between two random edges.
        let start = CGPoint(x: Double.random(in: -0.1...0.3, using: &random) * size.width,
                            y: Double.random(in: 0.2...1.0, using: &random) * size.height)
        let end = CGPoint(x: Double.random(in: 0.7...1.1, using: &random) * size.width,
                          y: Double.random(in: 0.0...0.8, using: &random) * size.height)
        let control = CGPoint(x: Double.random(in: 0.2...0.8, using: &random) * size.width,
                              y: Double.random(in: 0.1...0.9, using: &random) * size.height)
        func point(_ t: Double) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                           y: u * u * start.y + 2 * u * t * control.y + t * t * end.y)
        }
        // About one print every 26 points along the way.
        let length = hypot(control.x - start.x, control.y - start.y) + hypot(end.x - control.x, end.y - control.y)
        let steps = max(Int(length * 0.85 / 26), 6)
        let shown = Int(Double(steps) * min(progress / 0.7, 1))
        // The trail fades out over the last part of the walk.
        let trailFade = progress > 0.8 ? 1 - (progress - 0.8) / 0.2 : 1
        let shade = (isDark ? Color(white: 0.75) : Color(red: 0.55, green: 0.63, blue: 0.78))
        for step in 0..<shown {
            let t = (Double(step) + 0.5) / Double(steps)
            let here = point(t)
            let ahead = point(min(t + 0.01, 1))
            let heading = atan2(ahead.y - here.y, ahead.x - here.x)
            let side: Double = step.isMultiple(of: 2) ? 1 : -1
            var print = context
            print.translateBy(x: here.x - sin(heading) * 5 * side, y: here.y + cos(heading) * 5 * side)
            print.rotate(by: .radians(heading + .pi / 2))
            let opacity = (isDark ? 0.18 : 0.26) * trailFade
            print.fill(Path(ellipseIn: CGRect(x: -3.5, y: -8, width: 7, height: 9)), with: .color(shade.opacity(opacity)))
            print.fill(Path(ellipseIn: CGRect(x: -2.8, y: 2, width: 5.6, height: 5.5)), with: .color(shade.opacity(opacity)))
        }
    }

    private func drawWind(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededGenerator(seed: 0x3D)
        let color = (isDark ? Color(white: 0.8) : Color(red: 0.45, green: 0.55, blue: 0.65)).opacity(isDark ? 0.14 : 0.18)
        for _ in 0..<9 {
            let y = Double.random(in: 0...1, using: &random) * size.height
            let length = Double.random(in: 60...160, using: &random)
            let speed = Double.random(in: 70...130, using: &random)
            let span = size.width + length * 2
            let x = (Double.random(in: 0...span, using: &random) + time * speed).truncatingRemainder(dividingBy: span) - length
            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y))
            streak.addCurve(to: CGPoint(x: x + length, y: y - 6),
                            control1: CGPoint(x: x + length * 0.35, y: y + 6),
                            control2: CGPoint(x: x + length * 0.7, y: y - 10))
            context.stroke(streak, with: .color(color), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, count: Int) {
        var random = SeededGenerator(seed: 0x57A)
        let color = isDark ? Color.white : Color(red: 0.4, green: 0.45, blue: 0.7)
        for _ in 0..<count {
            let x = Double.random(in: 0...1, using: &random) * size.width
            let y = Double.random(in: 0...1, using: &random) * size.height
            let radius = Double.random(in: 0.6...1.5, using: &random)
            let phase = Double.random(in: 0...(2 * .pi), using: &random)
            let twinkle = 0.5 + 0.5 * sin(time * Double.random(in: 0.5...1.3, using: &random) + phase)
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(color.opacity((isDark ? 0.45 : 0.25) * twinkle)))
        }
    }
}

/// Deterministic randomness, so the layout of drops and flakes stays put between frames.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

#Preview("Ambient") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 8) {
            ForEach(Scenery.allCases) { scenery in
                AmbientBackground(scenery: scenery)
                    .frame(height: 260)
                    .overlay(alignment: .bottom) { Text(verbatim: scenery.debugName).font(.caption2) }
            }
        }
        .padding(8)
    }
}
