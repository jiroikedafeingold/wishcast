import SwiftUI

struct ContentView: View {
    @State private var viewModel = WishcastViewModel()
    @State private var selectedDate: Date?
    @State private var isPickingPlace = false
    @State private var isShowingSettings = false
    @State private var isShowingHelp = false
    @State private var isShowingWelcome = false
    @State private var isPickingDate = false
    #if DEBUG
    /// Set by the temporary background test button; nil follows the day's weather.
    @State private var testScenery: Scenery?
    #endif
    /// True while the wish chips are being scrolled, so that sideways drag doesn't change place.
    @State private var isScrollingWishes = false
    @AppStorage("tabletopGrass") private var tabletopGrass = true
    /// The animated weather hint behind the list and the day (Settings); not used on the Duo tabletop.
    @AppStorage("ambientBackground") private var ambientBackground = true
    #if os(iOS)
    @State private var fold = FoldState()
    #endif

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The system appearance (the columns may override it below).
    @Environment(\.colorScheme) private var systemColorScheme

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

    /// In light mode the page is black while cards stay light (not on the Duo tabletop's scenery).
    /// In light mode every page color is dark, so text on it gets light styling while cards stay
    /// light. Not on the Duo tabletop's scenery.
    private var isBlackPage: Bool {
        systemColorScheme == .light && !isOnScenery
    }

    private var sidebarColumn: some View {
        blackPage(sidebarContent)
    }

    /// Dark styling for the page (titles, headers, toolbar) with light cards, when the page is black.
    @ViewBuilder
    private func blackPage(_ content: some View) -> some View {
        if isBlackPage {
            content
                .environment(\.colorScheme, .dark)
                .environment(\.lightCardsOnBlack, true)
                #if os(iOS)
                // The navigation bar (e.g. a pushed day's title) takes its own appearance.
                .toolbarColorScheme(.dark, for: .navigationBar)
                #endif
        } else {
            content
        }
    }

