import SwiftUI

/// The launch artwork, shown for a moment before the app. On tall screens it fills the screen; on
/// wide ones (iPad, Mac, the open iPhone Duo) it's shown whole over a blurred copy of itself, so the
/// title at the top of the art is never cropped.
struct SplashView: View {
    var body: some View {
        GeometryReader { proxy in
            let imageAspect = 768.0 / 1376.0
            let isTall = proxy.size.width / max(proxy.size.height, 1) <= imageAspect * 1.15
            ZStack {
                Image("Splash")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .blur(radius: isTall ? 0 : 40)
                if !isTall {
                    Image("Splash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("Wishcast")
    }
}

#Preview {
    SplashView()
}
