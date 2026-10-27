import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Wishcast" }
    static var description: IntentDescription { "Best-case weather for your wish, mixed from global weather models and their ensemble members." }

    @Parameter(title: "Wishing For", default: .app)
    var wish: WidgetWish
}

/// The widget's wish choice; "Same as App" follows whatever is picked in Wishcast.
enum WidgetWish: String, AppEnum {
    case app, snow, sunny, wild, coolEvenings, pleasant

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Wish" }

    static var caseDisplayRepresentations: [WidgetWish: DisplayRepresentation] {
        [
            .app: "Same as App",
            .snow: "Snow",
            .sunny: "Sunny",
            .wild: "Wild Weather",
            .coolEvenings: "Cool Evenings",
            .pleasant: "Nice & Pleasant"
        ]
    }

    var resolved: Wish {
        Wish(rawValue: rawValue) ?? SharedSettings.wish
    }
}
