import SwiftUI

/// Horizontally scrolling chips for choosing what kind of weather to hope for.
struct WishPicker: View {
    @Binding var selection: Wish
    /// Called when the chips start and stop scrolling.
    var onScrolling: (Bool) -> Void = { _ in }

    /// How many launches have shown the "there's more" nudge; it stops after a few.
    @AppStorage("wishPickerNudges") private var nudges = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        Label {
                            Text(wish.label)
                        } icon: {
                            Image(systemName: wish.symbolName)
                        }
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(isSelected ? wish.tint : .secondary)
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
