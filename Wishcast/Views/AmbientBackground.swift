import SwiftUI
#if os(iOS)
import CoreHaptics
import UIKit
#endif

/// An animated hint of the day's weather behind the main screens: sunshine, clouds drifting over a
/// peeking sun, rain, lightning (with a soft haptic rumble), drifting snow with footprints wandering
/// across it, tumbling leaves blown on the wind, or twinkling stars. Cards sit on top, so the data stays
/// readable. Still with Reduce Motion; off entirely with the Settings switch.
struct AmbientBackground: View {
    let scenery: Scenery
    /// The system appearance (the screen may force dark styling on top of a light-mode page).
    var systemIsDark = false
    /// Whether this copy plays the thunder rumble. When the list and the day are both on screen,
    /// each strike still rumbles only once (see `ThunderHaptics.rumble(forStrikeAt:)`).
    var playsThunder = true

    /// The page color behind the animation: a light grey in light mode (so white cards stand out
    /// and the weather shows), the system's dark grouped background in dark mode.
    /// The page color for each kind of weather. Light mode: sky blue for sunshine, pale blue-grey
    /// when partly cloudy, dark grey for everything else; dark mode: muted blue, darker blue-grey,
    /// black. Nights are black in both.
    static func pageColor(for scenery: Scenery, systemIsDark: Bool) -> Color {
        switch (scenery, systemIsDark) {
        case (.sunny, false): Color(red: 0.53, green: 0.76, blue: 0.95)
        case (.sunny, true): Color(red: 0.12, green: 0.2, blue: 0.32)
        case (.partlyCloudy, false): Color(red: 0.78, green: 0.83, blue: 0.88)
        case (.partlyCloudy, true): Color(red: 0.17, green: 0.2, blue: 0.24)
        case (.cloudy, false), (.rain, false), (.thunderstorm, false), (.snow, false), (.windy, false):
            Color(red: 0.2, green: 0.21, blue: 0.23)
        default: .black
        }
    }

    /// Whether the page is dark enough that text sitting on it needs light (dark-mode) styling.
    static func isDarkPage(for scenery: Scenery, systemIsDark: Bool) -> Bool {
        systemIsDark || !(scenery == .sunny || scenery == .partlyCloudy)
    }

    static let base = Color.adaptive(light: Color(red: 0.88, green: 0.89, blue: 0.91),
                                    dark: Color(red: 0, green: 0, blue: 0))
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if reduceMotion {
                AmbientLayer(scenery: scenery, time: 0, isDark: colorScheme == .dark, flashes: false)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    AmbientLayer(scenery: scenery, time: timeline.date.timeIntervalSinceReferenceDate,
                                 isDark: colorScheme == .dark, flashes: true)
                }
            }
        }
        .background(Self.pageColor(for: scenery, systemIsDark: systemIsDark))
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        // Thunder follows each lightning strike: a short, strong rumble.
        .task(id: playsThunder && scenery == .thunderstorm && !reduceMotion) {
            guard playsThunder, scenery == .thunderstorm, !reduceMotion else { return }
            ThunderHaptics.shared.prepare()
            while !Task.isCancelled {
                let now = Date.timeIntervalSinceReferenceDate
                let strike = Lightning.nextStrike(after: now)
                try? await Task.sleep(for: .seconds(max(strike - now + 0.35, 0.1)))
                guard !Task.isCancelled else { return }
                ThunderHaptics.shared.rumble(forStrikeAt: strike)
            }
        }
    }
}

// MARK: - Lightning schedule

/// When lightning strikes: one strike in every 6.5-second slot at a random moment, and sometimes a
/// second one soon after. Shared by the drawing and the haptic rumble so they line up.
private enum Lightning {
    static let slot = 6.5

