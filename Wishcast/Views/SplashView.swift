import SwiftUI

/// The launch artwork with the app name and a tag line set in its sky, shown for a moment before
/// the app. On tall screens the art fills the screen; on wide ones (iPad, Mac, the open iPhone Duo)
/// it's shown whole over a blurred copy of itself, so nothing is cropped.
struct SplashView: View {
    /// One of the App Store subtitle tag lines, rotated each launch.
    let tagline: LocalizedStringResource

    /// The three tag lines, in rotation order (the same as the App Store subtitles).
    static let taglines: [LocalizedStringResource] = [
        "Not lying. Just optimistic.",
        "The weather you're hoping for",
        "Best-case weather, every day"
    ]

    private let imageAspect = 768.0 / 1376.0

    var body: some View {
        GeometryReader { proxy in
            let isTall = proxy.size.width / max(proxy.size.height, 1) <= imageAspect * 1.15
            ZStack {
                Image("Splash")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .blur(radius: isTall ? 0 : 40)
                    .overlay(alignment: .top) {
                        if isTall { title(width: proxy.size.width, height: proxy.size.height) }
                    }
                if !isTall {
                    // The art at its own shape, centered, with the title placed on it.
                    let height = proxy.size.height
                    let width = height * imageAspect
                    Image("Splash")
                        .resizable()
                        .frame(width: width, height: height)
                        .overlay(alignment: .top) { title(width: width, height: height) }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel(Text("Wishcast. \(Text(tagline))"))
    }

    /// Gold serif lettering in the open sky above the sun.
    private func title(width: CGFloat, height: CGFloat) -> some View {
        let gold = Color(red: 0.93, green: 0.80, blue: 0.52)
        return VStack(spacing: height * 0.008) {
            Text(verbatim: "Wishcast")
                .font(.system(size: min(width * 0.19, 96), weight: .semibold, design: .serif))
            Text(tagline)
                .font(.system(size: min(width * 0.062, 30), weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(gold)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
        .shadow(color: .black.opacity(0.25), radius: 12)
        .padding(.horizontal, width * 0.06)
        .lineLimit(2)
        .minimumScaleFactor(0.6)
        .padding(.top, height * 0.12)
    }
}

#Preview {
    SplashView(tagline: SplashView.taglines[0])
}
