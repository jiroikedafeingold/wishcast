import SwiftUI

/// A plain explanation of exactly what Wishcast does. The per-wish rules are generated from
/// `Wish.choice(for:preferences:)` and `Wish.matchDescription(preferences:)`, the same code that
/// builds the Wishcast, so this screen can't drift out of date.
struct HowItWorksView: View {
    @State var wish: Wish
    let preferences: Preferences
    /// Forecasts actually loaded for the current place, or 0 if none yet.
    let sourceCount: Int
    let placeName: String?

    var body: some View {
        Form {
            Section("In Short") {
                Text("Wishcast shows an optimistic forecast. For each day it looks at every forecast it downloaded, and for each value (high, low, rain, and so on) it picks the one that best fits your wish. Different values can come from different forecasts, so a day in Wishcast may not match any single forecast. It is a best case, not a prediction of what will happen.")
            }

            Section("Where the Forecasts Come From") {
                Text("Most data comes from Open-Meteo.com, which republishes forecasts from national and international weather services. Wishcast also downloads forecasts directly from the US National Weather Service, MET Norway and Apple Weather.")
                LabeledContent("Weather models (\(OpenMeteoClient.modelNames.count))",
                               value: OpenMeteoClient.modelNames.formatted(.list(type: .and)))
                LabeledContent("Ensembles (\(OpenMeteoClient.ensembleNames.count))",
                               value: OpenMeteoClient.ensembleNames.formatted(.list(type: .and)))
                LabeledContent("Direct from providers (\(OpenMeteoClient.providerNames.count))",
                               value: OpenMeteoClient.providerNames.formatted(.list(type: .and)))
                Text("Regional models and ensembles (such as NOAA HRRR, ICON-D2 or Météo-France AROME) only cover their own area, and the National Weather Service only covers the US, so each place gets the ones that reach it. Apple Weather isn't used in the widget.")
                Text("An ensemble runs one model many times from slightly different starting conditions. Wishcast counts each run (\"member\", including the unchanged \"control\" run) as one forecast. Members of the same ensemble are variations of one model, so they are not independent opinions.")
                if sourceCount > 0, let placeName {
                    Text("For \(placeName), \(sourceCount) forecasts were downloaded. Some models don't reach the last day or two, so later days can have fewer.")
                }
            }

            Section("How Far Ahead") {
                Text("The main list shows 7 days. Use the calendar button (“Pick a Future Date”) to see any day up to about six months out.")
                LabeledContent("First 7 days", value: String(localized: "Best case. More than 200 forecasts a day, more where regional models reach."))
                LabeledContent("Days 8–14", value: String(localized: "Long shot. Fewer models reach this far, and forecasts lose much of their skill after a week."))
                LabeledContent("Day 15 and later", value: String(localized: "Wild guess. Forecasts for a specific day this far out have very little skill; they're better at broad trends."))
                Text("Days after the first week also include \(OpenMeteoClient.longRangeName), ECMWF's 51-member long-range ensemble (EC46, then SEAS5). It only provides daily values, so beyond about 35 days there's no hourly forecast or evening temperature, and cloud cover is a 24-hour average. The GFS and GEM ensembles reach about 35 days; the other models stop sooner.")
            }

            Section {
                Picker("Wish", selection: $wish) {
                    ForEach(Wish.allCases) { wish in
                        Text(wish.title).tag(wish)
                    }
                }
                ForEach(Field.allCases) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.title)
                            .font(.headline)
                        Text(wish.choice(for: field, preferences: preferences).describe(field))
                        Text(field.definition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("How Each Day Is Built")
            } footer: {
                Text("“Typical” values are the median of all forecasts, for things the wish doesn't care about. The day's icon is drawn from the picked values, so it shows the best case too. Because values come from different forecasts they can disagree (for example, an evening warmer than the high). The one exception: the low is never allowed to be warmer than the high.")
            }

            Section("What the Counts Mean") {
                Text("“H: 3 of 220 · L: 12 of 220” under a day means 3 of that day’s 220 forecasts show the same high as displayed (rounded to the degree shown), and 12 show the same low. A small number means the value is an outlier. The tiles on a day’s screen count the same way (“12 of 220 forecasts show this”).")
                Text("A day’s Reality Check also counts single, unmixed forecasts that fully deliver your wish. For \(Text(wish.title)), that means: \(wish.matchDescription(preferences: preferences))")
                Text("These are counts of forecasts, not probabilities. Ensemble members aren't independent, so they shouldn't be read as a percent chance.")
                Text("Some sources don't report snowfall, gusts or CAPE. For the Reality Check those are treated as none, and missing cloud cover is treated as cloudy. When picking and counting values, forecasts missing a value are left out for that value.")
            }

            Section("Other Details") {
                LabeledContent("Hourly forecast", value: String(localized: "Shown from one real forecast: the source of one of the picked values, normally the wish's main one. The other values on that day may come from different forecasts."))
                LabeledContent("Right Now", value: String(localized: "Open-Meteo's modeled current conditions, not a weather station reading."))
                LabeledContent("Sunrise, sunset, UV, chance of precipitation", value: String(localized: "From Open-Meteo's single best-match forecast. Not mixed."))
                LabeledContent("Official alerts and the next hour", value: String(localized: "Weather alerts from national weather services, and the next-hour precipitation forecast, come from Apple Weather where it has them. They're shown as issued, never mixed or made more optimistic."))
                LabeledContent("Days", value: String(localized: "Midnight to midnight in the location's local time. A forecast with fewer than 20 hours of data for a day is left out of that day."))
                LabeledContent("Updates", value: String(localized: "The app downloads forecasts when it starts, when you pull to refresh, and when you change location. The widget asks for an update about every three hours; the system decides exactly when."))
            }
            Section {
                credit("Open-Meteo.com", "https://open-meteo.com/",
                       "Most weather data and the location search. Data licensed under CC BY 4.0. Wishcast changes it: values from different forecasts are mixed, and daily totals and averages are computed from hourly data.")
                credit("ECMWF", "https://www.ecmwf.int/",
                       "European Centre for Medium-Range Weather Forecasts: the ECMWF, ECMWF AI, ECMWF Ensemble, ECMWF AI Ensemble and ECMWF Long-Range (EC46 and SEAS5) forecasts (CC BY).")
                credit("NOAA NCEP", "https://www.ncei.noaa.gov/products/weather-climate-models/global-forecast",
                       "U.S. National Centers for Environmental Prediction: the GFS, GFS Ensemble, HRRR, NAM and NBM forecasts.")
                credit("National Weather Service", "https://www.weather.gov/",
                       "The US National Weather Service's gridded forecast, downloaded directly from api.weather.gov (US places only; public domain).")
                credit("Deutscher Wetterdienst (DWD)", "https://www.dwd.de/EN/Home/home_node.html",
                       "Germany's national weather service: the ICON, ICON-EU and ICON-D2 forecasts and their ensembles (CC BY).")
                credit("Canadian Meteorological Centre", "https://weather.gc.ca/",
                       "Environment and Climate Change Canada: the GEM, GEM Regional, GEM HRDPS and GEM Ensemble forecasts.")
                credit("Météo-France", "https://meteofrance.com/",
                       "France's national weather service: the ARPEGE and AROME forecasts.")
                credit("Japan Meteorological Agency (JMA)", "https://www.jma.go.jp/jma/indexe.html",
                       "The JMA and JMA MSM forecasts.")
                credit("UK Met Office", "https://www.metoffice.gov.uk/services/data",
                       "The UK Met Office and UK Met Office 2 km forecasts and their ensembles (CC BY-SA).")
                credit("China Meteorological Administration (CMA)", "https://www.cma.gov.cn/en/",
                       "The CMA forecast (CC BY).")
                credit("MET Norway", "https://www.met.no/en",
                       "The Norwegian Meteorological Institute: the MET Norway Nordic forecast via Open-Meteo, and its Locationforecast downloaded directly from api.met.no (CC BY 4.0).")
                credit("KNMI", "https://www.knmi.nl/",
                       "The Royal Netherlands Meteorological Institute: the KNMI HARMONIE forecast.")
                credit("DMI", "https://www.dmi.dk/",
                       "The Danish Meteorological Institute: the DMI HARMONIE forecast.")
                credit("MeteoSwiss", "https://www.meteoswiss.admin.ch/",
                       "Switzerland's national weather service: the ICON-CH1 and ICON-CH2 forecasts and their ensembles.")
                credit("ItaliaMeteo", "https://www.agenziaitaliameteo.it/",
                       "Italy's national weather agency, with Arpae: the ICON-2I forecast.")
                credit("Korea Meteorological Administration (KMA)", "https://www.kma.go.kr/eng/",
                       "The KMA LDPS forecast.")
                credit("Apple Weather", "https://developer.apple.com/weatherkit/data-source-attribution/",
                       "Apple's hourly forecast, via WeatherKit. Its data sources are listed on Apple's attribution page.")
                credit("GeoNames", "https://www.geonames.org/",
                       "The place names used in location search, via Open-Meteo (CC BY).")
            } header: {
                Text("Credits")
            } footer: {
                Text("Licences for data via Open-Meteo as listed on its licence page. Wishcast isn't affiliated with or endorsed by any of these organizations.")
            }

            Section("References") {
                reference("Open-Meteo licence and data sources", "https://open-meteo.com/en/licence")
                reference("Open-Meteo forecast API documentation", "https://open-meteo.com/en/docs")
                reference("Open-Meteo ensemble API documentation", "https://open-meteo.com/en/docs/ensemble-api")
                reference("Open-Meteo long-range (seasonal) API documentation", "https://open-meteo.com/en/docs/seasonal-forecast-api")
                reference("National Weather Service API documentation", "https://www.weather.gov/documentation/services-web-api")
                reference("MET Norway Locationforecast documentation", "https://api.met.no/weatherapi/locationforecast/2.0/documentation")
                reference("Ensemble forecasting (Wikipedia)", "https://en.wikipedia.org/wiki/Ensemble_forecasting")
                reference("Creative Commons Attribution 4.0 licence", "https://creativecommons.org/licenses/by/4.0/")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("How Wishcast Works")
    }

    @ViewBuilder
    private func credit(_ name: String, _ urlString: String, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = URL(string: urlString) {
                Link(name, destination: url)
                    .font(.headline)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func reference(_ title: LocalizedStringKey, _ urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Link(title, destination: url)
        }
    }
}

#Preview {
    NavigationStack {
        HowItWorksView(wish: .pleasant, preferences: Preferences(), sourceCount: 170, placeName: "Portland")
    }
}
