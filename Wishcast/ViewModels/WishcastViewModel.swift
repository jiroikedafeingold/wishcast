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
    private(set) var days: [WishcastDay] = []
    private(set) var conditions: Conditions?
    private(set) var timeZone: TimeZone = .current
    private(set) var sourceCount = 0
    /// Which non-Open-Meteo providers (NWS, MET Norway, Apple Weather) are in the current mix, for attribution.
    private(set) var otherProviders: Set<String> = []
    /// Apple Weather's required attribution, fetched once its forecast is in the mix.
    private(set) var appleWeatherAttribution: WeatherAttribution?
    private(set) var isLoading = false
    var errorMessage: String?

    /// The day the user picked beyond the 7-day list, if any.
    private(set) var pickedDay: WishcastDay?
    private(set) var isLoadingLongRange = false
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
    }

    func refresh() async {
        guard let place else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.forecasts(for: place, includeAppleWeather: true)
            timeZone = result.timeZone
            conditions = result.conditions
            forecasts = result.forecasts
            errorMessage = nil
            if otherProviders.contains(OpenMeteoClient.appleWeatherName), appleWeatherAttribution == nil {
                appleWeatherAttribution = try? await WeatherService.shared.attribution
            }
        } catch {
            errorMessage = String(localized: "Couldn't load forecasts. Pull to try again.")
        }
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
        longRangeForecasts = []
        longRangePlaceID = nil
        lastPickableDate = nil
        pickedDate = nil
        rebuildPickedDay()
        WidgetCenter.shared.reloadAllTimelines()
        await refresh()
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
            let daily = (try? await client.longRangeForecasts(for: place, after: lastListDay)) ?? []
            longRangeForecasts = hourly.forecasts + daily
            longRangePlaceID = place.id
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

    func removePlaces(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            savedPlaces.remove(at: index)
        }
        SharedSettings.savedPlaces = savedPlaces
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
    }
}
