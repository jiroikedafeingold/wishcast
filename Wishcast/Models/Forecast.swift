import Foundation

/// A location the user wants a forecast for.
struct Place: Codable, Hashable, Identifiable {
    var name: String
    var detail: String?
    var latitude: Double
    var longitude: Double

    var id: String { "\(latitude),\(longitude)" }
}

/// The user's ideal temperatures, stored in °C. Defaults are common comfortable values, user-adjustable.
struct Preferences: Codable, Equatable {
    /// Default 75°F / 24°C.
    var idealHigh = 23.9
    /// Default 60°F / 16°C.
    var idealEvening = 15.6
    /// Default 55°F / 13°C.
    var idealLow = 12.8
}

/// One hour of one forecast source. Values are metric.
struct HourForecast: Identifiable {
    let date: Date
    let localHour: Int
    let temperature: Double
    let precipitation: Double
    let snowfall: Double?
    let cloudCover: Double?
    let gust: Double?

    var id: Date { date }

    var symbolName: String {
        conditionSymbol(snowfall: (snowfall ?? 0) * 10, precipitation: precipitation * 10, cape: nil,
                        gust: gust, cloudCover: cloudCover, isNight: localHour < 7 || localHour >= 19)
    }
}

/// One forecast source's prediction for a single local day. All values are metric.
struct DayForecast: Identifiable {
    let source: String
    /// Local midnight of the day at the forecast location.
    let date: Date
    let high: Double            // °C
    let low: Double             // °C
    let eveningTemp: Double?    // °C, mean of 6–10 pm; nil for long-range daily-only forecasts
    let precipitation: Double   // mm
    let snowfall: Double?       // cm; nil when the source doesn't forecast snow
    let cloudCover: Double?     // %, daytime mean
    let maxGust: Double?        // km/h
    let maxCAPE: Double?        // J/kg, thunderstorm energy
    let hours: [HourForecast]

    var id: String { "\(source)-\(date.timeIntervalSince1970)" }

    var symbolName: String {
        conditionSymbol(snowfall: snowfall ?? 0, precipitation: precipitation, cape: maxCAPE,
                        gust: maxGust, cloudCover: cloudCover, isNight: false)
    }
}

/// SF Symbol for a set of conditions (daily totals; hourly callers scale up to match thresholds).
func conditionSymbol(snowfall: Double, precipitation: Double, cape: Double?, gust: Double?, cloudCover: Double?, isNight: Bool) -> String {
    if snowfall >= 0.5 { return "cloud.snow.fill" }
    if precipitation >= 1 { return (cape ?? 0) >= 1000 ? "cloud.bolt.rain.fill" : "cloud.rain.fill" }
    if (gust ?? 0) >= 60 { return "wind" }
    switch cloudCover ?? 50 {
    case ..<25: return isNight ? "moon.stars.fill" : "sun.max.fill"
    case ..<70: return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
    default: return "cloud.fill"
    }
}

/// What's actually happening right now, plus official daily details, from Open-Meteo's best-match model.
struct Conditions {
    struct Daily {
        let sunrise: Date
        let sunset: Date
        let uvIndexMax: Double?
        let precipitationChance: Double?
    }

    let temperature: Double
    let feelsLike: Double
    let humidity: Double
    let windSpeed: Double
    let weatherCode: Int
    let isDay: Bool
    /// Keyed by local midnight, matching `DayForecast.date`.
    let daily: [Date: Daily]

    /// WMO weather code to symbol and description.
    var symbolName: String {
        switch weatherCode {
        case 0, 1: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    var summary: String {
        switch weatherCode {
        case 0: String(localized: "Clear")
        case 1: String(localized: "Mostly Clear")
        case 2: String(localized: "Partly Cloudy")
        case 3: String(localized: "Cloudy")
        case 45, 48: String(localized: "Foggy")
        case 51...57: String(localized: "Drizzle")
        case 61...67, 80...82: String(localized: "Rain")
        case 71...77, 85, 86: String(localized: "Snow")
        case 95...99: String(localized: "Thunderstorms")
        default: String(localized: "Cloudy")
        }
    }
}

/// The kind of weather the user is hoping for.
enum Wish: String, CaseIterable, Identifiable, Codable {
    case snow, sunny, wild, coolEvenings, pleasant

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .snow: "Snow"
        case .sunny: "Sunny"
        case .wild: "Wild Weather"
        case .coolEvenings: "Cool Evenings"
        case .pleasant: "Nice & Pleasant"
        }
    }

