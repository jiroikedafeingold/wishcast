# App Store submission kit — Wishcast

The source of truth for every field is `fastlane/metadata/` (11 locales: en-US, de-DE, es-ES, fr-FR, it,
ja, ko, pt-BR, ru, zh-Hans, zh-Hant). Upload with:

```
source ~/Projects/AppStoreConnect/credentials.env
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 fastlane upload_store version:1.0.1
```

## Fields and limits

| Field | Limit | File |
|---|---|---|
| App name | 30 | `<locale>/name.txt` — “Wishcast” in every locale |
| Subtitle | 30 | `<locale>/subtitle.txt` — rotates per release, see `fastlane/subtitle_rotation.json` |
| Promotional text | 170 | `<locale>/promotional_text.txt` — editable any time, no review |
| Keywords | 100 | `<locale>/keywords.txt` — comma-separated, no spaces after commas |
| Description | 4000 | `<locale>/description.txt` |
| What’s New | 4000 | `<locale>/release_notes.txt` — not used for the first version; no emoji |
| Privacy / support / marketing URL | — | `https://jiroikedafeingold.github.io/wishcast/` |
| Copyright | — | `copyright.txt` — © 2026 Jiro Feingold |
| Categories | — | `primary_category.txt` WEATHER, `secondary_category.txt` ENTERTAINMENT |
| Review contact & notes | — | `review_information/` (add a phone number in App Store Connect) |

## English listing

**Subtitle:** Not lying. Just optimistic.

**Promotional text:** Tired of checking app after app for the forecast you want? Wishcast finds the best
case for your wish across more than 200 forecasts, and shows how many of them agree.

**Keywords:** weather,forecast,optimistic,best case,snow,sunny,storm,ensemble,widget,hourly,temperature,rain

**Description:** see `fastlane/metadata/en-US/description.txt`.

## Set in App Store Connect (not via fastlane)

- **App Privacy:** declare **Location → Precise Location**: purpose *App Functionality*, **not linked** to the
  user, **not used for tracking**. Wishcast itself has no analytics, ads, accounts or tracking and the
  developer receives nothing, but “Use Current Location” sends exact coordinates (and every forecast request
  sends the place’s coordinates) to Open-Meteo, the US National Weather Service, MET Norway (which logs IP
  and coordinates) and Apple WeatherKit, third parties that see the device’s IP address. Apple counts
  data as collected unless it’s only processed in real time and not retained, which Wishcast can’t promise
  for them, so declaring it is the honest choice. Nothing else is collected.
- **Age rating:** answer “None” to every content question (no user content, no web browsing, no ads).
- **Pricing:** Free, all territories. (Open-Meteo’s free API is for non-commercial use: no ads, no
  subscriptions.)
- **Export compliance:** already declared in the build (`ITSAppUsesNonExemptEncryption = NO`).

## Screenshots

`fastlane/screenshots/<locale>/` — `iphone69_N-*.png` (6.9″ iPhone, 1320 × 2868) and `ipad13_N-*.png`
(13″ iPad, 2064 × 2752).
