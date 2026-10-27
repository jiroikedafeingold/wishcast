import Foundation
import CoreLocation
import Observation
import WeatherKit
import WidgetKit

@Observable
final class WishcastViewModel {
    var wish: Wish {
        didSet {
            SharedSettings.wish = wish
            settingsChanged()
        }
    }
    var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            SharedSettings.preferences = preferences
            settingsChanged()
        }
    }
    private(set) var place: Place?
    private(set) var savedPlaces: [Place]
    /// Starred places, in the user's order; swiping on the main screen moves between them.
    private(set) var favorites: [Place]
    private(set) var days: [WishcastDay] = []
    private(set) var conditions: Conditions?
    private(set) var timeZone: TimeZone = .current
    private(set) var sourceCount = 0
    /// Which non-Open-Meteo providers (NWS, MET Norway, Apple Weather) are in the current mix, for attribution.
    private(set) var otherProviders: Set<String> = []
    /// Apple Weather's required attribution, fetched once any of its data is shown.
    private(set) var appleWeatherAttribution: WeatherAttribution?
    /// Official weather alerts for the place (via Apple Weather), shown as issued, never mixed.
    private(set) var alerts: [WeatherAlert] = []
    /// Apple Weather's minute-by-minute forecast for the next hour, where available (not mixed).
    private(set) var nextHour: Forecast<MinuteWeather>?
    private(set) var isLoading = false
    var errorMessage: String?

    /// The day the user picked beyond the 7-day list, if any.
    private(set) var pickedDay: WishcastDay?
    private(set) var isLoadingLongRange = false
    /// True when the ~6-month long-range forecast couldn't be downloaded, so the picker stops early.
    private(set) var isLongRangeMissing = false
    /// The last calendar day (in the device calendar, for the date picker) that has forecast data.
    private(set) var lastPickableDate: Date?

    private var forecasts: [DayForecast] = [] {
        didSet {
            let sources = Set(forecasts.map(\.source))
            sourceCount = sources.count
            otherProviders = sources.intersection([OpenMeteoClient.nwsName, OpenMeteoClient.metNorwayName, OpenMeteoClient.appleWeatherName])
            rebuildDays()
        }
    }
    /// Up to 35 days of hourly forecasts plus ECMWF's long-range ensemble; downloaded only when needed.
    private var longRangeForecasts: [DayForecast] = []
    private var longRangePlaceID: Place.ID?
    /// Local midnight (in the location's time zone) of the picked day.
    private var pickedDate: Date?
    private let client = OpenMeteoClient()

    init() {
        wish = SharedSettings.wish
        preferences = SharedSettings.preferences
        place = SharedSettings.place
        savedPlaces = SharedSettings.savedPlaces
        favorites = SharedSettings.favorites
    }

    /// Recent results per place, so moving between favorites doesn't download everything again.
    /// A full download costs about 180 of Open-Meteo's free daily calls.
    private var recentResults: [Place.ID: (date: Date, result: OpenMeteoClient.Result)] = [:]
    private static let reuseInterval: TimeInterval = 15 * 60

    /// `force` (pull to refresh) always downloads; otherwise a result from the last 15 minutes is reused.
    func refresh(force: Bool = true) async {
        guard let place else { return }
        if !force, let recent = recentResults[place.id], Date.now.timeIntervalSince(recent.date) < Self.reuseInterval {
            apply(recent.result)
            await loadOfficial(for: place)
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.forecasts(for: place, includeAppleWeather: true)
            recentResults[place.id] = (.now, result)
            // The user may have moved on to another place while this downloaded.
            guard place.id == self.place?.id else { return }
            apply(result)
            await loadOfficial(for: place)
            if otherProviders.contains(OpenMeteoClient.appleWeatherName) || !alerts.isEmpty || nextHour != nil,
               appleWeatherAttribution == nil {
                appleWeatherAttribution = try? await WeatherService.shared.attribution
            }
        } catch {
            errorMessage = String(localized: "Couldn't load forecasts. Pull to try again.")
        }
    }

    /// Alerts and the next-hour forecast. Both are optional extras: where Apple Weather has neither,
    /// or the request fails, they're simply not shown.
    private func loadOfficial(for place: Place) async {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let (minute, alerts) = (try? await WeatherService.shared.weather(for: location, including: .minute, .alerts)) ?? (nil, nil)
        guard place.id == self.place?.id else { return }
        nextHour = minute
        self.alerts = alerts ?? []
    }

    /// Whether rain, snow or other precipitation is expected at some point in the next hour.
    var precipitationExpectedSoon: Bool {
        nextHour?.forecast.contains { $0.precipitation != .none && $0.precipitationChance >= 0.3 } ?? false
    }

    private func apply(_ result: OpenMeteoClient.Result) {
        timeZone = result.timeZone
        conditions = result.conditions
        forecasts = result.forecasts
        errorMessage = nil
    }

    func select(_ newPlace: Place) async {
        place = newPlace
        SharedSettings.place = newPlace
        if !savedPlaces.contains(newPlace) {
            savedPlaces.append(newPlace)
            SharedSettings.savedPlaces = savedPlaces
        }
        forecasts = []
        conditions = nil
        alerts = []
        nextHour = nil
        longRangeForecasts = []
        longRangePlaceID = nil
        lastPickableDate = nil
        pickedDate = nil
        rebuildPickedDay()
        WidgetCenter.shared.reloadAllTimelines()
        await refresh(force: false)
    }

    // MARK: - Favorites

    func isFavorite(_ place: Place) -> Bool {
        favorites.contains { $0.id == place.id }
    }

    /// Saved places that aren't starred.
    var otherSavedPlaces: [Place] {
        savedPlaces.filter { !isFavorite($0) }
    }

    func toggleFavorite(_ place: Place) {
        if isFavorite(place) {
            favorites.removeAll { $0.id == place.id }
        } else {
            favorites.append(place)
            if !savedPlaces.contains(where: { $0.id == place.id }) { savedPlaces.append(place) }
        }
        saveFavorites()
    }

    func moveFavorites(from source: IndexSet, to destination: Int) {
        // `Array.move(fromOffsets:)` lives in SwiftUI; do the same by hand.
        let moving = source.sorted().map { favorites[$0] }
        var remaining = favorites
        for index in source.sorted(by: >) { remaining.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: insertAt)
        favorites = remaining
        saveFavorites()
    }

    /// Removes places from the saved list (and favorites).
    func removePlaces(_ places: [Place]) {
        let ids = Set(places.map(\.id))
        savedPlaces.removeAll { ids.contains($0.id) }
        favorites.removeAll { ids.contains($0.id) }
        saveFavorites()
    }

    /// Where the current place sits among favorites, if it's one of them.
    var favoriteIndex: Int? {
        guard let place else { return nil }
        return favorites.firstIndex { $0.id == place.id }
    }

    /// Moves to the next (`step` 1) or previous (-1) favorite, wrapping around. From a place
    /// that isn't a favorite, goes to the first one.
    func showFavorite(step: Int) async {
        guard !favorites.isEmpty else { return }
        let next = favoriteIndex.map { ($0 + step + favorites.count) % favorites.count } ?? 0
        await select(favorites[next])
    }

    func showFavorite(at index: Int) async {
        guard favorites.indices.contains(index) else { return }
        await select(favorites[index])
    }

    private func saveFavorites() {
        SharedSettings.savedPlaces = savedPlaces
        SharedSettings.favorites = favorites
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Downloads long-range forecasts for the current place, once.
    func loadLongRange() async {
        guard let place, longRangePlaceID != place.id, !isLoadingLongRange else { return }
        isLoadingLongRange = true
        defer { isLoadingLongRange = false }
        do {
            let hourly = try await client.forecasts(for: place, days: 35, includeAppleWeather: true)
            // The long-range ensemble adds 51 more forecasts to every day after the 7-day list.
            let lastListDay = days.map(\.date).max() ?? .now
            let daily: [DayForecast]
            do {
                daily = try await client.longRangeForecasts(for: place, after: lastListDay)
                isLongRangeMissing = false
            } catch {
                daily = []
                isLongRangeMissing = true
            }
            longRangeForecasts = hourly.forecasts + daily
            // Without the long-range forecast, try again the next time the picker opens.
            longRangePlaceID = isLongRangeMissing ? nil : place.id
            lastPickableDate = longRangeForecasts.map(\.date).max().map(deviceDate(fromLocal:))
            rebuildPickedDay()
        } catch {
            errorMessage = String(localized: "Couldn't load long-range forecasts. Try again later.")
        }
    }

    /// Picks a calendar day from the date picker. Returns the date to select in the list.
    func pick(_ date: Date) -> Date? {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let local = calendar.date(from: components) else { return nil }
        // Days already in the 7-day list are simply selected there.
        if days.contains(where: { $0.date == local }) {
            pickedDate = nil
            rebuildPickedDay()
            return local
        }
        pickedDate = local
        rebuildPickedDay()
        return pickedDay?.date
    }

    func day(for date: Date?) -> WishcastDay? {
        guard let date else { return nil }
        return days.first { $0.date == date } ?? (pickedDay?.date == date ? pickedDay : nil)
    }

    /// The same calendar day as a location-local midnight, expressed in the device calendar.
    private func deviceDate(fromLocal date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return Calendar.current.date(from: calendar.dateComponents([.year, .month, .day], from: date)) ?? date
    }

    private func rebuildPickedDay() {
        guard let pickedDate else {
            pickedDay = nil
            return
        }
        pickedDay = WishcastDay.build(from: longRangeForecasts.filter { $0.date == pickedDate }, wish: wish, preferences: preferences).first
    }

    func useCurrentLocation() async {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied {
                    errorMessage = String(localized: "Location access is off. Search for a place instead.")
                    return
                }
                if let coordinate = update.location?.coordinate {
                    await select(Place(name: String(localized: "Current Location"),
                                       latitude: coordinate.latitude,
                                       longitude: coordinate.longitude))
                    return
                }
            }
        } catch {
            errorMessage = String(localized: "Couldn't find your location.")
        }
    }

    func conditions(for day: WishcastDay) -> Conditions.Daily? {
        conditions?.daily[day.date]
    }

    /// Whether it's dark at the place right now and `day` is today (only today has a "now").
    func isNightNow(on day: WishcastDay) -> Bool {
        guard day.date == days.first?.date, let daily = conditions(for: day) else { return false }
        return Date.now < daily.sunrise || Date.now > daily.sunset
    }

    private func settingsChanged() {
        rebuildDays()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func rebuildDays() {
        days = WishcastDay.build(from: forecasts, wish: wish, preferences: preferences)
        rebuildPickedDay()
        syncWatch()
    }

    /// The place, wish and week, formatted for the Apple Watch app and its complications.
    private func syncWatch() {
        guard let place, !days.isEmpty else { return }
        let wishTitle = String(localized: wish.title)
        WatchSync.shared.send(WatchSummary(
            place: place.name,
            wishTitle: wishTitle,
            wishSymbol: wish.symbolName,
            wish: wish.rawValue,
            note: String(localized: "Best case for \(wishTitle). Not a prediction."),
            updated: .now,
            days: days.prefix(7).map { day in
                let count = day.forecasts.count
                return WatchSummary.Day(
                    weekday: day.weekday(in: timeZone, width: .abbreviated),
                    symbol: day.symbolName,
                    high: Metric.temperature.format(day.high.value),
                    low: Metric.temperature.format(day.low.value),
                    matchText: String(localized: "H: \(day.high.sameValueCount) of \(count) \u{00B7} L: \(day.low.sameValueCount) of \(count)")
                )
            }
        ))
    }
}