    /// Strike times (seconds since the reference date) in the slot containing `time`.
    static func strikes(inSlot index: Int) -> [Double] {
        var random = SeededGenerator(seed: UInt64(bitPattern: Int64(index)) &* 0x9E37_79B9 &+ 11)
        let first = Double(index) * slot + Double.random(in: 0.3...4.5, using: &random)
        let double = Double.random(in: 0...1, using: &random) < 0.35
        return double ? [first, first + Double.random(in: 0.7...1.4, using: &random)] : [first]
    }

    /// 0…1 brightness at `time`, plus a seed for that strike's bolt shape.
    static func flash(at time: Double) -> (intensity: Double, seed: UInt64) {
        let index = Int((time / slot).rounded(.down))
        for (number, strike) in (strikes(inSlot: index - 1) + strikes(inSlot: index)).enumerated() {
            let age = time - strike
            guard age >= 0, age < 0.45 else { continue }
            // A bright stroke, a dip, and a weaker re-strike, as real lightning flickers.
            let intensity = age < 0.12 ? 1 - age / 0.12 * 0.5 : (age < 0.2 ? 0.25 : 0.6 * (1 - (age - 0.2) / 0.25))
            return (max(intensity, 0), UInt64(bitPattern: Int64(index)) &* 31 &+ UInt64(number))
        }
        return (0, 0)
    }

    static func nextStrike(after time: Double) -> Double {
        let index = Int((time / slot).rounded(.down))
        return (strikes(inSlot: index) + strikes(inSlot: index + 1)).first { $0 > time } ?? time + slot
    }
}

/// A short, strong thunder rumble. Everything runs on its own queue, so starting the haptic engine
/// (which can take a moment the first time) never stalls the screen.
nonisolated private final class ThunderHaptics: @unchecked Sendable {
    static let shared = ThunderHaptics()
    private let queue = DispatchQueue(label: "Sunnyside.thunder", qos: .userInitiated)
    #if os(iOS)
    private var engine: CHHapticEngine?
    private var pattern: CHHapticPattern?

    /// Creates and starts the engine ahead of the first strike.
    func prepare() {
        queue.async { [self] in _ = readyEngine() }
    }

    /// The strike that last rumbled, so two backgrounds on screen don't both play it.
    private var lastStrike: Double = -1

    /// A sharp crack, then a rolling rumble, once per strike.
    func rumble(forStrikeAt strike: Double) {
        queue.async { [self] in
            guard strike != lastStrike else { return }
            lastStrike = strike
            guard let engine = readyEngine(), let pattern = makePattern() else { return }
            do {
                try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
            } catch {
                self.engine = nil
                // If Core Haptics fails right now, at least give a single strong tap.
                DispatchQueue.main.async {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
                }
            }
        }
    }

    /// On `queue` only.
    private func readyEngine() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        do {
            if engine == nil {
                let engine = try CHHapticEngine()
                engine.isAutoShutdownEnabled = true
                // After the system resets or stops the engine (e.g. in the background), make a new one.
                engine.resetHandler = { [weak self] in self?.queue.async { self?.engine = nil } }
                engine.stoppedHandler = { [weak self] _ in self?.queue.async { self?.engine = nil } }
                self.engine = engine
            }
            try engine?.start()
            return engine
        } catch {
            engine = nil
            return nil
        }
    }

    /// As strong as the Taptic Engine allows: a full-strength, sharp crack, then a full-strength
    /// rumble with hard knocks rolling through it. Built once.
    private func makePattern() -> CHHapticPattern? {
        if let pattern { return pattern }
        var events = [CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        ], relativeTime: 0)]
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        ], relativeTime: 0.03, duration: 1.2))
        for offset in [0.12, 0.3, 0.5, 0.75, 1.0] {
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: offset))
        }
        // Full strength for most of it, tapering only at the very end.
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 1), .init(relativeTime: 0.9, value: 1), .init(relativeTime: 1.23, value: 0.3)
        ], relativeTime: 0.03)
        pattern = try? CHHapticPattern(events: events, parameterCurves: [fade])
        return pattern
    }
    #else
    func prepare() {}
    func rumble(forStrikeAt strike: Double) {}
    #endif
}

