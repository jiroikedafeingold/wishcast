import SwiftUI

/// Shown once on first launch: how to read Wishcast before it starts looking like a regular weather app.
struct WelcomeView: View {
    let onContinue: () -> Void
    let onLearnMore: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to Wishcast")
                        .font(.largeTitle.bold())
                    Text("“\(Text(wishcastTagline))”")
                        .font(.subheadline)
                        .fontDesign(.serif)
                        .italic()
                        .foregroundStyle(.secondary)
                }

                point("eye", title: "It looks like a weather app",
                      text: "Current conditions, a 7-day outlook, hourly forecasts and a widget, all laid out like any other weather app.")
                point("sparkles", title: "But it shows the best case",
                      text: "For each day, Wishcast looks at about 170 forecasts from global weather models and their ensemble runs. For every value (high, low, rain, clouds) it picks the one that best fits the weather you’re wishing for. The high can come from one forecast and the low from another.")
                point("exclamationmark.bubble", title: "So it isn’t a prediction",
                      text: "A sunny day in Wishcast means at least one forecast shows mostly clear skies, not that it will be sunny. Each day shows how many forecasts actually show its high and low. Check a regular forecast before making plans that depend on the weather.")
                point("checkmark.seal", title: "The rest is straight",
                      text: "“Right Now”, sunrise, sunset, UV and chance of precipitation come from one standard Open-Meteo forecast and aren’t mixed.")
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        // Pinned below the scrolling text so "Got It" is always visible and scrolling can't hit a button.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Got It")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("How Wishcast Works", action: onLearnMore)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .presentationSizing(.form)
    }

    private func point(_ symbol: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(minWidth: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView(onContinue: {}, onLearnMore: {})
}
