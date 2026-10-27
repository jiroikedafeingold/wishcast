import SwiftUI

#if os(iOS)
import UIKit

/// Where iPhone Duo's hinge crosses the window, read from the system (iOS 27.1 reports it as a
/// reserved region of kind `.division`). Every other device reports nothing.
struct FoldState: Equatable {
    /// The hinge running side to side, only while the phone is actually bent: the tabletop pose,
    /// lower half flat on the table. `lowerBound` is where the upper page ends, `upperBound` where the
    /// lower page starts.
    var tabletopBand: ClosedRange<CGFloat>?
    /// The hinge running top to bottom (the open Duo held like a book), bent or flat. `lowerBound` is
    /// where the leading page ends.
    var bookDivision: ClosedRange<CGFloat>?
}

/// Reports the window's fold state. Attach as a background that ignores the safe area, so its
/// coordinates are the window's.
struct FoldReader: UIViewRepresentable {
    @Binding var state: FoldState

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onChange = { state = $0 }
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onChange = { state = $0 }
    }

    final class ProbeView: UIView {
        var onChange: ((FoldState) -> Void)?
        private var reported: FoldState?

        // Bounds change on every fold, unfold and rotation, each of which lays the view out again.
        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        private func report() {
            let current = measure()
            guard current != reported else { return }
            reported = current
            // Not inside SwiftUI's update pass: publish on the next turn of the main actor.
            let onChange = onChange
            Task { @MainActor in onChange?(current) }
        }

        private func measure() -> FoldState {
            guard window != nil else { return FoldState() }
            guard #available(iOS 27.1, *) else { return FoldState() }
            // Active divisions only exist while the phone is bent; inactive ones also while it's flat.
            let bent = reservedRegions(kind: .division, options: []).map(\.frame)
            let any = reservedRegions(kind: .division, options: .includeInactive).map(\.frame)
            let sideways = bent.first { $0.width > $0.height && $0.minY > 0 && $0.maxY < bounds.height }
            let upright = any.first { $0.height > $0.width && $0.minX > 0 && $0.maxX < bounds.width }
            return FoldState(tabletopBand: sideways.map { $0.minY...$0.maxY },
                             bookDivision: upright.map { $0.minX...$0.maxX })
        }
    }
}
#endif

/// Grass seen from above with sunlight dappling through leaves overhead, drawn in code. The lawn is
/// drawn twice, in shade and in sun, and soft drifting patches reveal the sunlit one — the way light
/// through a canopy lights up the grass under it. Only the patches move, and not with Reduce Motion.
struct SunlitGrass: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GrassBlades(sunlit: false)
            GrassBlades(sunlit: true)
                .mask {
                    if reduceMotion {
                        DappleMask(time: 0)
                    } else {
                        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                            DappleMask(time: timeline.date.timeIntervalSinceReferenceDate)
                        }
                    }
                }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

/// A tiny deterministic random generator, so the lawn looks the same on every redraw.
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

private struct GrassBlades: View {
    /// The same blades either way (same seed); sunlit ones are brighter and warmer.
    var sunlit: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let ground = sunlit
                ? [Color(red: 0.42, green: 0.62, blue: 0.18), Color(red: 0.25, green: 0.45, blue: 0.10)]
                : [Color(red: 0.10, green: 0.25, blue: 0.08), Color(red: 0.05, green: 0.16, blue: 0.05)]
            context.fill(Path(rect), with: .linearGradient(Gradient(colors: ground),
                                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

            var random = SeededRandom(state: 0x5EED)
            // Back to front, so nearer (lower, longer, brighter) blades overlap farther ones.
            let count = Int(size.width * size.height / 38)
            for index in 0..<count {
                let depth = Double(index) / Double(count)
                let x = Double.random(in: -10...(size.width + 10), using: &random)
                let base = size.height * (0.05 + 0.98 * depth) + Double.random(in: -12...12, using: &random)
                let length = (10 + 26 * depth) * Double.random(in: 0.7...1.3, using: &random)
                let lean = Double.random(in: -0.45...0.45, using: &random) * length
                var blade = Path()
                blade.move(to: CGPoint(x: x - 1.6, y: base))
                blade.addQuadCurve(to: CGPoint(x: x + lean, y: base - length),
                                   control: CGPoint(x: x + lean * 0.2, y: base - length * 0.6))
                blade.addQuadCurve(to: CGPoint(x: x + 1.6, y: base),
                                   control: CGPoint(x: x + lean * 0.3, y: base - length * 0.5))
                blade.closeSubpath()
                let hue = Double.random(in: 0.25...0.32, using: &random)
                let shade = (0.30 + 0.30 * depth) * Double.random(in: 0.8...1.15, using: &random)
                let color = sunlit
                    ? Color(hue: hue - 0.04, saturation: 0.62, brightness: min(shade * 1.75, 0.98))
                    : Color(hue: hue, saturation: 0.75, brightness: shade * 0.8)
                context.fill(blade, with: .color(color))
            }
        }
    }
}

/// Where sunlight gets through the canopy: soft, irregular patches (each a small cluster of blobs)
/// that sway and brighten as the leaves above move.
private struct DappleMask: View {
    var time: Double

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
                let flicker = 0.75 + 0.25 * sin(time * speed * 2.1 + phase)
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

#Preview("Sunlit grass") {
    SunlitGrass()
        .frame(height: 400)
}