// MARK: - Drawing

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
                drawSunDisc(in: &context, size: size, strength: 1)
            case .partlyCloudy:
                // A smaller, dimmer sun that the clouds keep drifting across.
                drawSunGlow(in: &context, size: size, strength: 0.35, rays: false)
                drawSunDisc(in: &context, size: size, strength: 0.55)
                drawSunCoveringClouds(in: &context, size: size)
                drawClouds(in: &context, size: size, count: 9, opacity: 0.75, seed: 0xC1)
            case .cloudy:
                drawClouds(in: &context, size: size, count: 16, opacity: 0.85, seed: 0xC2)
            case .rain:
                drawClouds(in: &context, size: size, count: 13, opacity: 0.8, seed: 0xC3, darkness: 0.15)
                drawRain(in: &context, size: size, count: 85)
            case .thunderstorm:
                drawClouds(in: &context, size: size, count: 14, opacity: 0.85, seed: 0xC4, darkness: 0.3)
                drawRain(in: &context, size: size, count: 100)
                if flashes { drawLightning(in: &context, size: size) }
            case .snow:
                drawFootprints(in: &context, size: size)
                drawSnow(in: &context, size: size)
            case .windy:
                drawWind(in: &context, size: size)
            case .clearNight:
                drawStars(in: &context, size: size, count: 70)
            case .partlyCloudyNight:
                drawStars(in: &context, size: size, count: 40)
                drawClouds(in: &context, size: size, count: 7, opacity: 0.55, seed: 0xC5, darkness: 0.2)
            }
        }
    }

    private var sunCenter: (CGSize) -> CGPoint { { CGPoint(x: $0.width * 0.86, y: $0.height * 0.05) } }

    // MARK: Sun

    private func drawSunGlow(in context: inout GraphicsContext, size: CGSize, strength: Double, rays: Bool = true) {
        let center = sunCenter(size)
        let breathe = 0.85 + 0.15 * sin(time * 0.4)
        let radius = max(size.width, 320) * 0.75
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [Color(red: 1, green: 0.82, blue: 0.4).opacity((isDark ? 0.5 : 0.45) * strength * breathe), .clear]),
            center: center, startRadius: 0, endRadius: radius))
        guard rays else { return }
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
                Gradient(colors: [Color(red: 1, green: 0.9, blue: 0.6).opacity(0.16 * strength), .clear]),
                center: .zero, startRadius: 0, endRadius: radius))
        }
    }

    /// The sun itself, half off the top corner: a warm disc with a soft bloom.
    private func drawSunDisc(in context: inout GraphicsContext, size: CGSize, strength: Double) {
        let center = sunCenter(size)
        let radius = min(size.width, 400) * 0.16
        var bloom = context
        bloom.addFilter(.blur(radius: radius * 0.5))
        bloom.fill(Path(ellipseIn: CGRect(x: center.x - radius * 1.4, y: center.y - radius * 1.4, width: radius * 2.8, height: radius * 2.8)),
                   with: .color(Color(red: 1, green: 0.8, blue: 0.35).opacity(0.45 * strength)))
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.75).opacity(0.85 * strength),
                                                             Color(red: 1, green: 0.78, blue: 0.3).opacity(0.6 * strength)]),
                                           center: center, startRadius: 0, endRadius: radius))
    }

    /// Two slow clouds that pass back and forth over the sun, so it keeps peeking out.
    private func drawSunCoveringClouds(in context: inout GraphicsContext, size: CGSize) {
        let center = sunCenter(size)
        let width = min(size.width, 400) * 0.55
        for index in 0..<2 {
            let swing = sin(time * (0.05 + 0.02 * Double(index)) + Double(index) * 2.4)
            let point = CGPoint(x: center.x - width * 0.5 + swing * width * 0.6,
                                y: center.y + width * (0.02 + 0.12 * Double(index)))
            drawCloud(in: &context, at: point, width: width, opacity: 0.95, darkness: 0, shape: 900 + UInt64(index))
        }
    }

    // MARK: Clouds

    private func drawClouds(in context: inout GraphicsContext, size: CGSize, count: Int, opacity: Double,
                            seed: UInt64, darkness: Double = 0) {
        var random = SeededGenerator(seed: seed)
        for index in 0..<count {
            let width = Double.random(in: 0.35...0.75, using: &random) * size.width
            let speed = Double.random(in: 3...8, using: &random)
            let span = size.width + width * 2
            let x = (Double.random(in: 0...span, using: &random) + time * speed).truncatingRemainder(dividingBy: span) - width
            let y = Double.random(in: -0.05...0.95, using: &random) * size.height
            let bob = 4 * sin(time * 0.2 + y)
            drawCloud(in: &context, at: CGPoint(x: x, y: y + bob), width: width,
                      opacity: opacity * Double.random(in: 0.6...1, using: &random), darkness: darkness,
                      shape: seed &+ UInt64(index))
        }
    }

    /// A soft, irregular cumulus: a lumpy base, a random number of uneven billows piled highest
    /// off-center, and a ragged trailing wisp. `shape` seeds the outline, so each cloud keeps its own.
    private func drawCloud(in context: inout GraphicsContext, at origin: CGPoint, width: Double, opacity: Double,
                           darkness: Double, shape: UInt64) {
        var random = SeededGenerator(seed: shape &* 0x2545_F491_4F6C_DD1D &+ 1)
        var cloud = context
        cloud.addFilter(.blur(radius: width * 0.05))
        // On light backgrounds clouds are a soft blue-grey, so they stand out from the page.
        let lightTone = isDark ? 0.62 - darkness : 0.86 - darkness * 0.5
        let baseTone = isDark ? 0.42 - darkness : 0.7 - darkness * 0.5
        let alpha = opacity * (isDark ? 0.6 : 0.75)
        let light = Color(red: lightTone * 0.97, green: lightTone * 0.99, blue: min(lightTone * 1.05, 1)).opacity(alpha)
        let base = Color(red: baseTone * 0.96, green: baseTone * 0.98, blue: baseTone * 1.06).opacity(alpha)
        let height = width * Double.random(in: 0.22...0.34, using: &random)
        // Lumpy base: a few overlapping flat ellipses rather than one.
        for _ in 0..<Int.random(in: 3...5, using: &random) {
            let w = width * Double.random(in: 0.35...0.65, using: &random)
            let x = origin.x + Double.random(in: 0...(width - w), using: &random)
            let h = height * Double.random(in: 0.45...0.7, using: &random)
            cloud.fill(Path(ellipseIn: CGRect(x: x, y: origin.y + height * Double.random(in: 0.5...0.7, using: &random), width: w, height: h)),
                       with: .color(base))
        }
        // Billows: uneven sizes and spacing, tallest around a random peak.
        let peak = Double.random(in: 0.25...0.75, using: &random)
        let billows = Int.random(in: 4...8, using: &random)
        var along = Double.random(in: 0.02...0.12, using: &random)
        for _ in 0..<billows {
            guard along < 0.98 else { break }
            let lift = max(0, 1 - abs(along - peak) * Double.random(in: 1.4...2.4, using: &random))
            let diameter = height * (0.6 + 1.3 * lift) * Double.random(in: 0.75...1.25, using: &random)
            let x = origin.x + along * width - diameter / 2
            let y = origin.y + height * 0.8 - diameter * Double.random(in: 0.65...0.9, using: &random)
            cloud.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter * Double.random(in: 0.9...1.2, using: &random),
                                              height: diameter * Double.random(in: 0.75...0.95, using: &random))),
                       with: .color(light))
            along += Double.random(in: 0.1...0.24, using: &random)
        }
        // A trailing wisp on some clouds, stretched out on one side.
        if Bool.random(using: &random) {
            let side = Bool.random(using: &random)
            let w = width * Double.random(in: 0.3...0.5, using: &random)
            let x = side ? origin.x + width * 0.8 : origin.x - w * 0.6
            cloud.fill(Path(ellipseIn: CGRect(x: x, y: origin.y + height * 0.6, width: w, height: height * 0.25)),
                       with: .color(light.opacity(0.6)))
        }
    }

    // MARK: Rain and lightning

    private func drawRain(in context: inout GraphicsContext, size: CGSize, count: Int) {
        var random = SeededGenerator(seed: 0x7A1)
        let color = (isDark ? Color(red: 0.75, green: 0.85, blue: 1) : Color(red: 0.3, green: 0.45, blue: 0.68)).opacity(isDark ? 0.38 : 0.4)
        for _ in 0..<count {
            let x = Double.random(in: -20...size.width, using: &random)
            let speed = Double.random(in: 380...620, using: &random)
            let length = Double.random(in: 10...18, using: &random)
            let fall = size.height + length
            let y = (Double.random(in: 0...1, using: &random) * fall + time * speed).truncatingRemainder(dividingBy: fall) - length
            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y))
            streak.addLine(to: CGPoint(x: x + length * 0.15, y: y + length))
            context.stroke(streak, with: .color(color), lineWidth: 1.3)
        }
    }

    /// The sky lights up and a branching bolt forks down from the clouds.
    private func drawLightning(in context: inout GraphicsContext, size: CGSize) {
        let (flash, seed) = Lightning.flash(at: time)
        guard flash > 0 else { return }
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(red: 0.85, green: 0.9, blue: 1).opacity((isDark ? 0.28 : 0.35) * flash)))
        var random = SeededGenerator(seed: seed &+ 0xB017)
        var point = CGPoint(x: Double.random(in: 0.15...0.85, using: &random) * size.width, y: -4)
        let bottom = size.height * Double.random(in: 0.45...0.8, using: &random)
        var bolt = Path()
        var branches: [Path] = []
        bolt.move(to: point)
        while point.y < bottom {
            point = CGPoint(x: point.x + Double.random(in: -22...22, using: &random),
                            y: point.y + Double.random(in: 12...30, using: &random))
            bolt.addLine(to: point)
            if Double.random(in: 0...1, using: &random) < 0.22 {
                var branch = Path()
                var tip = point
                branch.move(to: tip)
                for _ in 0..<Int.random(in: 2...4, using: &random) {
                    tip = CGPoint(x: tip.x + Double.random(in: -26...26, using: &random), y: tip.y + Double.random(in: 10...22, using: &random))
                    branch.addLine(to: tip)
                }
                branches.append(branch)
            }
        }
        var glow = context
        glow.addFilter(.blur(radius: 5))
        let glowColor = Color(red: 0.75, green: 0.82, blue: 1).opacity(0.7 * flash)
        glow.stroke(bolt, with: .color(glowColor), lineWidth: 6)
        for branch in branches { glow.stroke(branch, with: .color(glowColor), lineWidth: 3) }
        let core = (isDark ? Color.white : Color(red: 0.95, green: 0.97, blue: 1)).opacity(0.95 * flash)
        context.stroke(bolt, with: .color(core), lineWidth: 1.8)
        for branch in branches { context.stroke(branch, with: .color(core.opacity(0.7 * flash)), lineWidth: 0.9) }
    }

    // MARK: Snow

    /// Flakes at three depths: far ones are soft dots, near ones six-armed crystals that turn slowly.
    /// Each drifts on its own mix of slow sways and breezes, so no two fall the same way.
    private func drawSnow(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededGenerator(seed: 0x5A0)
        let tint = isDark ? Color.white : Color(red: 0.55, green: 0.66, blue: 0.84)
        for index in 0..<110 {
            let depth = Double(index % 3) // 0 far, 1 middle, 2 near
            let baseX = Double.random(in: -0.1...1.1, using: &random) * size.width
            let speed = (10 + depth * 10) * Double.random(in: 0.8...1.3, using: &random)
            let fall = size.height + 20
            let y = (Double.random(in: 0...1, using: &random) * fall + time * speed).truncatingRemainder(dividingBy: fall) - 10
            let phase1 = Double.random(in: 0...(2 * .pi), using: &random)
            let phase2 = Double.random(in: 0...(2 * .pi), using: &random)
            let drift = Double.random(in: -6...10, using: &random) // a light breeze, mostly left to right
            let x = baseX
                + (14 + depth * 6) * sin(time * Double.random(in: 0.25...0.5, using: &random) + phase1)
                + 6 * sin(time * Double.random(in: 0.9...1.6, using: &random) + phase2)
                + drift * (y / max(size.height, 1)) * 4
            let radius = (1.2 + depth * 1.3) * Double.random(in: 0.8...1.25, using: &random)
            let opacity = (isDark ? 0.45 : 0.5) + depth * 0.15
            let spin = time * Double.random(in: -0.6...0.6, using: &random) + phase1
            if depth < 2 || radius < 3 {
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(tint.opacity(opacity)))
            } else {
                drawCrystal(in: &context, at: CGPoint(x: x, y: y), radius: radius * 1.3, rotation: spin, color: tint.opacity(opacity))
            }
        }
    }

    /// A six-armed snow crystal: each arm with a pair of short side branches.
    private func drawCrystal(in context: inout GraphicsContext, at center: CGPoint, radius: Double, rotation: Double, color: Color) {
        var crystal = Path()
        for arm in 0..<6 {
            let angle = rotation + Double(arm) * .pi / 3
            let tip = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            crystal.move(to: center)
            crystal.addLine(to: tip)
            for (fraction, length) in [(0.55, 0.35), (0.8, 0.22)] {
                let base = CGPoint(x: center.x + cos(angle) * radius * fraction, y: center.y + sin(angle) * radius * fraction)
                for side in [-1.0, 1.0] {
                    let branchAngle = angle + side * 0.75
                    crystal.move(to: base)
                    crystal.addLine(to: CGPoint(x: base.x + cos(branchAngle) * radius * length,
                                                y: base.y + sin(branchAngle) * radius * length))
                }
            }
        }
        context.stroke(crystal, with: .color(color), style: StrokeStyle(lineWidth: max(radius * 0.09, 0.5), lineCap: .round))
    }

    /// Someone walking across the snow: prints appear one by one along a wandering path, linger,
    /// and fade, then a new walk starts somewhere else.
    private func drawFootprints(in context: inout GraphicsContext, size: CGSize) {
        let walk = 16.0
        let cycle = Int(time / walk)
        let progress = time.truncatingRemainder(dividingBy: walk) / walk
        var random = SeededGenerator(seed: UInt64(truncatingIfNeeded: cycle) &* 0x9E37 &+ 7)
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
        let trailFade = progress > 0.8 ? 1 - (progress - 0.8) / 0.2 : 1
        let shade = (isDark ? Color(white: 0.75) : Color(red: 0.5, green: 0.58, blue: 0.74))
        for step in 0..<shown {
            let t = (Double(step) + 0.5) / Double(steps)
            let here = point(t)
            let ahead = point(min(t + 0.01, 1))
            let heading = atan2(ahead.y - here.y, ahead.x - here.x)
            let side: Double = step.isMultiple(of: 2) ? 1 : -1
            var footprint = context
            footprint.translateBy(x: here.x - sin(heading) * 5 * side, y: here.y + cos(heading) * 5 * side)
            footprint.rotate(by: .radians(heading + .pi / 2))
            let opacity = 0.42 * trailFade
            footprint.fill(Path(ellipseIn: CGRect(x: -3.5, y: -8, width: 7, height: 9)), with: .color(shade.opacity(opacity)))
            footprint.fill(Path(ellipseIn: CGRect(x: -2.8, y: 2, width: 5.6, height: 5.5)), with: .color(shade.opacity(opacity)))
        }
    }

    // MARK: Wind

    /// Wind shown only by what it carries: leaves blown across at uneven speeds, each fluttering,
    /// tumbling and drifting up or down on its own. Every 10 seconds a short gust (about 3 seconds)
    /// speeds them up, and the wind's direction shifts a little each time.
    private func drawWind(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededGenerator(seed: 0x1EAF)
        let colors = [Color(red: 0.55, green: 0.65, blue: 0.3), Color(red: 0.8, green: 0.55, blue: 0.25),
                      Color(red: 0.7, green: 0.4, blue: 0.25), Color(red: 0.6, green: 0.6, blue: 0.35),
                      Color(red: 0.85, green: 0.7, blue: 0.3)]
        let wind = Wind(time: time)
        // Leaves live in a field that's rotated to the wind's direction around the screen's center;
        // the field is the screen's diagonal, so it still covers the screen when tilted.
        let diagonal = hypot(size.width, size.height)
        var field = context
        field.translateBy(x: size.width / 2, y: size.height / 2)
        field.rotate(by: .radians(wind.angle))
        for _ in 0..<34 {
            let baseSpeed = Double.random(in: 35...90, using: &random)
            let span = diagonal + 80
            let start = Double.random(in: 0...span, using: &random)
            // Distance travelled so far: the leaf's own pace, with the gusts' extra push added in.
            let travelled = baseSpeed * (time + Wind.gustBoost * wind.gustDistance)
            let x = (start + travelled).truncatingRemainder(dividingBy: span) - span / 2
            // Drift across the wind: a few slow and quicker waves with random rates, so paths wander.
            var y = (Double.random(in: 0...1, using: &random) - 0.5) * diagonal
            for _ in 0..<3 {
                let amount = Double.random(in: 6...28, using: &random)
                let rate = Double.random(in: 0.15...1.4, using: &random)
                y += amount * sin(time * rate + Double.random(in: 0...(2 * .pi), using: &random))
            }
            let length = Double.random(in: 7...14, using: &random)
            let color = colors[Int.random(in: 0..<colors.count, using: &random)]
            let spinRate = Double.random(in: -2.2...2.2, using: &random)
            let flutterRate = Double.random(in: 0.8...2, using: &random)
            let phase = Double.random(in: 0...(2 * .pi), using: &random)
            var leaf = field
            leaf.translateBy(x: x, y: y)
            leaf.rotate(by: .radians(spinRate * (time + wind.gustDistance) + phase))
            // Tumbling: squash the leaf as it turns edge-on.
            leaf.scaleBy(x: 1, y: 0.25 + 0.75 * abs(sin(time * flutterRate + phase)))
            var shape = Path()
            shape.move(to: CGPoint(x: -length / 2, y: 0))
            shape.addQuadCurve(to: CGPoint(x: length / 2, y: 0), control: CGPoint(x: 0, y: -length * 0.45))
            shape.addQuadCurve(to: CGPoint(x: -length / 2, y: 0), control: CGPoint(x: 0, y: length * 0.45))
            leaf.fill(shape, with: .color(color.opacity(isDark ? 0.7 : 0.75)))
            // A faint midrib.
            var rib = Path()
            rib.move(to: CGPoint(x: -length / 2, y: 0))
            rib.addLine(to: CGPoint(x: length / 2, y: 0))
            leaf.stroke(rib, with: .color(.black.opacity(0.15)), lineWidth: 0.5)
        }
    }

    // MARK: Stars

    /// Stars that clearly brighten and dim at their own pace, the brightest with a little glint.
    private func drawStars(in context: inout GraphicsContext, size: CGSize, count: Int) {
        var random = SeededGenerator(seed: 0x57A)
        let color = isDark ? Color.white : Color(red: 0.35, green: 0.4, blue: 0.68)
        for _ in 0..<count {
            let x = Double.random(in: 0...1, using: &random) * size.width
            let y = Double.random(in: 0...1, using: &random) * size.height
            let radius = Double.random(in: 0.7...2, using: &random)
            let phase = Double.random(in: 0...(2 * .pi), using: &random)
            let rate = Double.random(in: 0.6...2.2, using: &random)
            let wave = 0.5 + 0.5 * sin(time * rate + phase)
            let twinkle = 0.15 + 0.85 * wave * wave
            let size = radius * (0.85 + 0.3 * twinkle)
            context.fill(Path(ellipseIn: CGRect(x: x - size, y: y - size, width: size * 2, height: size * 2)),
                         with: .color(color.opacity((isDark ? 0.95 : 0.8) * twinkle)))
            // A cross-shaped glint on the bigger stars at their brightest.
            if radius > 1.5, twinkle > 0.75 {
                let reach = size * 4 * (twinkle - 0.75) / 0.25
                var glint = Path()
                glint.move(to: CGPoint(x: x - reach, y: y)); glint.addLine(to: CGPoint(x: x + reach, y: y))
                glint.move(to: CGPoint(x: x, y: y - reach)); glint.addLine(to: CGPoint(x: x, y: y + reach))
                context.stroke(glint, with: .color(color.opacity((isDark ? 0.6 : 0.4) * twinkle)), lineWidth: 0.6)
            }
        }
    }
}

