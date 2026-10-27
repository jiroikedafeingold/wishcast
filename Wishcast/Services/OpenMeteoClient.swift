import Foundation
import CoreLocation
import WeatherKit

/// Fetches forecasts from a set of global Open-Meteo models plus every member of several
/// ensembles, and reduces each to per-day summaries.
struct OpenMeteoClient {
    /// Display names, for the "How Wishcast Works" screen.
    static var modelNames: [String] { models.values.sorted() }
    static var ensembleNames: [String] { ensembles.values.sorted() }
    static var providerNames: [String] { [nwsName, metNorwayName, appleWeatherName] }

    struct Result {
        let forecasts: [DayForecast]
        let conditions: Conditions?
        let timeZone: TimeZone
    }

    /// Which source a response came from, which decides how its keys map to forecast names.
    private enum Source {
        case models
        case ensemble(String)
        /// A single forecast whose keys carry no suffix (NWS, MET Norway, Apple Weather).
        case single(String)

        func label(_ suffix: String) -> String? {
            switch self {
            case .models:
                return OpenMeteoClient.models[String(suffix.dropFirst())]
            case .ensemble(let name):
                // Ensemble keys look like "temperature_2m" (control run) and "temperature_2m_member07".
                if suffix.isEmpty { return String(localized: "\(name) control") }
                guard let member = Int(suffix.replacing("_member", with: "")) else { return nil }
                return "\(name) #\(member)"
            case .single(let name):
                return suffix.isEmpty ? name : nil
            }
        }
    }

    private struct Batch {
        let response: ForecastResponse
        let source: Source
    }

    private static let variables = ["temperature_2m", "precipitation", "snowfall", "cloud_cover", "wind_gusts_10m", "cape"]

    /// Explicit models rather than Open-Meteo's "seamless" blends, which mix a provider's regional
    /// model into its global one and would count it twice. Regional models only return values inside
    /// their area; elsewhere they're all empty and drop out of the summaries.
    private static let models = [
        // Global
        "ecmwf_ifs025": "ECMWF",
        "ecmwf_aifs025_single": "ECMWF AI",
        "gfs_global": "GFS",
        "icon_global": "ICON",
        "gem_global": "GEM",
        "jma_gsm": "JMA",
        "meteofrance_arpege_world": "Météo-France ARPEGE",
        "ukmo_global_deterministic_10km": "UK Met Office",
        "cma_grapes_global": "CMA",
        // Regional
        "ncep_hrrr_conus": "NOAA HRRR",
        "ncep_nam_conus": "NOAA NAM",
        "ncep_nbm_conus": "NOAA NBM",
        "gem_regional": "GEM Regional",
        "gem_hrdps_continental": "GEM HRDPS",
        "icon_eu": "ICON-EU",
        "icon_d2": "ICON-D2",
        "meteofrance_arome_france_hd": "Météo-France AROME",
        "ukmo_uk_deterministic_2km": "UK Met Office 2 km",
        "knmi_harmonie_arome_europe": "KNMI HARMONIE",
        "dmi_harmonie_arome_europe": "DMI HARMONIE",
        "metno_nordic": "MET Norway Nordic",
        "meteoswiss_icon_ch1": "MeteoSwiss ICON-CH1",
        "meteoswiss_icon_ch2": "MeteoSwiss ICON-CH2",
        "italia_meteo_arpae_icon_2i": "ItaliaMeteo ICON-2I",
        "jma_msm": "JMA MSM",
        "kma_ldps": "KMA LDPS"
    ]

    /// One request each; regional ensembles fail outside their area and are simply left out.
    private static let ensembles = [
        "ecmwf_ifs025": "ECMWF Ensemble",
        "ecmwf_aifs025": "ECMWF AI Ensemble",
        "gfs_seamless": "GFS Ensemble",
        "icon_global": "ICON Ensemble",
        "icon_eu": "ICON-EU Ensemble",
        "icon_d2": "ICON-D2 Ensemble",
        "gem_global": "GEM Ensemble",
        "ukmo_global_ensemble_20km": "UK Met Office Ensemble",
        "ukmo_uk_ensemble_2km": "UK Met Office 2 km Ensemble",
        "meteoswiss_icon_ch1": "MeteoSwiss ICON-CH1 Ensemble",
        "meteoswiss_icon_ch2": "MeteoSwiss ICON-CH2 Ensemble"
    ]

