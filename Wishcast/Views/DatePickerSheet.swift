import SwiftUI

/// Lets people pick any future date that has forecast data.
struct DatePickerSheet: View {
    /// The last day with forecast data, or nil while long-range forecasts are loading.
    let lastDate: Date?
    let isLoading: Bool
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
                        Text("Forecasts reach \(lastDate.formatted(date: .long, time: .omitted)). The first 7 days are a best case, days 8–14 a long shot, and anything later a wild guess.")
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