    var symbolName: String {
        switch self {
        case .snow: "snowflake"
        case .sunny: "sun.max.fill"
        case .wild: "tornado"
        case .coolEvenings: "moon.stars.fill"
        case .pleasant: "leaf.fill"
        }
    }

    /// How each value of a day is chosen from all forecasts. This table is the single source of
    /// truth: the Wishcast is built from it and the "How Wishcast Works" screen describes it.
    func choice(for field: Field, preferences: Preferences) -> Choice {
        switch (self, field) {
        case (.snow, .snowfall), (.snow, .precipitation): .highest
        case (.snow, .high), (.snow, .low), (.snow, .evening): .lowest

        case (.sunny, .cloudCover), (.sunny, .precipitation), (.sunny, .snowfall): .lowest

        case (.wild, .high), (.wild, .precipitation), (.wild, .snowfall), (.wild, .gust): .highest
        case (.wild, .low): .lowest

        case (.coolEvenings, .evening): .closest(preferences.idealEvening)
        case (.coolEvenings, .low): .closest(preferences.idealLow)
        case (.coolEvenings, .precipitation), (.coolEvenings, .cloudCover): .lowest

        case (.pleasant, .high): .closest(preferences.idealHigh)
        case (.pleasant, .evening): .closest(preferences.idealEvening)
        case (.pleasant, .low): .closest(preferences.idealLow)
        case (.pleasant, .precipitation), (.pleasant, .snowfall), (.pleasant, .cloudCover), (.pleasant, .gust): .lowest

        default: .typical
        }
    }

    /// Whether a single, unmixed forecast delivers the wish. Used for the "N of M forecasts match" count.
    /// Missing snowfall, gusts or thunderstorm energy count as none; missing cloud cover counts as cloudy.
    func isMatched(by day: DayForecast, preferences: Preferences) -> Bool {
        switch self {
        case .snow:
            (day.snowfall ?? 0) >= 0.5
        case .sunny:
            (day.cloudCover ?? 100) <= 30 && day.precipitation < 0.5
        case .wild:
            (day.maxGust ?? 0) >= 60 || day.precipitation >= 15 || (day.snowfall ?? 0) >= 10 || (day.maxCAPE ?? 0) >= 1000
        case .coolEvenings:
            day.eveningTemp.map { abs($0 - preferences.idealEvening) <= 3 } ?? false
        case .pleasant:
            abs(day.high - preferences.idealHigh) <= 3 && day.precipitation < 1 && (day.maxGust ?? 0) < 40
        }
    }

    /// Plain-language version of `isMatched`, kept next to it so the two stay in sync.
    func matchDescription(preferences: Preferences) -> String {
        let tolerance = Metric.temperatureDifference(3)
        switch self {
        case .snow:
            return String(localized: "\(Metric.snowfall.format(0.5)) or more of snow.")
        case .sunny:
            return String(localized: "Daytime cloud cover of 30% or less, and less than \(Metric.rainfall.format(0.5)) of precipitation.")
        case .wild:
            return String(localized: "Gusts of \(Metric.wind.format(60)) or more, or \(Metric.rainfall.format(15)) or more of precipitation, or \(Metric.snowfall.format(10)) or more of snow, or strong thunderstorm potential (CAPE, a measure of how unstable the air is, of 1,000 J/kg or more).")
        case .coolEvenings:
            return String(localized: "An evening average within \(tolerance) of your perfect evening (\(Metric.temperature.format(preferences.idealEvening))).")
        case .pleasant:
            return String(localized: "A high within \(tolerance) of your perfect high (\(Metric.temperature.format(preferences.idealHigh))), less than \(Metric.rainfall.format(1)) of precipitation, and gusts under \(Metric.wind.format(40)).")
        }
    }

    /// The value this wish cares about most; charted on the day screen and used to choose the hourly forecast.
    var keyField: Field {
        switch self {
        case .snow: .snowfall
        case .sunny: .cloudCover
        case .wild: .gust
        case .coolEvenings: .evening
        case .pleasant: .high
        }
    }
}