    /// `days` up to 35 (the ensembles' limit). The standard models stop at the forecast API's 16-day limit.
    /// Apple Weather is only included when asked, because its data must be shown with Apple's attribution.
    func forecasts(for place: Place, days: Int = 7, includeAppleWeather: Bool = false) async throws -> Result {
        let standardDays = min(days, 16)
        async let conditions = try? fetchConditions(for: place, days: standardDays)

        // Each request is independent: a failing source (or one that doesn't cover the place) shouldn't sink the others.
        let batches = await withTaskGroup(of: Batch?.self) { group in
            group.addTask {
                guard let response = try? await fetch(host: "api.open-meteo.com", path: "/v1/forecast",
                                                      models: Self.models.keys.joined(separator: ","), place: place, days: standardDays)
                else { return nil }
                return Batch(response: response, source: .models)
            }
            for (model, name) in Self.ensembles {
                group.addTask {
                    guard let response = try? await fetch(host: "ensemble-api.open-meteo.com", path: "/v1/ensemble",
                                                          models: model, place: place, days: days)
                    else { return nil }
                    return Batch(response: response, source: .ensemble(name))
                }
            }
            group.addTask {
                guard let response = try? await nationalWeatherService(for: place) else { return nil }
                return Batch(response: response, source: .single(Self.nwsName))
            }
            group.addTask {
                guard let response = try? await metNorway(for: place) else { return nil }
                return Batch(response: response, source: .single(Self.metNorwayName))
            }
            if includeAppleWeather {
                group.addTask {
                    guard let response = try? await appleWeather(for: place) else { return nil }
                    return Batch(response: response, source: .single(Self.appleWeatherName))
                }
            }
            var batches: [Batch] = []
            for await batch in group {
                if let batch { batches.append(batch) }
            }
            return batches
        }

        // MET Norway and Apple don't report the place's time zone; Open-Meteo and NWS do.
        guard let zoned = batches.first(where: { !$0.response.timezone.isEmpty })?.response else {
            throw URLError(.cannotLoadFromNetwork)
        }
        let timeZone = TimeZone(identifier: zoned.timezone) ?? TimeZone(secondsFromGMT: zoned.utcOffsetSeconds) ?? .current
        // Keep every source to the same days the Open-Meteo requests cover (today plus `days - 1`).
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: days, to: today) ?? today
        let forecasts = batches.flatMap { batch in
            Self.summarize(batch.response, timeZone: timeZone, label: batch.source.label)
        }
        return await Result(
            forecasts: forecasts.filter { $0.date >= today && $0.date < end },
            conditions: conditions,
            timeZone: timeZone
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
                    snowfall: value("snowfall_sum"),
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

    // MARK: - Other providers

    static let nwsName = "National Weather Service"
    static let metNorwayName = "MET Norway"
    static let appleWeatherName = "Apple Weather"

    /// NWS and MET Norway both ask apps to identify themselves with contact details.
    private static let userAgent = "Wishcast/1.0 (https://jiroikedafeingold.github.io/wishcast/; apps@feingold5.com)"

    /// The US National Weather Service's gridded forecast (about 7 days, US only; elsewhere the
    /// lookup fails and the source is left out). Values cover intervals like "…/PT3H", spread here
    /// into hours: levels repeat, amounts are split evenly.
    private func nationalWeatherService(for place: Place) async throws -> ForecastResponse {
        var points = URLComponents(string: "https://api.weather.gov")!
        points.path = String(format: "/points/%.4f,%.4f", place.latitude, place.longitude)
        let point: NWSPoint = try await get(points, headers: ["User-Agent": Self.userAgent, "Accept": "application/geo+json"])
        guard let gridURL = URLComponents(string: point.properties.forecastGridData) else { throw URLError(.badURL) }
        let grid: NWSGrid = try await get(gridURL, headers: ["User-Agent": Self.userAgent, "Accept": "application/geo+json"])

        func hourly(_ layer: NWSGrid.Layer?, isAmount: Bool, scale: Double = 1) -> [Double: Double] {
            var result: [Double: Double] = [:]
            for entry in layer?.values ?? [] {
                guard let value = entry.value, let (start, hours) = Self.nwsInterval(entry.validTime) else { continue }
                for hour in 0..<hours {
                    result[start + Double(hour) * 3600] = value * scale / (isAmount ? Double(hours) : 1)
                }
            }
            return result
        }
        let properties = grid.properties
        let temperature = hourly(properties.temperature, isAmount: false)
        let series = [
            "temperature_2m": temperature,
            "precipitation": hourly(properties.quantitativePrecipitation, isAmount: true),
            "snowfall": hourly(properties.snowfallAmount, isAmount: true, scale: 0.1), // mm to cm
            "cloud_cover": hourly(properties.skyCover, isAmount: false),
            "wind_gusts_10m": hourly(properties.windGust, isAmount: false)
        ]
        let timeZone = TimeZone(identifier: point.properties.timeZone)
        return Self.hourlyResponse(times: temperature.keys.sorted(), series: series,
                                   timeZone: point.properties.timeZone,
                                   offset: timeZone?.secondsFromGMT() ?? 0)
    }

    /// "2026-10-27T09:00:00+00:00/PT3H" (or "/P1DT6H") to a start time and a length in hours.
    private static func nwsInterval(_ validTime: String) -> (Double, Int)? {
        let parts = validTime.split(separator: "/")
        guard parts.count == 2, let start = try? Date(String(parts[0]), strategy: .iso8601) else { return nil }
        var hours = 0
        var number = ""
        for character in parts[1] {
            if character.isNumber {
                number.append(character)
            } else {
                if character == "D" { hours += (Int(number) ?? 0) * 24 }
                if character == "H" { hours += Int(number) ?? 0 }
                number = ""
            }
        }
        return hours > 0 ? (start.timeIntervalSince1970, hours) : nil
    }

    /// MET Norway's Locationforecast. Only its hourly steps are used (about the first 2½ days); later
    /// steps are 6-hourly, too coarse for a fair high and low. It has no snowfall amount.
    private func metNorway(for place: Place) async throws -> ForecastResponse {
        var components = URLComponents(string: "https://api.met.no/weatherapi/locationforecast/2.0/complete")!
        // MET Norway asks for at most four decimals, so requests for one place share its cache.
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.4f", place.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.4f", place.longitude))
        ]
        // URLSession's cache honors MET Norway's Expires and Last-Modified headers, as its terms require.
        let forecast: METForecast = try await get(components, headers: ["User-Agent": Self.userAgent])
        var times: [Double] = []
        var series: [String: [Double: Double]] = [:]
        for step in forecast.properties.timeseries {
            guard let next = step.data.next1Hours, let time = try? Date(step.time, strategy: .iso8601) else { break }
            let key = time.timeIntervalSince1970
            let details = step.data.instant.details
            times.append(key)
            series["temperature_2m", default: [:]][key] = details.airTemperature
            series["precipitation", default: [:]][key] = next.details.precipitationAmount
            series["cloud_cover", default: [:]][key] = details.cloudAreaFraction
            series["wind_gusts_10m", default: [:]][key] = details.windSpeedOfGust.map { $0 * 3.6 } // m/s to km/h
        }
        return Self.hourlyResponse(times: times, series: series, timeZone: "", offset: 0)
    }

    /// Apple Weather's hourly forecast, from yesterday (so today is complete) through about 10 days out.
    private func appleWeather(for place: Place) async throws -> ForecastResponse {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let hours = try await WeatherService.shared.weather(
            for: location, including: .hourly(startDate: .now.addingTimeInterval(-86_400), endDate: .now.addingTimeInterval(10 * 86_400)))
        var times: [Double] = []
        var series: [String: [Double: Double]] = [:]
        for hour in hours {
            let key = hour.date.timeIntervalSince1970
            times.append(key)
            series["temperature_2m", default: [:]][key] = hour.temperature.converted(to: .celsius).value
            series["precipitation", default: [:]][key] = hour.precipitationAmount.converted(to: .millimeters).value
            series["snowfall", default: [:]][key] = hour.snowfallAmount.converted(to: .centimeters).value
            series["cloud_cover", default: [:]][key] = hour.cloudCover * 100
            series["wind_gusts_10m", default: [:]][key] = hour.wind.gust?.converted(to: .kilometersPerHour).value
        }
        return Self.hourlyResponse(times: times, series: series, timeZone: "", offset: 0)
    }

    /// Lays out one source's hourly values the way Open-Meteo returns them, so they're summarized alike.
    private static func hourlyResponse(times: [Double], series: [String: [Double: Double]], timeZone: String, offset: Int) -> ForecastResponse {
        var hourly: [String: [Double?]] = ["time": times]
        for (variable, values) in series {
            hourly[variable] = times.map { values[$0] }
        }
        return ForecastResponse(utcOffsetSeconds: offset, timezone: timeZone, hourly: hourly)
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

    private func get<T: Decodable>(_ components: URLComponents, headers: [String: String] = [:]) async throws -> T {
        guard let url = components.url else { throw URLError(.badURL) }
        #if DEBUG
        // Screenshot runs relaunch the app dozens of times; reuse each download so every shot and
        // language shows the same forecasts and Open-Meteo's free rate limit isn't exhausted.
        if let cached = Self.screenshotCache(for: url), let data = try? Data(contentsOf: cached) {
            return try JSONDecoder().decode(T.self, from: data)
        }
        #endif
        var request = URLRequest(url: url)
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        let (data, response) = try await URLSession.shared.data(for: request)
        // MET Norway answers 203 when a newer API version exists; the data is still valid.
        guard [200, 203].contains((response as? HTTPURLResponse)?.statusCode) else { throw URLError(.badServerResponse) }
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
    private static func summarize(_ response: ForecastResponse, timeZone: TimeZone, label: (String) -> String?) -> [DayForecast] {
        guard let times = response.hourly["time"]?.compactMap({ $0 }) else { return [] }

        var sources: [String: [String: [Double?]]] = [:]
        for (key, values) in response.hourly {
            guard let variable = variables.first(where: { key == $0 || key.hasPrefix($0 + "_") }) else { continue }
            sources[String(key.dropFirst(variable.count)), default: [:]][variable] = values
        }

        // Each hour's real UTC offset, so days stay midnight-to-midnight across daylight-saving changes.
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
                    snowfall: value("snowfall", index),
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
                snowfall: series["snowfall"] == nil ? nil : values("snowfall", hours).reduce(0, +),
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

private struct NWSPoint: Decodable {
    struct Properties: Decodable {
        let forecastGridData: String
        let timeZone: String
    }
    let properties: Properties
}

private struct NWSGrid: Decodable {
    struct Layer: Decodable {
        struct Entry: Decodable {
            let validTime: String
            let value: Double?
        }
        let values: [Entry]
    }
    /// Units: °C, mm, mm, %, km/h.
    struct Properties: Decodable {
        let temperature: Layer?
        let quantitativePrecipitation: Layer?
        let snowfallAmount: Layer?
        let skyCover: Layer?
        let windGust: Layer?
    }
    let properties: Properties
}

private struct METForecast: Decodable {
    struct Step: Decodable {
        struct Data: Decodable {
            struct Instant: Decodable {
                struct Details: Decodable {
                    let airTemperature: Double?
                    let cloudAreaFraction: Double?
                    let windSpeedOfGust: Double?

                    enum CodingKeys: String, CodingKey {
                        case airTemperature = "air_temperature"
                        case cloudAreaFraction = "cloud_area_fraction"
                        case windSpeedOfGust = "wind_speed_of_gust"
                    }
                }
                let details: Details
            }
            struct NextHour: Decodable {
                struct Details: Decodable {
                    let precipitationAmount: Double?

                    enum CodingKeys: String, CodingKey {
                        case precipitationAmount = "precipitation_amount"
                    }
                }
                let details: Details
            }
            let instant: Instant
            let next1Hours: NextHour?

            enum CodingKeys: String, CodingKey {
                case instant
                case next1Hours = "next_1_hours"
            }
        }
        let time: String
        let data: Data
    }
    struct Properties: Decodable {
        let timeseries: [Step]
    }
    let properties: Properties
}
