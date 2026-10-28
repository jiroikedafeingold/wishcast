# Wishcast

*You aren’t lying to yourself, you are just being optimistic.*

Wishcast is a weather app for iPhone, iPad and Mac that shows the **best case** for the weather you’re hoping for. For each day of the week ahead it downloads more than 200 forecasts: up to 26 global and regional weather models and every member of up to 11 ensembles from Open-Meteo, plus the US National Weather Service, MET Norway and Apple Weather directly and, for each value (high, low, rain, snow, clouds, wind), picks the one that best fits your wish: Nice & Pleasant, Sunny, Snow, Rainy, Wild Weather or Cool Evenings. Values can come from different forecasts, so a Wishcast day is a wish, not a prediction, and the app says so.

## Features

- Current conditions, a 7-day best-case outlook, hourly forecasts, sunrise/sunset, UV and chance of precipitation
- Pick any date up to about six months ahead (past a week it’s a long shot, past two weeks a wild guess)
- Your own perfect high, evening and low temperatures
- Per-value transparency: where each value came from and how many forecasts show it
- Saved places, city search and current location
- Home Screen widgets, plus Lock Screen widgets on iPhone
- “How Wishcast Works” explains every rule, with credits and references

## Project layout

| Path | Contents |
|---|---|
| `Wishcast/Models/Forecast.swift` | Data model, the per-wish rules (`Wish.choice(for:)`), formatting, shared settings |
| `Wishcast/Services/OpenMeteoClient.swift` | Downloads and summarizes forecasts (Open-Meteo models, ensembles and long-range; NWS, MET Norway, WeatherKit) |
| `Wishcast/ViewModels/` | One view model per screen |
| `Wishcast/Views/` | SwiftUI views |
| `WishcastWidget/` | WidgetKit extension (shares `Forecast.swift`, `OpenMeteoClient.swift`, `WishStyle.swift`) |
| `docs/` | Privacy & support page (GitHub Pages) |
| `fastlane/` | App Store metadata and upload lane |
| `ci_scripts/` | Xcode Cloud build scripts |

Requires Xcode 27 and iOS/iPadOS/macOS 27. No third-party dependencies.

## Data and credits

Weather data by [Open-Meteo.com](https://open-meteo.com/) under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), [MET Norway](https://www.met.no/en) under CC BY 4.0, the [US National Weather Service](https://www.weather.gov/) and Apple Weather, from forecasts published by ECMWF, NOAA, Deutscher Wetterdienst, Environment and Climate Change Canada, Météo-France, the Japan Meteorological Agency, the UK Met Office, the China Meteorological Administration, MET Norway, KNMI, DMI, MeteoSwiss, ItaliaMeteo and the Korea Meteorological Administration. Place names from GeoNames via Open-Meteo. Wishcast isn’t affiliated with or endorsed by any of them.

## Contact

apps@feingold5.com
