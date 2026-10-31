import AppIntents
import WidgetKit

/// Siri and Shortcuts: ask for the best case on a day this week, or change what you're wishing for.
/// Both use the place and wish chosen in the app (shared with the widgets).

/// A day this week, as people say it.
enum ForecastDayOption: String, AppEnum {
    case today, tomorrow, monday, tuesday, wednesday, thursday, friday, saturday, sunday

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Day" }

    static var caseDisplayRepresentations: [ForecastDayOption: DisplayRepresentation] {
        [
            .today: "Today",
            .tomorrow: "Tomorrow",
            .monday: "Monday",
            .tuesday: "Tuesday",
            .wednesday: "Wednesday",
            .thursday: "Thursday",
            .friday: "Friday",
            .saturday: "Saturday",
            .sunday: "Sunday"
        ]
    }

    /// The Gregorian weekday number (Sunday = 1), for the named days.
    var weekday: Int? {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        case .today, .tomorrow: nil
        }
    }
}

/// The wishes, as Siri hears them.
enum WishOption: String, AppEnum {
    case pleasant, sunny, snow, rainy, wild, coolEvenings

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Wish" }

    static var caseDisplayRepresentations: [WishOption: DisplayRepresentation] {
        [
            .pleasant: DisplayRepresentation(title: "Nice & Pleasant", synonyms: ["nice and pleasant", "pleasant", "nice"]),
            .sunny: DisplayRepresentation(title: "Sun", synonyms: ["sunny", "sunshine"]),
            .snow: DisplayRepresentation(title: "Snow", synonyms: ["snowy"]),
            .rainy: DisplayRepresentation(title: "Rain", synonyms: ["rainy"]),
            .wild: DisplayRepresentation(title: "Wild Weather", synonyms: ["wild"]),
            .coolEvenings: DisplayRepresentation(title: "Cool Evenings", synonyms: ["cool evening"])
        ]
    }

    var wish: Wish {
        switch self {
        case .pleasant: .pleasant
        case .sunny: .sunny
        case .snow: .snow
        case .rainy: .rainy
        case .wild: .wild
        case .coolEvenings: .coolEvenings
        }
    }
}

/// "What's my Wishcast for Saturday?" The best case for your wish at your place, with how many
/// forecasts show it, so the answer stays honest.
struct GetWishcastIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Wishcast"
    static let description = IntentDescription("The best case for your wish on a day this week, at the place shown in Wishcast.")

    @Parameter(title: "Day", default: .today)
    var day: ForecastDayOption

    static var parameterSummary: some ParameterSummary {
        Summary("Get the Wishcast for \(\.$day)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let place = SharedSettings.place else {
            return .result(dialog: "Open Wishcast and choose a place first.")
        }
        let wish = SharedSettings.wish
        guard let result = try? await OpenMeteoClient().forecasts(for: place) else {
            return .result(dialog: "Wishcast couldn't download forecasts right now. Try again in a moment.")
        }
        let days = Array(WishcastDay.build(from: result.forecasts, wish: wish, preferences: SharedSettings.preferences).prefix(7))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = result.timeZone
        let match: WishcastDay? = switch day {
        case .today: days.first
        case .tomorrow: days.dropFirst().first
        default: days.first { calendar.component(.weekday, from: $0.date) == day.weekday }
        }
        guard let match, let high = match.value(.high), let low = match.value(.low) else {
            return .result(dialog: "Wishcast doesn't have that day yet.")
        }
        let dayName = match.weekday(in: result.timeZone)
        let highText = Metric.temperature.format(high.value)
        let lowText = Metric.temperature.format(low.value)
        let weather = Self.spokenWeather(for: match.symbolName)
        return .result(dialog: "Best case for \(wish.label) in \(place.name) on \(dayName): \(weather), a high of \(highText) and a low of \(lowText). \(high.sameValueCount) of \(high.sampleSize) forecasts show that high. It's a wish, not a prediction.")
    }

    /// The day's weather in a few words, from its icon.
    private static func spokenWeather(for symbolName: String) -> String {
        switch symbolName {
        case "sun.max.fill": String(localized: "sunny")
        case "cloud.sun.fill": String(localized: "partly cloudy")
        case "cloud.fill": String(localized: "cloudy")
        case "cloud.fog.fill": String(localized: "foggy")
        case "cloud.drizzle.fill": String(localized: "drizzle")
        case "cloud.rain.fill": String(localized: "rain")
        case "cloud.snow.fill": String(localized: "snow")
        case "cloud.bolt.rain.fill": String(localized: "thunderstorms")
        case "wind": String(localized: "windy")
        default: String(localized: "mixed weather")
        }
    }
}

/// "Set my Wishcast wish to snow." Changes the wish in the app and its widgets.
struct SetWishIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Wish"
    static let description = IntentDescription("Choose the weather you're wishing for in Wishcast.")

    @Parameter(title: "Wish")
    var wish: WishOption

    static var parameterSummary: some ParameterSummary {
        Summary("Wish for \(\.$wish)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        SharedSettings.wish = wish.wish
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Now wishing for \(wish.wish.label).")
    }
}

struct WishcastShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetWishcastIntent(),
            phrases: [
                "What's my \(.applicationName) for \(\.$day)",
                "What's the \(.applicationName) for \(\.$day)",
                "Get my \(.applicationName) for \(\.$day)",
                "What's my \(.applicationName)",
                "Get my \(.applicationName)"
            ],
            shortTitle: "Get Wishcast",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: SetWishIntent(),
            phrases: [
                "Set my \(.applicationName) wish to \(\.$wish)",
                "Make a \(.applicationName) wish for \(\.$wish)",
                "Wish for \(\.$wish) in \(.applicationName)"
            ],
            shortTitle: "Set Wish",
            systemImageName: "leaf.fill"
        )
    }
}
