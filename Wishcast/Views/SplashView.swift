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
        .accessibilityLabel(Text("Sunnyside. \(Text(tagline))"))
    }

    /// Gold serif lettering in the open sky above the sun.
    private func title(width: CGFloat, height: CGFloat) -> some View {
        // Bright gold lettering with a dark outline and deep shadow, over a soft dark wash, so it
        // stands out from the bright sky.
        let gold = LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.7), Color(red: 0.98, green: 0.78, blue: 0.38)],
                                  startPoint: .top, endPoint: .bottom)
        let outline = Color(red: 0.22, green: 0.15, blue: 0.05).opacity(0.75)
        return VStack(spacing: height * 0.01) {
            Text(verbatim: "Sunnyside")
                .font(.system(size: min(width * 0.2, 104), weight: .bold, design: .serif))
            Text(tagline)
                .font(.system(size: min(width * 0.068, 32), weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(gold)
        // A thin outline made from four tight shadows, then the depth shadows.
        .shadow(color: outline, radius: 0, x: 1, y: 1)
        .shadow(color: outline, radius: 0, x: -1, y: -1)
        .shadow(color: outline, radius: 0, x: 1, y: -1)
        .shadow(color: outline, radius: 0, x: -1, y: 1)
        .shadow(color: .black.opacity(0.55), radius: 4, y: 3)
        .shadow(color: .black.opacity(0.35), radius: 16)
        .padding(.horizontal, width * 0.06)
        .lineLimit(2)
        .minimumScaleFactor(0.6)
        .padding(.vertical, height * 0.03)
        .frame(maxWidth: .infinity)
        .background {
            // Larger than the text's box so it fades out softly with no visible edge.
            Ellipse()
                .fill(.black.opacity(0.32))
                .frame(width: width * 1.05, height: height * 0.22)
                .blur(radius: width * 0.09)
        }
        .padding(.top, height * 0.1)
    }
}

#Preview {
    SplashView(tagline: SplashView.taglines[0])
}