/// One value shown for a day. Each is chosen independently from all forecasts for that day.
enum Field: CaseIterable, Identifiable {
    case high, low, evening, precipitation, snowfall, cloudCover, gust

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .high: "High"
        case .low: "Low"
        case .evening: "Evening Avg"
        case .precipitation: "Precipitation"
        case .snowfall: "Snowfall"
        case .cloudCover: "Daytime Clouds"
        case .gust: "Peak Gusts"
        }
    }

    /// Exactly how the value is computed from a forecast's hourly data.
    var definition: LocalizedStringResource {
        switch self {
        case .high: "The warmest hourly temperature from midnight to midnight."
        case .low: "The coldest hourly temperature from midnight to midnight."
        case .evening: "The average of the hourly temperatures from 6 PM to 10 PM."
        case .precipitation: "Total rain plus melted snow for the day."
        case .snowfall: "Total snowfall for the day."
        case .cloudCover: "The average of the hourly cloud cover from 8 AM to 5 PM."
        case .gust: "The strongest hourly wind gust of the day."
        }
    }

    var symbolName: String {
        switch self {
        case .high: "thermometer.sun.fill"
        case .low: "thermometer.snowflake"
        case .evening: "moon.fill"
        case .precipitation: "drop.fill"
        case .snowfall: "snowflake"
        case .cloudCover: "cloud.fill"
        case .gust: "wind"
        }
    }

    var metric: Metric {
        switch self {
        case .high, .low, .evening: .temperature
        case .precipitation: .rainfall
        case .snowfall: .snowfall
        case .cloudCover: .cloudCover
        case .gust: .wind
        }
    }

    func value(_ day: DayForecast) -> Double? {
        switch self {
        case .high: day.high
        case .low: day.low
        case .evening: day.eveningTemp
        case .precipitation: day.precipitation
        case .snowfall: day.snowfall
        case .cloudCover: day.cloudCover
        case .gust: day.maxGust
        }
    }
}

/// How one value is chosen from all forecasts.
enum Choice: Equatable {
    /// The forecast value nearest a preferred temperature (°C).
    case closest(Double)
    case lowest
    case highest
    /// The median of all forecasts, for values the wish doesn't care about.
    case typical

    func describe(_ field: Field) -> String {
        switch self {
        case .closest(let target): String(localized: "Closest to your \(Metric.temperature.format(target))")
        case .lowest: String(localized: "Lowest of all forecasts")
        case .highest: String(localized: "Highest of all forecasts")
        case .typical: String(localized: "Typical: the median of all forecasts")
        }
    }
}

/// One chosen value for a day, and where it came from.
struct PickedValue {
    let field: Field
    let choice: Choice
    let value: Double
    /// The forecast it came from. Nil for `.typical`, which is a median rather than one forecast's value.
    let source: DayForecast?
    /// How many forecasts show this value as displayed, e.g. how many forecasts' highs also read 66°.
    let sameValueCount: Int
    /// How many forecasts report this value at all.
    let sampleSize: Int

    var sourceDescription: String {
        if choice == .typical { return String(localized: "Median of \(sampleSize) forecasts") }
        if sameValueCount > 1 { return String(localized: "\(sameValueCount) of \(sampleSize) forecasts show this") }
        return source?.source ?? ""
    }

    /// Counts forecasts whose value formats the same as `value`, so the count matches what's on screen.
    private static func countShowing(_ value: Double, field: Field, in values: [Double]) -> Int {
        let shown = field.metric.format(value)
        return values.count { field.metric.format($0) == shown }
    }

    static func pick(_ field: Field, choice: Choice, from forecasts: [DayForecast]) -> PickedValue? {
        // Sorted by source name so ties resolve the same way on every refresh.
        let candidates = forecasts
            .compactMap { forecast in field.value(forecast).map { (forecast: forecast, value: $0) } }
            .sorted { $0.forecast.source < $1.forecast.source }
        guard !candidates.isEmpty else { return nil }

        let best: (forecast: DayForecast, value: Double)?
        switch choice {
        case .lowest: best = candidates.min { $0.value < $1.value }
        case .highest: best = candidates.max { $0.value < $1.value }
        case .closest(let target): best = candidates.min { abs($0.value - target) < abs($1.value - target) }
        case .typical:
            let values = candidates.map(\.value).sorted()
            let median = values.count.isMultiple(of: 2)
                ? (values[values.count / 2 - 1] + values[values.count / 2]) / 2
                : values[values.count / 2]
            return PickedValue(field: field, choice: choice, value: median, source: nil,
                               sameValueCount: countShowing(median, field: field, in: values), sampleSize: candidates.count)
        }
        guard let best else { return nil }
        return PickedValue(
            field: field,
            choice: choice,
            value: best.value,
            source: best.forecast,
            sameValueCount: countShowing(best.value, field: field, in: candidates.map(\.value)),
            sampleSize: candidates.count
        )
    }
}

