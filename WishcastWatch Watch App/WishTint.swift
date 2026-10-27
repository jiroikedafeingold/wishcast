import SwiftUI

/// Each wish's color, matching the iPhone app. Keep in sync with `Wish.tint` in WishStyle.swift.
func wishTint(_ wish: String) -> Color {
    switch wish {
    case "snow": .cyan
    case "sunny": .orange
    case "wild": .purple
    case "coolEvenings": .indigo
    default: .green
    }
}
