import SwiftUI

struct ContentView: View {
    @State private var viewModel = WishcastViewModel()
    @State private var selectedDate: Date?
    @State private var isPickingPlace = false
    @State private var isShowingSettings = false
    @State private var isShowingHelp = false
    @State private var isShowingWelcome = false
    @State private var isPickingDate = false
    /// True while the wish chips are being scrolled, so that sideways drag doesn't change place.
    @State private var isScrollingWishes = false
    @AppStorage("tabletopGrass") private var tabletopGrass = true
    #if os(iOS)
    @State private var fold = FoldState()
    #endif

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        #if os(iOS)
        splitView
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
                favorites: viewModel.favorites,
                otherPlaces: viewModel.otherSavedPlaces,
                onSelect: { place in Task { await viewModel.select(place) } },
                onUseCurrentLocation: { Task { await viewModel.useCurrentLocation() } },
                onToggleFavorite: viewModel.toggleFavorite,
                onMoveFavorites: viewModel.moveFavorites,
                onDelete: viewModel.removePlaces
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
            DatePickerSheet(lastDate: viewModel.lastPickableDate, isLoading: viewModel.isLoadingLongRange,
                            isLongRangeMissing: viewModel.isLongRangeMissing) { date in
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
        if let band = fold.tabletopBand, tabletopGrass {
            // iPhone Duo half-open on a table: the day stands up against the sky, and the list lies
            // flat on the table over the ground, both drawn to match the day's weather.
            let scenery = currentScenery
            VStack(spacing: 0) {
                NavigationStack {
                    detailColumn
                        .containerBackground(for: .navigation) { SkyScenery(scenery: scenery) }
                }
                .environment(\.colorScheme, scenery.skyColorScheme)
                .frame(height: band.lowerBound)
                HingeHorizon(scenery: scenery)
                    .frame(height: band.upperBound - band.lowerBound)
                NavigationStack {
                    sidebarColumn
                        .scrollContentBackground(.hidden)
                        .containerBackground(for: .navigation) { GroundScenery(scenery: scenery) }
                }
                .environment(\.colorScheme, scenery.groundColorScheme)
            }
            .environment(\.onScenery, true)
            .environment(\.showsScrollHints, true)
            .ignoresSafeArea(edges: .vertical)
        } else if let division = fold.bookDivision {
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
        } else if let division = fold.uprightDivision {
            // iPhone Duo open and held upright: the list of days on the top page, the full day below,
            // and the title strip across the hinge. The lower page uses a compact title so the day
            // starts near the top of its page.
            VStack(spacing: 0) {
                // The place name moves into the toolbar row and sections sit closer together, so more
                // of the list of days fits on the upper page.
                NavigationStack {
                    sidebarColumn
                        .toolbarTitleDisplayMode(.inline)
                        .listSectionSpacing(.compact)
                }
                .frame(height: division.lowerBound - Self.hingeBarOverlap)
                // The title strip reaches a little onto each page, so it's more than a sliver.
                HingeHorizon(scenery: currentScenery, blendsIn: true)
                    .frame(height: division.upperBound - division.lowerBound + 2 * Self.hingeBarOverlap)
                NavigationStack {
                    detailColumn
                        .toolbarTitleDisplayMode(.inline)
                }
            }
            .environment(\.showsScrollHints, true)
            .ignoresSafeArea(edges: .vertical)
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
                // The place name with its favorite star, large or (upright Duo) inline. The inline one is
                // bigger than the system's, so the place still reads as the heading.
                #if os(iOS)
                ToolbarItem(placement: .largeTitle) {
                    placeTitle(font: .largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ToolbarItem(placement: .title) {
                    placeTitle(font: .title.bold())
                }
                #else
                ToolbarItem {
                    if let place = viewModel.place {
                        let isFavorite = viewModel.isFavorite(place)
                        Button(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                               systemImage: isFavorite ? "star.fill" : "star") {
                            viewModel.toggleFavorite(place)
                        }
                    }
                }
                #endif
                ToolbarItem {
                    Button("Pick a Future Date…", systemImage: "calendar") { isPickingDate = true }
                        .disabled(viewModel.days.isEmpty)
                }
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
        if let day = viewModel.day(for: selectedDate) ?? (isBookLayout ? viewModel.days.first : nil) {
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
            .listRowBackground(rowBackground(isSelected: selectedDate == day.date))
            .accessibilityAddTraits(selectedDate == day.date ? .isSelected : [])
        } else {
            NavigationLink(value: day.date) {
                DayRow(day: day, timeZone: viewModel.timeZone)
            }
        }
    }

    /// How far the upright hinge strip extends onto each page.
    private static let hingeBarOverlap: CGFloat = 14

    #if os(iOS)
    /// iPhone Duo open and upright (not on a table): list on the top page, day on the bottom.
    private var isUprightPages: Bool { fold.uprightDivision != nil && !isOnScenery }
    #else
    private var isUprightPages: Bool { false }
    #endif

    #if os(iOS)
    /// Whether the tabletop scenery is showing behind the list and the day.
    private var isOnScenery: Bool { fold.tabletopBand != nil && tabletopGrass }
    #else
    private var isOnScenery: Bool { false }
    #endif

    /// A list row's background: frosted over tabletop scenery so rows stay readable, tinted when selected.
    /// `nil` keeps the system's (or, with `clear`, no) background elsewhere.
    private func rowBackground(isSelected: Bool = false, clear: Bool = false) -> AnyView? {
        if isOnScenery {
            return AnyView(ZStack {
                Rectangle().fill(.regularMaterial)
                if isSelected { viewModel.wish.tint.opacity(0.25) }
            })
        }
        if isSelected { return AnyView(viewModel.wish.tint.opacity(0.18)) }
        return clear ? AnyView(Color.clear) : nil
    }

    /// The scene for the day on the upper page (today by default). After dark, today's clear and
    /// partly cloudy skies turn to night.
    private var currentScenery: Scenery {
        guard let day = viewModel.day(for: selectedDate) ?? viewModel.days.first else { return .sunny }
        return Scenery(symbolName: day.symbolName, isNight: viewModel.isNightNow(on: day))
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

    /// Whether the list and the day are both on screen around a hinge (book or upright), so rows
    /// select a day rather than navigate to it.
    private var isBookLayout: Bool {
        #if os(iOS)
        fold.bookDivision != nil || fold.uprightDivision != nil
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
                Text("Choose a place and Wishcast will compare more than 200 forecasts from weather services around the world to find the best case for the weather you're hoping for.")
            } actions: {
                Button("Choose Location") { isPickingPlace = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List(selection: $selectedDate) {
                favoritesRow

                if !viewModel.alerts.isEmpty {
                    Section {
                        ForEach(viewModel.alerts.indices, id: \.self) { index in
                            WeatherAlertRow(alert: viewModel.alerts[index])
                                .listRowBackground(rowBackground())
                        }
                    } header: {
                        Text("Official Alerts").sceneryLegible()
                    } footer: {
                        Text("From national weather services via Apple Weather. Shown as issued, never part of the wish.")
                            .sceneryLegible()
                    }
                }

                if viewModel.precipitationExpectedSoon, let nextHour = viewModel.nextHour {
                    Section {
                        NextHourView(forecast: nextHour)
                            .listRowBackground(rowBackground())
                    } header: {
                        Text("Next Hour").sceneryLegible()
                    } footer: {
                        Text("One forecast from Apple Weather, not mixed and not a best case.")
                            .sceneryLegible()
                    }
                }

                if let conditions = viewModel.conditions {
                    Section {
                        CurrentConditionsView(conditions: conditions)
                            .listRowBackground(rowBackground())
                    } header: {
                        // On the Duo's upright top page, space goes to the list of days instead.
                        if !isUprightPages { Text("Right Now").sceneryLegible() }
                    }
                }

                Section {
                    WishPicker(selection: $viewModel.wish) { isScrollingWishes = $0 }
                        .listRowInsets(EdgeInsets(top: isUprightPages ? 2 : 8, leading: 0, bottom: isUprightPages ? 2 : 8, trailing: 0))
                        .listRowBackground(rowBackground(clear: true))
                } header: {
                    if !isUprightPages { Text("I'm Wishing For").sceneryLegible() }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .listRowBackground(rowBackground())
                    }
                }

                if let pickedDay = viewModel.pickedDay {
                    Section {
                        dayRow(pickedDay)
                    } header: {
                        Text("Your Date").sceneryLegible()
                    }
                }

                if !viewModel.days.isEmpty {
                    Section {
                        ForEach(viewModel.days) { day in
                            dayRow(day)
                        }
                    } header: {
                        Text("7-Day Wishcast").sceneryLegible()
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This is a wish, not a prediction.")
                            // Open-Meteo's CC BY 4.0 licence requires this link wherever its data is shown.
                            if let url = URL(string: "https://open-meteo.com/") {
                                Link("Weather data by Open-Meteo.com", destination: url)
                            }
                            // MET Norway's licence (CC BY 4.0) and Apple's WeatherKit terms ask for the same.
                            if viewModel.otherProviders.contains(OpenMeteoClient.metNorwayName),
                               let url = URL(string: "https://www.met.no/en") {
                                Link("Data from MET Norway", destination: url)
                            }
                            if viewModel.otherProviders.contains(OpenMeteoClient.appleWeatherName),
                               let attribution = viewModel.appleWeatherAttribution {
                                AppleWeatherAttribution(attribution: attribution)
                            }
                        }
                        .sceneryLegible()
                    }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.days.isEmpty {
                    ProgressView("Gathering forecasts…")
                }
            }
            .refreshable { await viewModel.refresh() }
            .sceneryScrollHints()
            // Swipe sideways to move between favorites (not while scrolling the wish chips).
            .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { drag in
                let dx = drag.translation.width, dy = drag.translation.height
                guard !isScrollingWishes, !viewModel.favorites.isEmpty, abs(dx) > 80, abs(dx) > 2 * abs(dy) else { return }
                Task { await viewModel.showFavorite(step: dx < 0 ? 1 : -1) }
            })
        }
    }

    /// One dot per favorite, the current one filled; tap a dot to jump to that place. Only shown when
    /// there's somewhere to swipe to.
    @ViewBuilder
    private var favoritesRow: some View {
        let favorites = viewModel.favorites
        let current = viewModel.favoriteIndex
        if viewModel.place != nil, favorites.count > 1 || (favorites.count == 1 && current == nil) {
            HStack(spacing: 8) {
                ForEach(favorites.indices, id: \.self) { index in
                    Button {
                        Task { await viewModel.showFavorite(at: index) }
                    } label: {
                        Circle()
                            .fill(index == current ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                            .frame(width: 8, height: 8)
                            .padding(4)
                            .contentShape(.rect)
                    }
                }
            }
            .buttonStyle(.borderless)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(current.map { String(localized: "Favorite \($0 + 1) of \(favorites.count)") }
                                ?? String(localized: "\(favorites.count) favorites"))
            .accessibilityHint("Swipe up or down to change place.")
            .accessibilityAdjustableAction { direction in
                Task { await viewModel.showFavorite(step: direction == .increment ? 1 : -1) }
            }
            .sceneryLegible()
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }

    /// The place name with a star beside it to add or remove it from favorites.
    private func placeTitle(font: Font) -> some View {
        HStack(spacing: 8) {
            Text(viewModel.place?.name ?? String(localized: "Wishcast"))
                .font(font)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let place = viewModel.place {
                let isFavorite = viewModel.isFavorite(place)
                Button(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                       systemImage: isFavorite ? "star.fill" : "star") {
                    viewModel.toggleFavorite(place)
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(isFavorite ? .yellow : .secondary)
                .buttonStyle(.borderless)
            }
        }
    }
}

#Preview {
    ContentView()
}