/// Formats metric values in the user's preferred units.
enum Metric {
    case temperature, rainfall, snowfall, wind, cloudCover

    func format(_ value: Double) -> String {
        switch self {
        case .temperature:
            Measurement(value: value, unit: UnitTemperature.celsius)
                .formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0))))
        case .rainfall:
            // Two decimals so small amounts in inches (1 mm ≈ 0.04 in) don't round to "0 in".
            Measurement(value: value, unit: UnitLength.millimeters)
                .formatted(.measurement(width: .abbreviated, usage: .rainfall, numberFormatStyle: .number.precision(.fractionLength(0...2))))
        case .snowfall:
            Measurement(value: value, unit: UnitLength.centimeters)
                .formatted(.measurement(width: .abbreviated, usage: .snowfall, numberFormatStyle: .number.precision(.fractionLength(0...1))))
        case .wind:
            Measurement(value: value, unit: UnitSpeed.kilometersPerHour)
                .formatted(.measurement(width: .abbreviated, usage: .wind, numberFormatStyle: .number.precision(.fractionLength(0))))
        case .cloudCover:
            (value / 100).formatted(.percent.precision(.fractionLength(0)))
        }
    }

    /// The metric value converted to the user's preferred unit.
    func displayValue(_ value: Double) -> Double {
        switch self {
        case .temperature: Measurement(value: value, unit: UnitTemperature.celsius).converted(to: Self.temperatureUnit).value
        case .rainfall: Measurement(value: value, unit: UnitLength.millimeters).converted(to: UnitLength(forLocale: .current, usage: .rainfall)).value
        case .snowfall: Measurement(value: value, unit: UnitLength.centimeters).converted(to: UnitLength(forLocale: .current, usage: .snowfall)).value
        case .wind: Measurement(value: value, unit: UnitSpeed.kilometersPerHour).converted(to: UnitSpeed(forLocale: .current, usage: .wind)).value
        case .cloudCover: value
        }
    }

    /// Symbol for the unit `displayValue` returns, e.g. "°F" or "mm".
    var unitSymbol: String {
        switch self {
        case .temperature: Self.temperatureUnit.symbol
        case .rainfall: UnitLength(forLocale: .current, usage: .rainfall).symbol
        case .snowfall: UnitLength(forLocale: .current, usage: .snowfall).symbol
        case .wind: UnitSpeed(forLocale: .current, usage: .wind).symbol
        case .cloudCover: "%"
        }
    }

    /// A temperature *difference* given in °C, in the user's unit (3°C → "5°F"), rounded.
    static func temperatureDifference(_ celsius: Double) -> String {
        let difference = Metric.temperature.displayValue(celsius) - Metric.temperature.displayValue(0)
        return "\(Int(difference.rounded()))\(temperatureUnit.symbol)"
    }

    /// The inverse of `displayValue` for temperatures, used when the user edits preferences.
    static func celsius(fromDisplay value: Double) -> Double {
        Measurement(value: value, unit: temperatureUnit).converted(to: .celsius).value
    }

    private static var temperatureUnit: UnitTemperature { UnitTemperature(forLocale: .current, usage: .weather) }
}

/// How far ahead a day is, which decides how the day screen labels it.
enum ForecastRange {
    /// Today through day 7.
    case near
    /// Days 8–14.
    case extended
    /// Day 15 and beyond.
    case longRange

    /// Days ahead counted from today in the location's time zone (today is 0).
    init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let daysAhead = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: date)).day ?? 0
        switch daysAhead {
        case ..<7: self = .near
        case ..<14: self = .extended
        default: self = .longRange
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .near: "Best case"
        case .extended: "Long shot"
        case .longRange: "Wild guess"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .near:
            "This is a wish, not a prediction."
        case .extended:
            "More than a week out, forecasts lose much of their skill and fewer models reach this far. Treat this as a long shot."
        case .longRange:
            "More than two weeks out, wild guess."
        }
    }
}

