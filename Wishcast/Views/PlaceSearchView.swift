import SwiftUI

struct PlaceSearchView: View {
    /// Starred places, in order.
    let favorites: [Place]
    /// Saved places that aren't starred.
    let otherPlaces: [Place]
    let onSelect: (Place) -> Void
    let onUseCurrentLocation: () -> Void
    let onToggleFavorite: (Place) -> Void
    let onMoveFavorites: (IndexSet, Int) -> Void
    let onDelete: ([Place]) -> Void

    @State private var viewModel = PlaceSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.query.isEmpty {
                    Section {
                        Button {
                            onUseCurrentLocation()
                            dismiss()
                        } label: {
                            Label("Use Current Location", systemImage: "location.fill")
                        }
                    }
                    if !favorites.isEmpty {
                        Section {
                            ForEach(favorites) { place in
                                placeButton(place, isFavorite: true)
                            }
                            .onMove(perform: onMoveFavorites)
                            .onDelete { offsets in onDelete(offsets.map { favorites[$0] }) }
                        } header: {
                            Text("Favorites")
                        } footer: {
                            Text("Swipe left or right on the main screen to move between favorites. Drag to reorder.")
                        }
                    }
                    if !otherPlaces.isEmpty {
                        Section {
                            ForEach(otherPlaces) { place in
                                placeButton(place, isFavorite: false)
                            }
                            .onDelete { offsets in onDelete(offsets.map { otherPlaces[$0] }) }
                        } header: {
                            Text("Saved Places")
                        } footer: {
                            if favorites.isEmpty {
                                Text("Tap the star to make a place a favorite.")
                            }
                        }
                    }
                } else {
                    ForEach(viewModel.results) { place in
                        placeButton(place, isFavorite: favorites.contains { $0.id == place.id })
                    }
                }
            }
            .searchable(text: $viewModel.query, prompt: "Search for a city")
            .task(id: viewModel.query) { await viewModel.search() }
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                #if os(iOS)
                if favorites.count > 1 && viewModel.query.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
                #endif
            }
        }
        .presentationSizing(.form)
    }

    private func placeButton(_ place: Place, isFavorite: Bool) -> some View {
        HStack {
            Button {
                onSelect(place)
                dismiss()
            } label: {
                VStack(alignment: .leading) {
                    Text(place.name)
                        .foregroundStyle(.primary)
                    if let detail = place.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .tint(.primary)
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                   systemImage: isFavorite ? "star.fill" : "star") {
                onToggleFavorite(place)
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(isFavorite ? .yellow : .secondary)
        }
        // Each button handles its own tap, rather than the whole row acting as one.
        .buttonStyle(.borderless)
        // Custom swipe actions replace the list's built-in delete, so it's added back here.
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete([place])
            }
        }
        .swipeActions(edge: .leading) {
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                   systemImage: isFavorite ? "star.slash" : "star") {
                onToggleFavorite(place)
            }
            .tint(.yellow)
        }
    }
}