    private var sidebarContent: some View {
        sidebar
            .navigationTitle(viewModel.place?.name ?? String(localized: "Sunnyside"))
            .toolbar {
                // The place name with its favorite star, shown once: as the large title, or (only on the
                // upright Duo, whose top page has no room for one) in the toolbar row, bigger than the
                // system's inline title so it still reads as the heading. Elsewhere the toolbar row stays
                // empty, even after the large title scrolls away.
                #if os(iOS)
                if isUprightPages {
                    ToolbarItem(placement: .title) {
                        placeTitle(font: .title.bold())
                    }
                } else {
                    ToolbarItem(placement: .largeTitle) {
                        placeTitle(font: .largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ToolbarItem(placement: .title) {
                        Color.clear.frame(width: 0, height: 0)
                    }
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
                #if DEBUG
                // Temporary: flip through the animated backgrounds (Debug builds only).
                if showsAmbient {
                    ToolbarItem {
                        Button {
                            let all = Scenery.allCases
                            let next = testScenery.flatMap { all.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
                            testScenery = next < all.count ? all[next] : nil
                        } label: {
                            Text(verbatim: testScenery?.debugName ?? "Auto")
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
                    Button("How Sunnyside Works", systemImage: "questionmark.circle") { isShowingHelp = true }
                }
            }
    }

    /// The page behind the list and the day: the animated weather, or the plain page color when
    /// that's off. The Duo tabletop draws its own scenery instead.
    @ViewBuilder
    private func pageBackground() -> some View {
        if showsAmbient {
            AmbientBackground(scenery: currentScenery, systemIsDark: systemColorScheme == .dark)
        } else if !isOnScenery {
            AmbientBackground.base.ignoresSafeArea()
        }
    }

    /// Rain, lightning, snow, footprints, leaves and faint clouds, crossing over the page's text and cards.
    @ViewBuilder
    private func pageOverlay() -> some View {
        if showsAmbient {
            AmbientOverlay(scenery: currentScenery)
        }
    }

    /// Whether the animated weather background is on (and this isn't the Duo tabletop, which has its own scenery).
    private var showsAmbient: Bool { ambientBackground && !isOnScenery }

    @ViewBuilder
    private var detailColumn: some View {
        if let day = viewModel.day(for: selectedDate) ?? (isBookLayout ? viewModel.days.first : nil) {
            blackPage(DayDetailView(day: day, wish: viewModel.wish, preferences: viewModel.preferences,
                                    timeZone: viewModel.timeZone, official: viewModel.conditions(for: day))
                .background { pageBackground() }
                .overlay { pageOverlay() })
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
                    .lightCard()
            }
            .buttonStyle(.plain)
            .listRowBackground(rowBackground(isSelected: selectedDate == day.date))
            .accessibilityAddTraits(selectedDate == day.date ? .isSelected : [])
        } else {
            NavigationLink(value: day.date) {
                // A selected sidebar row turns its text white for a solid highlight; on the white
                // card it would vanish, so keep it dark there.
                DayRow(day: day, timeZone: viewModel.timeZone)
                    .foregroundStyle(isBlackPage ? AnyShapeStyle(Color.black) : AnyShapeStyle(.primary))
            }
            .lightCard()
            .listRowBackground(rowBackground(isSelected: isBlackPage && selectedDate == day.date))
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
        if isBlackPage && !clear {
            return AnyView(ZStack {
                Color.white
                if isSelected { viewModel.wish.tint.opacity(0.18) }
            })
        }
        if isSelected { return AnyView(viewModel.wish.tint.opacity(0.18)) }
        return clear ? AnyView(Color.clear) : nil
    }

    /// The scene for the day on the upper page (today by default). After dark, today's clear and
    /// partly cloudy skies turn to night.
    private var currentScenery: Scenery {
        #if DEBUG
        if let testScenery { return testScenery }
        #endif
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
        // Only the wild-guess shot shows a picked date; don't carry it over from an earlier run.
        if shot != 4 { viewModel.clearPickedDay() }
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
                Text("Choose a place and Sunnyside will compare more than 200 forecasts from weather services around the world to find the best case for the weather you're hoping for.")
            } actions: {
                Button("Choose Location") { isPickingPlace = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List(selection: $selectedDate) {
                favoritesRow

                if !viewModel.alerts.isEmpty {
                    Section {
                        // Each row holds its own alert: indexing into the array crashed when a new
                        // place cleared it mid-update.
                        ForEach(Array(viewModel.alerts.enumerated()), id: \.offset) { _, alert in
                            WeatherAlertRow(alert: alert)
                                .lightCard()
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
                            .lightCard()
                            .listRowBackground(rowBackground())
                    } header: {
                        Text("Next Hour").sceneryLegible()
                    }
                }

                if let conditions = viewModel.conditions {
                    Section {
                        CurrentConditionsView(conditions: conditions)
                            .lightCard()
                            .listRowBackground(rowBackground())
                    } header: {
                        // On the Duo's upright top page, space goes to the list of days instead.
                        if !isUprightPages { Text("Right Now").sceneryLegible() }
                    }
                }

                Section {
                    WishPicker(selection: $viewModel.wish) { isScrollingWishes = $0 }
                        .lightCard()
                        .listRowInsets(EdgeInsets(top: isUprightPages ? 2 : 8, leading: 0, bottom: isUprightPages ? 2 : 8, trailing: 0))
                        .listRowBackground(rowBackground(clear: true))
                } header: {
                    if !isUprightPages { Text("I'm Wishing For").sceneryLegible() }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .lightCard()
                            .foregroundStyle(.secondary)
                            .listRowBackground(rowBackground())
                    }
                }

                if let pickedDay = viewModel.pickedDay {
                    Section {
                        dayRow(pickedDay)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Remove", systemImage: "xmark", role: .destructive) {
                                    if selectedDate == pickedDay.date { selectedDate = nil }
                                    viewModel.clearPickedDay()
                                }
                            }
                    } header: {
                        Text("Your Date").sceneryLegible()
                    } footer: {
                        Text("Swipe left to remove.").sceneryLegible()
                    }
                }

                if !viewModel.days.isEmpty {
                    Section {
                        ForEach(viewModel.days) { day in
                            dayRow(day)
                        }
                    } header: {
                        Text("7-Day Outlook").sceneryLegible()
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
            .scrollContentBackground(.hidden)
            .background { pageBackground() }
            .overlay { pageOverlay() }
            // Swipe sideways to move between favorites (not while scrolling the wish chips).
            .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { drag in
                let dx = drag.translation.width, dy = drag.translation.height
                guard !isScrollingWishes, !viewModel.favorites.isEmpty, abs(dx) > 80, abs(dx) > 2 * abs(dy) else { return }
                Task { await viewModel.showFavorite(step: dx < 0 ? 1 : -1) }
            })
        }
    }

    /// Moves between favorites: the previous and next favorite's names on either side of one dot per
    /// favorite (the current one wide), in a pill so it reads as a control. Tap a side or a dot, or
    /// swipe the list sideways. Only shown while on one of two or more favorites.
    @ViewBuilder
    private var favoritesRow: some View {
        let favorites = viewModel.favorites
        if viewModel.place != nil, let current = viewModel.favoriteIndex, favorites.count > 1 {
            let previous = favorites[(current - 1 + favorites.count) % favorites.count]
            let next = favorites[(current + 1) % favorites.count]
            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.showFavorite(step: -1) }
                } label: {
                    Label(previous.name, systemImage: "chevron.left")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 6) {
                    ForEach(favorites.indices, id: \.self) { index in
                        Button {
                            Task { await viewModel.showFavorite(at: index) }
                        } label: {
                            Capsule()
                                .fill(index == current ? AnyShapeStyle(viewModel.wish.tint) : AnyShapeStyle(.tertiary))
                                .frame(width: index == current ? 18 : 8, height: 8)
                                .padding(.vertical, 6)
                                .contentShape(.rect)
                        }
                    }
                }
                .fixedSize()
                Button {
                    Task { await viewModel.showFavorite(step: 1) }
                } label: {
                    HStack(spacing: 4) {
                        Text(next.name)
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .buttonStyle(.borderless)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: .capsule)
            .lightCard()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Favorite \(current + 1) of \(favorites.count)"))
            .accessibilityHint("Swipe up or down to change place.")
            .accessibilityAdjustableAction { direction in
                Task { await viewModel.showFavorite(step: direction == .increment ? 1 : -1) }
            }
            .animation(.snappy, value: current)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    /// The place name with a star beside it to add or remove it from favorites.
    private func placeTitle(font: Font) -> some View {
        HStack(spacing: 8) {
            Text(viewModel.place?.name ?? String(localized: "Sunnyside"))
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
