import SwiftUI

struct PlaceSearchView: View {
    let savedPlaces: [Place]
    let onSelect: (Place) -> Void
    let onUseCurrentLocation: () -> Void
    let onDelete: (IndexSet) -> Void

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
                    if !savedPlaces.isEmpty {
                        Section("Saved Places") {
                            ForEach(savedPlaces) { place in
                                placeButton(place)
                            }
                            .onDelete(perform: onDelete)
                        }
                    }
                } else {
                    ForEach(viewModel.results) { place in
                        placeButton(place)
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
            }
        }
        .presentationSizing(.form)
    }

    private func placeButton(_ place: Place) -> some View {
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
        }
        .tint(.primary)
    }
}
