import SwiftUI

struct ContentView: View {
    @State private var viewModel = WishcastViewModel()
    @State private var selectedDate: Date?
    @State private var isPickingPlace = false
    @State private var isShowingSettings = false
    @State private var isShowingHelp = false
    @State private var isShowingWelcome = false
    @State private var isPickingDate = false
    @AppStorage("tabletopGrass") private var tabletopGrass = true
    #if os(iOS)
    @State private var fold = FoldState()
    #endif

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        #if os(iOS)
        // iPhone Duo: in the tabletop pose (half-open, lower half on the table) the app moves to the
        // upper half and the lower half optionally becomes a sunlit lawn with today's best case.
        Group {
            if let band = fold.tabletopBand, tabletopGrass {
                VStack(spacing: 0) {
                    splitView
                        .frame(height: band.lowerBound)
                    Color.clear
                        .frame(height: band.upperBound - band.lowerBound)
                    TabletopPanel(day: viewModel.days.first, wish: viewModel.wish, timeZone: viewModel.timeZone)
                }
                .ignoresSafeArea(edges: .vertical)
            } else {
                splitView
            }
        }
        .background(FoldReader(state: $fold).ignoresSafeArea())
        #else
        splitView
        #endif
    }

    private var splitView: some View {
        columns
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
            if !hasSeenWelcome && !isScreenshotRun { isShowingWelcome = true }
        }
        .task { await viewModel.refresh() }
        #if DEBUG
        .task { await stageScreenshot() }
        #endif
        .onChange(of: viewModel.days.map(\.date)) { _, dates in
            // With room for both columns, show today rather than an empty detail pane —
            // including after switching to a place whose days don't include the old selection.
            if horizontalSizeClass == .regular || isBookLayout, !dates.contains(where: { $0 == selectedDate }) {
                selectedDate = dates.first
            }
        }
    }

    @ViewBuilder
    private var columns: some View {
        #if os(iOS)
        if let division = fold.bookDivision {
            // iPhone Duo held open like a book: the list on the left page, the day on the right, and
            // nothing on the hinge. (The system split view slides the list over the day on this screen.)
            HStack(spacing: 0) {
                NavigationStack { sidebarColumn }
                    .frame(width: division.lowerBound)
                Color.clear
                    .frame(width: division.upperBound - division.lowerBound)
                NavigationStack { detailColumn }
            }
            .ignoresSafeArea(edges: .horizontal)
        } else {
            // Wide enough that each day's "H: … · L: …" count fits on one line.
            NavigationSplitView { sidebarColumn.navigationSplitViewColumnWidth(min: 320, ideal: 390, max: 480) } detail: { detailColumn }
        }
        #else
        NavigationSplitView { sidebarColumn.navigationSplitViewColumnWidth(min: 320, ideal: 390, max: 480) } detail: { detailColumn }
        #endif
    }

    private var sidebarColumn: some View {
        sidebar
            .navigationTitle(viewModel.place?.name ?? String(localized: "Wishcast"))
            .toolbar {
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
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let day = viewModel.day(for: selectedDate) {
            DayDetailView(day: day, wish: viewModel.wish, preferences: viewModel.preferences,
                          timeZone: viewModel.timeZone, official: viewModel.conditions(for: day))
        } else {
            ContentUnavailableView("Pick a Day", systemImage: "calendar",
                                   description: Text("See how each value for that day was picked, and how many forecasts show it."))
        }
    }

    /// A day row: a navigation link in the split view, or a selecting button on the hinge's book layout.
    @ViewBuilder
    private func dayRow(_ day: WishcastDay) -> some View {
        if isBookLayout {
            Button {
                selectedDate = day.date
            } label: {
                DayRow(day: day, timeZone: viewModel.timeZone)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .listRowBackground(selectedDate == day.date ? viewModel.wish.tint.opacity(0.18) : nil)
            .accessibilityAddTraits(selectedDate == day.date ? .isSelected : [])
        } else {
            NavigationLink(value: day.date) {
                DayRow(day: day, timeZone: viewModel.timeZone)
            }
        }
    }

    private var isScreenshotRun: Bool {
        #if DEBUG
        ScreenshotMode.shot != nil
        #else
        false
        #endif
    }

    #if DEBUG
    /// Opens the screen for an App Store screenshot (see ScreenshotMode).
    private func stageScreenshot() async {
        guard let shot = ScreenshotMode.shot else { return }
        isShowingWelcome = false
        viewModel.wish = shot == 3 ? .snow : .pleasant
        await viewModel.select(ScreenshotMode.place)
        switch shot {
        case 2:
            selectedDate = viewModel.days.dropFirst(2).first?.date
        case 4:
            await viewModel.loadLongRange()
            if let date = Calendar.current.date(byAdding: .day, value: 58, to: .now) {
                selectedDate = viewModel.pick(date)
            }
        case 5:
            isShowingHelp = true
        default:
            break
        }
    }
    #endif

    private var isBookLayout: Bool {
        #if os(iOS)
        fold.bookDivision != nil
        #else
        false
        #endif
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
                        dayRow(pickedDay)
                    }
                }

                if !viewModel.days.isEmpty {
                    Section {
                        ForEach(viewModel.days) { day in
                            dayRow(day)
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

/// The lower half of a half-open iPhone Duo on a table: sunlit grass with today's best case on glass.
private struct TabletopPanel: View {
    let day: WishcastDay?
    let wish: Wish
    let timeZone: TimeZone

    var body: some View {
        SunlitGrass()
            .overlay {
                if let day {
                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            WeatherSymbol(name: day.symbolName)
                                .font(.largeTitle)
                            Text("\(Metric.temperature.format(day.high.value)) / \(Metric.temperature.format(day.low.value))")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .monospacedDigit()
                        }
                        Text(day.weekday(in: timeZone))
                            .font(.headline)
                        Text("\(Text(ForecastRange(date: day.date, timeZone: timeZone).title)) for \(Text(wish.title))")
                            .font(.subheadline)
                        Text("This is a wish, not a prediction.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .accessibilityElement(children: .combine)
                }
            }
    }
}
