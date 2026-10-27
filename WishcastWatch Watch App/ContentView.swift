import SwiftUI

/// Today's best case and the week, for the place and wish chosen on the iPhone.
struct ContentView: View {
    let summary: WatchSummary?

    var body: some View {
        NavigationStack {
            if let summary {
                List {
                    if let today = summary.days.first {
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(summary.wishTitle, systemImage: summary.wishSymbol)
                                    .font(.caption)
                                    .foregroundStyle(wishTint(summary.wish))
                                HStack {
                                    Image(systemName: today.symbol)
                                        .symbolRenderingMode(.multicolor)
                                        .font(.title2)
                                    Text(verbatim: "\(today.high) / \(today.low)")
                                        .font(.title2.weight(.semibold))
                                        .monospacedDigit()
                                        .minimumScaleFactor(0.7)
                                }
                                Text(today.matchText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } footer: {
                            Text(summary.note)
                        }
                    }
                    Section {
                        ForEach(Array(summary.days.dropFirst().enumerated()), id: \.offset) { _, day in
                            HStack {
                                Text(day.weekday)
                                    .frame(minWidth: 36, alignment: .leading)
                                Image(systemName: day.symbol)
                                    .symbolRenderingMode(.multicolor)
                                Spacer()
                                Text(verbatim: "\(day.high) / \(day.low)")
                                    .monospacedDigit()
                            }
                            .font(.footnote)
                        }
                    }
                }
                .navigationTitle(summary.place)
            } else {
                ContentUnavailableView {
                    Label("Wishcast", systemImage: "mappin.and.ellipse")
                } description: {
                    Text("Open Wishcast on your iPhone and choose a place.")
                }
            }
        }
    }
}

#Preview {
    ContentView(summary: WatchSummary(
        place: "Denver", wishTitle: "Nice & Pleasant", wishSymbol: "leaf.fill", wish: "pleasant",
        note: "Best case for Nice & Pleasant. Not a prediction.", updated: .now,
        days: ["Today", "Wed", "Thu", "Fri", "Sat", "Sun", "Mon"].map {
            .init(weekday: $0, symbol: "sun.max.fill", high: "68°", low: "47°", matchText: "H: 2 of 220 · L: 1 of 220")
        }))
}