/// The wind for the leaves: one short gust in each 10-second slot, at a random moment, and a
/// direction that eases to a new slight tilt with each gust.
private struct Wind {
    static let slot = 10.0
    static let gustLength = 3.0
    /// How much faster than their own pace leaves move at the peak of a gust.
    static let gustBoost = 1.6

    /// 0…1 strength of the gust right now.
    let gust: Double
    /// The extra distance (in "seconds at full gust") all gusts so far have added, so speed changes
    /// never make leaves jump.
    let gustDistance: Double
    /// Radians from left-to-right; between about -0.35 and 0.35 (±20°).
    let angle: Double

    init(time: Double) {
        let index = Int((time / Self.slot).rounded(.down))
        func gustStart(_ slot: Int) -> Double {
            var random = SeededGenerator(seed: UInt64(bitPattern: Int64(slot)) &* 0xA24B &+ 3)
            return Double(slot) * Self.slot + Double.random(in: 0.5...(Self.slot - Self.gustLength - 0.5), using: &random)
        }
        func direction(_ slot: Int) -> Double {
            var random = SeededGenerator(seed: UInt64(bitPattern: Int64(slot)) &* 0x51F7 &+ 9)
            return Double.random(in: -0.35...0.35, using: &random)
        }
        let start = gustStart(index)
        let into = time - start
        // Each gust is a smooth sin² swell; one full gust adds gustLength / 2 of distance.
        if into <= 0 {
            gust = 0
            gustDistance = Double(index) * Self.gustLength / 2
        } else if into >= Self.gustLength {
            gust = 0
            gustDistance = Double(index + 1) * Self.gustLength / 2
        } else {
            let phase = into / Self.gustLength * .pi
            gust = sin(phase) * sin(phase)
            gustDistance = Double(index) * Self.gustLength / 2 + (into - sin(2 * phase) * Self.gustLength / (2 * .pi)) / 2
        }
        // The direction turns to this slot's tilt while the gust blows, and holds until the next one.
        let from = direction(index - 1), to = direction(index)
        let turn = min(max(into / Self.gustLength, 0), 1)
        angle = from + (to - from) * (0.5 - 0.5 * cos(turn * .pi))
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

extension Color {
    /// A color that differs between light and dark appearance.
    static func adaptive(light: Color, dark: Color) -> Color {
        #if os(iOS)
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #else
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light) })
        #endif
    }
}
