import SwiftUI

/// Lets people pick any future date that has forecast data.
struct DatePickerSheet: View {
    /// The last day with forecast data, or nil while long-range forecasts are loading.
    let lastDate: Date?
    let isLoading: Bool
    /// The long-range forecast failed to download, so `lastDate` is only a couple of weeks out.
    var isLongRangeMissing = false
    let onPick: (Date) -> Void

    @State private var date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let lastDate {
                        DatePicker("Date", selection: $date, in: Date.now...lastDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    } else if isLoading {
                        ProgressView("Downloading long-range forecasts…")
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Long-range forecasts aren’t available right now.")
                    }
                } footer: {
                    if let lastDate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Forecasts reach \(lastDate.formatted(date: .long, time: .omitted)). The first 7 days are a best case, days 8–14 a long shot, and anything later a wild guess.")
                            Text("The free weather services Sunnyside uses limit how much each device can download a day, so long-range forecasts are downloaded once a day for each place and saved.")
                            if isLongRangeMissing {
                                Label("The long-range forecast, which reaches about six months out, couldn’t be downloaded right now, possibly because today’s download limit was reached, so later dates aren’t available. Try again tomorrow.",
                                      systemImage: "exclamationmark.triangle")
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Pick a Date")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Show") {
                        onPick(date)
                        dismiss()
                    }
                    .disabled(lastDate == nil)
                }
            }
            .onChange(of: lastDate) { _, lastDate in
                // Keep the default inside the available range.
                if let lastDate, date > lastDate { date = lastDate }
            }
        }
        .presentationSizing(.form)
    }
}

#Preview {
    DatePickerSheet(lastDate: Calendar.current.date(byAdding: .month, value: 6, to: .now), isLoading: false) { _ in }
}
