import Foundation

/// Fetches forecasts from a set of global Open-Meteo models plus every member of several
/// ensembles, and reduces each to per-day summaries.
struct OpenMeteoClient {
    /// Display names, for the "How Wishcast Works" screen.
    static var modelNames: [String] { models.values.sorted() }
    static var ensembleNames: [String] { ensembles.values.sorted() }

    struct Result {
        let forecasts: [DayForecast]
        let conditions: Conditions?
        let timeZone: TimeZone
    }

    private struct Batch {
        let response: ForecastResponse
        let forecasts: [DayForecast]
    }

    private static let variables = ["temperature_2m", "precipitation", "snowfall", "cloud_cover", "wind_gusts_10m", "cape"]

    private static let models = [
        "ecmwf_ifs025": "ECMWF",
        "ecmwf_aifs025_single": "ECMWF AI",
        "gfs_seamless": "GFS",
        "icon_seamless": "ICON",
        "gem_seamless": "GEM",
        "jma_seamless": "JMA",
        "meteofrance_seamless": "Météo-France",
        "ukmo_seamless": "UK Met Office",
        "cma_grapes_global": "CMA"
    ]

    private static let ensembles = [
        "ecmwf_ifs025": "ECMWF Ensemble",
        "gfs_seamless": "GFS Ensemble",
        "icon_seamless": "ICON Ensemble",
        "gem_global": "GEM Ensemble",
        "ukmo_global_ensemble_20km": "UK Met Office Ensemble"
    ]

    /// `days` up to 35 (the ensembles' limit). The standard models stop at the forecast API's 16-day limit.
    func forecasts(for place: Place, days: Int = 7) async throws -> Result {
        let standardDays = min(days, 16)
        async let conditions = try? fetchConditions(for: place, days: standardDays)

        // Each request is independent: a failing ensemble shouldn't sink the others.
        let batches = await withTaskGroup(of: Batch?.self) { group in
            group.addTask {
                guard let response = try? await fetch(host: "api.open-meteo.com", path: "/v1/forecast",
                                                      models: Self.models.keys.joined(separator: ","), place: place, days: standardDays)
                else { return nil }
                return Batch(response: response, forecasts: Self.summarize(response) { suffix in
                    Self.models[String(suffix.dropFirst())]
                })
            }
            for (model, name) in Self.ensembles {
                group.addTask {
                    guard let response = try? await fetch(host: "ensemble-api.open-meteo.com", path: "/v1/ensemble",
                                                          models: model, place: place, days: days)
                    else { return nil }
                    // Ensemble keys look like "temperature_2m" (control run) and "temperature_2m_member07".
                    return Batch(response: response, forecasts: Self.summarize(response) { suffix in
                        if suffix.isEmpty { return String(localized: "\(name) control") }
                        guard let member = Int(suffix.replacing("_member", with: "")) else { return nil }
                        return "\(name) #\(member)"
                    })
                }
            }
            var batches: [Batch] = []
            for await batch in group {
                if let batch { batches.append(batch) }
            }
            return batches
        }

        guard let first = batches.first?.response else { throw URLError(.cannotLoadFromNetwork) }
        return await Result(
            forecasts: batches.flatMap(\.forecasts),
            conditions: conditions,
            timeZone: TimeZone(identifier: first.timezone) ?? TimeZone(secondsFromGMT: first.utcOffsetSeconds) ?? .current
        )
    }

    /// Display name for the long-range ensemble, for credits and source labels.
    static let longRangeName = "ECMWF Long-Range"

    /// ECMWF's long-range ensemble (EC46, then SEAS5): 51 members, daily values only, about 6 months out.
    /// Only days after `after` are returned.
    func longRangeForecasts(for place: Place, after: Date) async throws -> [DayForecast] {
        let response: DailyResponse = try await get(components(host: "seasonal-api.open-meteo.com", path: "/v1/seasonal", place: place, days: 217, extra: [
            URLQueryItem(name: "daily", value: Self.dailyVariables.joined(separator: ","))
        ]))
        var members: [String: [String: [Double?]]] = [:]
        for (key, values) in response.daily {
            guard let variable = Self.dailyVariables.first(where: { key == $0 || key.hasPrefix($0 + "_") }) else { continue }
            members[String(key.dropFirst(variable.count)), default: [:]][variable] = values
        }
        guard let times = response.daily["time"]?.compactMap({ $0 }) else { return [] }
        return members.flatMap { suffix, series -> [DayForecast] in
            let source: String
            if suffix.isEmpty {
                source = String(localized: "\(Self.longRangeName) control")
            } else if let member = Int(suffix.replacing("_member", with: "")) {
                source = "\(Self.longRangeName) #\(member)"
            } else {
                return []
            }
            return times.indices.compactMap { index -> DayForecast? in
                func value(_ variable: String) -> Double? {
                    guard let values = series[variable], index < values.count else { return nil }
                    return values[index]
                }
                let date = Self.localMidnight(dailyTime: times[index], fixedOffset: response.utcOffsetSeconds, timeZoneID: response.timezone)
                guard date > after, let high = value("temperature_2m_max"), let low = value("temperature_2m_min"),
                      let precipitation = value("precipitation_sum")
                else { return nil }
                return DayForecast(
                    source: source,
                    date: date,
                    high: high,
                    low: low,
                    eveningTemp: nil,
                    precipitation: precipitation,
                    snowfall: value("snowfall_sum") ?? 0,
                    // A 24-hour average here; the hourly forecasts use 8 AM–5 PM.
                    cloudCover: value("cloud_cover_mean"),
                    maxGust: value("wind_gusts_10m_max"),
                    maxCAPE: nil,
                    hours: []
                )
            }
        }
    }

