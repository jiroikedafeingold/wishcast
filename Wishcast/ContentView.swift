import SwiftUI

struct ContentView: View {
    @State private var viewModel = WishcastViewModel()
    @State private var selectedDate: Date?
    @State private var isPickingPlace = false
    @State private var isShowingSettings = false
    @State private var isShowingHelp = false
    @State private var isShowingWelcome = false
    @State private var isPickingDate = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle(viewModel.place?.name ?? String(localized: "Wishcast"))                .toolbar {
                    ToolbarItem {
                        Button("Locations", systemImage: "mappin.and.ellipse") { isPickingPlace = true }
                    }
                    ToolbarItem {
                        Button("Settings", systemImage: "slider.horizontal.3") { isShowingSettings = true }
                    }
                    ToolbarItem {
                        Button("How Wishcast Works", systemImage: "questionmark.circle") { isShowingHelp = true }
                    }
                }
        } detail: {
            if let day = viewModel.day(for: selectedDate) {
                DayDetailView(day: day, wish: viewModel.wish, preferences: viewModel.preferences,
                              timeZone: viewModel.timeZone, official: viewModel.conditions(for: day))
            } else {
                ContentUnavailableView("Pick a Day", systemImage: "calendar",
                                       description: Text("See how each value for that day was picked, and how many forecasts show it."))
            }
        }
        .tint(viewModel.wish.tint)
        .sheet(isPresented: $isPickingPlace) {
            PlaceSearchView(
                savedPlaces: viewModel.savedPlaces,
                onSelect: { place in Task { await viewModel.select(place) } },
                onUseCurrentLocation: { Task { await viewModel.useCurrentLocation() } },
                onDelete: viewModel.removePlaces(at:)
            )
            .tint(viewModel.wish.tint)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(preferences: $viewModel.preferences, wish: viewModel.wish,
                         sourceCount: viewModel.sourceCount, placeName: viewModel.place?.name)
                .tint(viewModel.wish.tint)
        }
        .sheet(isPresented: $isShowingHelp) {
            NavigationStack {
                HowItWorksView(wish: viewModel.wish, preferences: viewModel.preferences,
                               sourceCount: viewModel.sourceCount, placeName: viewModel.place?.name)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingHelp = false }
                        }
                    }
            }
            .presentationSizing(.form)
            .tint(viewModel.wish.tint)
        }
        .sheet(isPresented: $isPickingDate) {
            DatePickerSheet(lastDate: viewModel.lastPickableDate, isLoading: viewModel.isLoadingLongRange) { date in
                selectedDate = viewModel.pick(date)
            }
            .task { await viewModel.loadLongRange() }
            .tint(viewModel.wish.tint)
        }
        .sheet(isPresented: $isShowingWelcome, onDismiss: { hasSeenWelcome = true }) {
            WelcomeView {
                isShowingWelcome = false
            } onLearnMore: {
                isShowingWelcome = false
                isShowingHelp = true
            }
            .tint(viewModel.wish.tint)
        }
        .onAppear {
            // Explain how to read Wishcast once, on first launch; it's always available from the ? button.
            if !hasSeenWelcome { isShowingWelcome = true }
        }
        .task { await viewModel.refresh() }
        .onChange(of: viewModel.days.map(\.date)) { _, dates in
            // With room for both columns, show today rather than an empty detail pane —
            // including after switching to a place whose days don't include the old selection.
            if horizontalSizeClass == .regular, !dates.contains(where: { $0 == selectedDate }) {
                selectedDate = dates.first
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if viewModel.place == nil {
            ContentUnavailableView {
                Label("Where To?", systemImage: "mappin.and.ellipse")
            } description: {
                Text("Choose a place and Wishcast will compare forecasts from \(OpenMeteoClient.modelNames.count) weather models and every member of \(OpenMeteoClient.ensembleNames.count) ensembles to find the best case for the weather you're hoping for.")
            } actions: {
                Button("Choose Location") { isPickingPlace = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List(selection: $selectedDate) {
                // The tag line sits right under the location title, styled as a motto. It's a list row
                // rather than a navigation subtitle, which drops italics and truncates when collapsed.
                Text("“\(Text(wishcastTagline))”")
                    .font(.subheadline)
                    .fontDesign(.serif)
                    .italic()
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    // A little leading room so the italic slant isn't clipped at the row edge.
                    .listRowInsets(EdgeInsets(top: 0, leading: 3, bottom: 0, trailing: 0))

                if let conditions = viewModel.conditions {
                    Section("Right Now") {
                        CurrentConditionsView(conditions: conditions)
                    }
                }

                Section {
                    WishPicker(selection: $viewModel.wish)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("I'm Wishing For")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }

                if let pickedDay = viewModel.pickedDay {
                    Section("Your Date") {
                        NavigationLink(value: pickedDay.date) {
                            DayRow(day: pickedDay, timeZone: viewModel.timeZone)
                        }
                    }
                }

                if !viewModel.days.isEmpty {
                    Section {
                        ForEach(viewModel.days) { day in
                            NavigationLink(value: day.date) {
                                DayRow(day: day, timeZone: viewModel.timeZone)
                            }
                        }
                        Button("Pick a Future Date…", systemImage: "calendar") { isPickingDate = true }
                    } header: {
                        Text("7-Day Wishcast")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This is a wish, not a prediction.")
                            // Open-Meteo's CC BY 4.0 licence requires this link wherever its data is shown.
                            if let url = URL(string: "https://open-meteo.com/") {
                                Link("Weather data by Open-Meteo.com", destination: url)
                            }
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.days.isEmpty {
                    ProgressView("Gathering forecasts…")
                }
            }
            .refreshable { await viewModel.refresh() }
        }
    }
}

#Preview {
    ContentView()
}
