import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Wishcast" }
    static var description: IntentDescription { "Best-case weather for your wish, mixed from many weather models and their ensemble members." }

    @Parameter(title: "Wishing For", default: .app)
    var wish: WidgetWish

    /// A favorite or saved place for this widget; empty follows the place shown in the app.
    @Parameter(title: "Place")
    var place: PlaceEntity?
}

/// A favorite or saved place, so each widget can show a different one.
struct PlaceEntity: AppEntity {
    let id: String
    let place: Place

    init(_ place: Place) {
        id = place.id
        self.place = place
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Place" }
    static var defaultQuery = PlaceQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(place.name)", subtitle: place.detail.map { "\($0)" })
    }
}

struct PlaceQuery: EntityQuery {
    /// Favorites first, in the user's order, then the other saved places.
    private var places: [Place] {
        let favorites = SharedSettings.favorites
        return favorites + SharedSettings.savedPlaces.filter { saved in !favorites.contains { $0.id == saved.id } }
    }

    func entities(for identifiers: [String]) async throws -> [PlaceEntity] {
        places.filter { identifiers.contains($0.id) }.map(PlaceEntity.init)
    }

    func suggestedEntities() async throws -> [PlaceEntity] {
        places.map(PlaceEntity.init)
    }
}

/// The widget's wish choice; "Same as App" follows whatever is picked in Wishcast.
enum WidgetWish: String, AppEnum {
    case app, sunny, snow, rainy, wild, coolEvenings, pleasant

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Wish" }

    static var caseDisplayRepresentations: [WidgetWish: DisplayRepresentation] {
        [
            .app: "Same as App",
            .sunny: "Sunny",
            .snow: "Snow",
            .rainy: "Rainy",
            .wild: "Wild Weather",
            .coolEvenings: "Cool Evenings",
            .pleasant: "Nice & Pleasant"
        ]
    }

    var resolved: Wish {
        Wish(rawValue: rawValue) ?? SharedSettings.wish
    }
}
