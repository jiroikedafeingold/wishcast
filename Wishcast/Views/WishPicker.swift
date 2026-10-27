import SwiftUI

/// Horizontally scrolling chips for choosing what kind of weather to hope for.
struct WishPicker: View {
    @Binding var selection: Wish

    var body: some View {
        ScrollViewReader { proxy in
            chips
                // Make sure the current wish is visible when the list first appears.
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
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
                            Text(wish.title)
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
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
}

#Preview {
    @Previewable @State var wish = Wish.snow
    WishPicker(selection: $wish)
}
