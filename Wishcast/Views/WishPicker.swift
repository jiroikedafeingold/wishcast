import SwiftUI

/// Horizontally scrolling chips for choosing what kind of weather to hope for.
struct WishPicker: View {
    @Binding var selection: Wish
    /// Called when the chips start and stop scrolling.
    var onScrolling: (Bool) -> Void = { _ in }

    /// How many launches have shown the "there's more" nudge; it stops after a few.
    @AppStorage("wishPickerNudges") private var nudges = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// On the black light-mode page, chips sit on white so they don't vanish into the black.
    @Environment(\.lightCardsOnBlack) private var lightCardsOnBlack
    /// In light mode the page is colored (blue, blue-grey or dark grey), so chips sit on solid white.
    @Environment(\.colorScheme) private var colorScheme
    /// Once per launch.
    private static var nudgedThisLaunch = false

    var body: some View {
        ScrollViewReader { proxy in
            chips
                .task {
                    // Make sure the current wish is visible when the list first appears.
                    proxy.scrollTo(selection, anchor: .center)
                    await nudge(proxy)
                }
        }
    }

    /// On narrow screens only a couple of chips fit, so for the first few launches the row slides a
    /// couple of chips toward the hidden ones and back, to show it scrolls.
    private func nudge(_ proxy: ScrollViewProxy) async {
        guard !Self.nudgedThisLaunch, nudges < 5, !reduceMotion,
              let index = Wish.allCases.firstIndex(of: selection) else { return }
        Self.nudgedThisLaunch = true
        nudges += 1
        let all = Wish.allCases
        // Toward whichever end has more chips beyond the current one.
        let peek = all[index >= all.count / 2 ? max(index - 2, 0) : min(index + 2, all.count - 1)]
        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(peek, anchor: .center) }
        try? await Task.sleep(for: .seconds(0.9))
        withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(selection, anchor: .center) }
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Wish.allCases) { wish in
                    let isSelected = wish == selection
                    Button {
                        selection = wish
                    } label: {
                        // A tighter icon-to-text gap than Label's default.
                        HStack(spacing: 4) {
                            Image(systemName: wish.symbolName)
                            Text(wish.label)
                        }
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    // Full-strength text on the solid white chips in light mode, for contrast.
                    .tint(isSelected ? wish.tint : (colorScheme == .light ? .primary : .secondary))
                    .background(lightCardsOnBlack || colorScheme == .light ? Color.white : Color.clear, in: .capsule)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .id(wish)
                }
            }
        }
        .scrollIndicators(.hidden)
        .onScrollPhaseChange { _, phase in onScrolling(phase.isScrolling) }
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
}

#Preview {
    @Previewable @State var wish = Wish.snow
    WishPicker(selection: $wish)
}
