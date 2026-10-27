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
    /// The hinge running side to side (the open Duo held upright), bent or flat. `lowerBound` is where
    /// the upper page ends.
    var uprightDivision: ClosedRange<CGFloat>?
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
            let book = any.first { $0.height > $0.width && $0.minX > 0 && $0.maxX < bounds.width }
            let upright = any.first { $0.width > $0.height && $0.minY > 0 && $0.maxY < bounds.height }
            return FoldState(tabletopBand: sideways.map { $0.minY...$0.maxY },
                             bookDivision: book.map { $0.minX...$0.maxX },
                             uprightDivision: upright.map { $0.minY...$0.maxY })
        }
    }
}
#endif