    /// Open-Meteo's *daily* timestamps use one fixed UTC offset for the whole response, so after a
    /// daylight-saving change they're an hour off. This returns the day's real local midnight.
    private static func localMidnight(dailyTime: Double, fixedOffset: Int, timeZoneID: String) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let day = utc.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: dailyTime + Double(fixedOffset)))
        var local = Calendar(identifier: .gregorian)
        local.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: fixedOffset) ?? .current
        return local.date(from: day) ?? Date(timeIntervalSince1970: dailyTime)
    }

    private static let dailyVariables = ["temperature_2m_max", "temperature_2m_min", "precipitation_sum", "snowfall_sum", "cloud_cover_mean", "wind_gusts_10m_max"]

    func searchPlaces(_ query: String) async throws -> [Place] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "geocoding-api.open-meteo.com"
        components.path = "/v1/search"
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "en")
        ]
        let response: GeocodingResponse = try await get(components)
        return (response.results ?? []).map { result in
            Place(
                name: result.name,
                detail: [result.admin1, result.country].compactMap { $0 }.joined(separator: ", "),
                latitude: result.latitude,
                longitude: result.longitude
            )
        }
    }

    // MARK: - Networking

    private func fetch(host: String, path: String, models: String, place: Place, days: Int) async throws -> ForecastResponse {
        try await get(components(host: host, path: path, place: place, days: days, extra: [
            URLQueryItem(name: "hourly", value: Self.variables.joined(separator: ",")),
            URLQueryItem(name: "models", value: models)
        ]))
    }

    private func fetchConditions(for place: Place, days: Int) async throws -> Conditions {
        let response: ConditionsResponse = try await get(components(host: "api.open-meteo.com", path: "/v1/forecast", place: place, days: days, extra: [
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"),
            URLQueryItem(name: "daily", value: "sunrise,sunset,uv_index_max,precipitation_probability_max")
        ]))
        var daily: [Date: Conditions.Daily] = [:]
        for (index, time) in response.daily.time.enumerated() where index < response.daily.sunrise.count && index < response.daily.sunset.count {
            daily[Self.localMidnight(dailyTime: time, fixedOffset: response.utcOffsetSeconds, timeZoneID: response.timezone)] = Conditions.Daily(
                sunrise: Date(timeIntervalSince1970: response.daily.sunrise[index]),
                sunset: Date(timeIntervalSince1970: response.daily.sunset[index]),
                uvIndexMax: response.daily.uvIndexMax[safe: index] ?? nil,
                precipitationChance: response.daily.precipitationProbabilityMax[safe: index] ?? nil
            )
        }
        let current = response.current
        return Conditions(
            temperature: current.temperature2m,
            feelsLike: current.apparentTemperature,
            humidity: current.relativeHumidity2m,
            windSpeed: current.windSpeed10m,
            weatherCode: current.weatherCode,
            isDay: current.isDay == 1,
            daily: daily
        )
    }

    private func components(host: String, path: String, place: Place, days: Int, extra: [URLQueryItem]) -> URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime")
        ] + extra
        return components
    }

    private func get<T: Decodable>(_ components: URLComponents) async throws -> T {
        guard let url = components.url else { throw URLError(.badURL) }
        #if DEBUG
        // Screenshot runs relaunch the app dozens of times; reuse each download so every shot and
        // language shows the same forecasts and Open-Meteo's free rate limit isn't exhausted.
        if let cached = Self.screenshotCache(for: url), let data = try? Data(contentsOf: cached) {
            return try JSONDecoder().decode(T.self, from: data)
        }
        #endif
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        #if DEBUG
        if let cached = Self.screenshotCache(for: url) { try? data.write(to: cached) }
        #endif
        return try JSONDecoder().decode(T.self, from: data)
    }

    #if DEBUG
    /// A per-URL cache file, only when launched for screenshots (`-shot N`).
    private static func screenshotCache(for url: URL) -> URL? {
        guard ProcessInfo.processInfo.arguments.contains("-shot") else { return nil }
        // URLs contain the place, models and forecast length, so a stable hash of the string is a safe key.
        let key = url.absoluteString.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        let folder = URL.cachesDirectory.appending(path: "ScreenshotForecasts", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: String(key, radix: 16) + ".json")
    }
    #endif

    // MARK: - Summarizing

    /// Splits a response into one series set per source, then reduces each to daily summaries.
    /// Keys are "<variable><suffix>", where the suffix identifies the model or ensemble member.
    static func summarize(_ response: ForecastResponse, label: (String) -> String?) -> [DayForecast] {
        guard let times = response.hourly["time"]?.compactMap({ $0 }) else { return [] }

        var sources: [String: [String: [Double?]]] = [:]
        for (key, values) in response.hourly {
            guard let variable = variables.first(where: { key == $0 || key.hasPrefix($0 + "_") }) else { continue }
            sources[String(key.dropFirst(variable.count)), default: [:]][variable] = values
        }

        // Each hour's real UTC offset, so days stay midnight-to-midnight across daylight-saving changes.
        let timeZone = TimeZone(identifier: response.timezone) ?? TimeZone(secondsFromGMT: response.utcOffsetSeconds) ?? .current
        let offsets = times.map { Double(timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: $0))) }

        return sources.flatMap { suffix, series -> [DayForecast] in
            guard let source = label(suffix) else { return [] }
            return dailySummaries(times: times, offsets: offsets, series: series, source: source)
        }
    }

    private static func dailySummaries(times: [Double], offsets: [Double], series: [String: [Double?]], source: String) -> [DayForecast] {
        let secondsPerDay = 86_400.0

        func value(_ variable: String, _ index: Int) -> Double? {
            guard let values = series[variable], index < values.count else { return nil }
            return values[index]
        }
        func values(_ variable: String, _ hours: [Int]) -> [Double] {
            hours.compactMap { value(variable, $0) }
        }
        func localHour(_ index: Int) -> Int {
            Int((times[index] + offsets[index]).truncatingRemainder(dividingBy: secondsPerDay) / 3600)
        }
        func mean(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }

        let hoursByDay = Dictionary(grouping: times.indices) { ((times[$0] + offsets[$0]) / secondsPerDay).rounded(.down) }

        return hoursByDay.compactMap { day, hours in
            // Local midnight uses the offset in effect at the day's first hour (changes happen at 2 AM).
            guard let firstHour = hours.min() else { return nil }
            let offset = offsets[firstHour]
            let temps = values("temperature_2m", hours)
            let precipitation = values("precipitation", hours)
            // Skip partial days (e.g. where a model's range ends) so comparisons stay fair.
            guard temps.count >= 20, precipitation.count >= 20,
                  let high = temps.max(), let low = temps.min(),
                  let evening = mean(values("temperature_2m", hours.filter { (18...22).contains(localHour($0)) }))
            else { return nil }

            let hourly = hours.sorted().compactMap { index -> HourForecast? in
                guard let temperature = value("temperature_2m", index) else { return nil }
                return HourForecast(
                    date: Date(timeIntervalSince1970: times[index]),
                    localHour: localHour(index),
                    temperature: temperature,
                    precipitation: value("precipitation", index) ?? 0,
                    snowfall: value("snowfall", index) ?? 0,
                    cloudCover: value("cloud_cover", index),
                    gust: value("wind_gusts_10m", index)
                )
            }

            return DayForecast(
                source: source,
                date: Date(timeIntervalSince1970: day * secondsPerDay - offset),
                high: high,
                low: low,
                eveningTemp: evening,
                precipitation: precipitation.reduce(0, +),
                snowfall: values("snowfall", hours).reduce(0, +),
                cloudCover: mean(values("cloud_cover", hours.filter { (8...17).contains(localHour($0)) })),
                maxGust: values("wind_gusts_10m", hours).max(),
                maxCAPE: values("cape", hours).max(),
                hours: hourly
            )
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ForecastResponse: Decodable {
    let utcOffsetSeconds: Int
    let timezone: String
    /// "time" plus one array per variable/source; all values decode as numbers.
    let hourly: [String: [Double?]]

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case timezone, hourly
    }
}

private struct DailyResponse: Decodable {
    let utcOffsetSeconds: Int
    let timezone: String
    /// "time" plus one array per variable/member.
    let daily: [String: [Double?]]

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case timezone, daily
    }
}

private struct ConditionsResponse: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let apparentTemperature: Double
        let relativeHumidity2m: Double
        let windSpeed10m: Double
        let weatherCode: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case relativeHumidity2m = "relative_humidity_2m"
            case windSpeed10m = "wind_speed_10m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [Double]
        let sunrise: [Double]
        let sunset: [Double]
        let uvIndexMax: [Double?]
        let precipitationProbabilityMax: [Double?]

        enum CodingKeys: String, CodingKey {
            case time, sunrise, sunset
            case uvIndexMax = "uv_index_max"
            case precipitationProbabilityMax = "precipitation_probability_max"
        }
    }

    let utcOffsetSeconds: Int
    let timezone: String
    let current: Current
    let daily: Daily

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case timezone, current, daily
    }
}

private struct GeocodingResponse: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?
    }

    let results: [Result]?
}