/// One day of the Wishcast: every value chosen independently from all forecasts for that day,
/// so the combination may not appear in any single forecast.
struct WishcastDay: Identifiable {
    let date: Date
    let forecasts: [DayForecast]
    let high: PickedValue
    let low: PickedValue
    /// Every field's pick, in `Field.allCases` order (including high and low).
    let values: [PickedValue]
    /// How many single, unmixed forecasts match the wish.
    let matchCount: Int
    /// The pick whose forecast supplies the hourly data on the day screen: the wish's key value
    /// when it came from a single forecast, otherwise the first value that did.
    let hourlyPick: PickedValue?

    var id: Date { date }
    var matchFraction: Double { Double(matchCount) / Double(forecasts.count) }

    func value(_ field: Field) -> PickedValue? {
        values.first { $0.field == field }
    }

    /// Drawn from the picked values, so it shows the best case too.
    var symbolName: String {
        conditionSymbol(snowfall: value(.snowfall)?.value ?? 0, precipitation: value(.precipitation)?.value ?? 0, cape: nil,
                        gust: value(.gust)?.value, cloudCover: value(.cloudCover)?.value, isNight: false)
    }

    /// Groups forecasts by day and, for each day, picks every value according to the wish's rules.
    static func build(from forecasts: [DayForecast], wish: Wish, preferences: Preferences) -> [WishcastDay] {
        Dictionary(grouping: forecasts, by: \.date)
            .compactMap { date, dayForecasts in
                var values = Field.allCases.compactMap { field in
                    PickedValue.pick(field, choice: wish.choice(for: field, preferences: preferences), from: dayForecasts)
                }
                guard let high = values.first(where: { $0.field == .high }),
                      var low = values.first(where: { $0.field == .low })
                else { return nil }
                // Mixing could pair a warm forecast's low with a cool forecast's high. Never show a
                // low above the high: re-pick it from forecasts whose low is at or below that high.
                if low.value > high.value,
                   let repicked = PickedValue.pick(.low, choice: low.choice, from: dayForecasts.filter { $0.low <= high.value }),
                   let index = values.firstIndex(where: { $0.field == .low }) {
                    low = repicked
                    values[index] = repicked
                }
                return WishcastDay(
                    date: date,
                    forecasts: dayForecasts,
                    high: high,
                    low: low,
                    values: values,
                    matchCount: dayForecasts.count { wish.isMatched(by: $0, preferences: preferences) },
                    hourlyPick: values.first { $0.field == wish.keyField && $0.source != nil }
                        ?? values.first { $0.source != nil }
                )
            }
            .sorted { $0.date < $1.date }
    }

    /// The middle-of-the-pack value across all forecasts — the honest, non-optimistic answer.
    func median(_ value: (DayForecast) -> Double?) -> Double? {
        let sorted = forecasts.compactMap(value).sorted()
        return sorted.isEmpty ? nil : sorted[sorted.count / 2]
    }

    func weekday(in timeZone: TimeZone, width: Date.FormatStyle.Symbol.Weekday = .wide) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        // Past the first week a weekday alone is ambiguous, so include the date.
        var style = ForecastRange(date: date, timeZone: timeZone) == .near
            ? Date.FormatStyle.dateTime.weekday(width)
            : Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = timeZone
        // Used as a title, so capitalize it even in languages that write weekdays lowercase (e.g. Russian).
        style.capitalizationContext = .standalone
        return date.formatted(style)
    }

    func shortDate(in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        style.timeZone = timeZone
        return date.formatted(style)
    }
}

/// Settings shared between the app and its widget through an App Group.
enum SharedSettings {
    static let appGroup = "group.com.jirofeingold.wishcast"

    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static var wish: Wish {
        get { defaults.string(forKey: "wish").flatMap(Wish.init(rawValue:)) ?? .pleasant }
        set { defaults.set(newValue.rawValue, forKey: "wish") }
    }

    static var preferences: Preferences {
        get { decode("preferences") ?? Preferences() }
        set { encode(newValue, "preferences") }
    }

    static var place: Place? {
        get { decode("place") }
        set { encode(newValue, "place") }
    }

    static var savedPlaces: [Place] {
        get { decode("savedPlaces") ?? [] }
        set { encode(newValue, "savedPlaces") }
    }

    private static func decode<T: Decodable>(_ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func encode(_ value: some Encodable, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
