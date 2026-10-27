import SwiftUI

struct SettingsView: View {
    @Binding var preferences: Preferences
    let wish: Wish
    let sourceCount: Int
    let placeName: String?
    @AppStorage("tabletopGrass") private var tabletopGrass = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TemperatureStepper(title: "Perfect High", celsius: $preferences.idealHigh, range: 0...45)
                    TemperatureStepper(title: "Perfect Evening", celsius: $preferences.idealEvening, range: -10...35)
                    TemperatureStepper(title: "Perfect Low", celsius: $preferences.idealLow, range: -20...30)
                } header: {
                    Text("Your Ideal Temperatures")
                } footer: {
                    Text("“Nice & Pleasant” picks the high, evening and low closest to these. “Cool Evenings” uses your evening and low.")
                }

                Section {
                    Button("Restore Defaults") { preferences = Preferences() }
                        .disabled(preferences == Preferences())
                }

                #if os(iOS)
                Section {
                    Toggle("Sunlit Grass on Tabletop", isOn: $tabletopGrass)
                } footer: {
                    Text("On iPhone Duo standing half-open on a table, show sunlit grass and today’s best case on the lower half.")
                }
                #endif

                Section {
                    NavigationLink("How Wishcast Works") {
                        HowItWorksView(wish: wish, preferences: preferences, sourceCount: sourceCount, placeName: placeName)
                    }
                    if let url = URL(string: "https://open-meteo.com/") {
                        Link("Weather data by Open-Meteo.com", destination: url)
                    }
                } footer: {
                    Text(wishcastTagline)
                        .italic()
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationSizing(.form)
    }
}

/// Steps a Celsius value by one degree in the user's preferred unit.
private struct TemperatureStepper: View {
    let title: LocalizedStringKey
    @Binding var celsius: Double
    let range: ClosedRange<Double>

    var body: some View {
        let displayRange = Metric.temperature.displayValue(range.lowerBound)...Metric.temperature.displayValue(range.upperBound)
        Stepper(
            value: Binding(
                get: { Metric.temperature.displayValue(celsius).rounded() },
                set: { celsius = Metric.celsius(fromDisplay: $0) }
            ),
            in: displayRange,
            step: 1
        ) {
            // Spell out the unit here (e.g. "75°F") since this is where people set it.
            LabeledContent(title, value: Measurement(value: celsius, unit: UnitTemperature.celsius)
                .formatted(.measurement(width: .abbreviated, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))))
        }
    }
}

#Preview {
    @Previewable @State var preferences = Preferences()
    SettingsView(preferences: $preferences, wish: .pleasant, sourceCount: 170, placeName: "Portland")
}
