# Xcode Cloud setup — Wishcast

Xcode Cloud is Apple's CI/CD. Turning it on is a one-time flow in **Xcode + App Store Connect** (it
can't be scripted). The repo is prepared; this lists what's done and the steps you finish in the GUI.

## ✅ Already prepared in the repo

- **Bundle identifiers** — app `com.jirofeingold.Wishcast`, widget `com.jirofeingold.Wishcast.WishcastWidget`.
- **Development team** — `TJ8LYQ4D36`, automatic signing (Xcode Cloud manages distribution signing).
- **Entitlements** — App Group `group.com.jirofeingold.wishcast` on both targets (shared settings for the
  widget). Automatic signing provisions it from the App ID capability.
- **Export compliance** — `ITSAppUsesNonExemptEncryption = NO` (the app only uses standard HTTPS), so
  builds don't stop for the encryption question.
- **Versioning** — `VERSIONING_SYSTEM = apple-generic`; marketing version in `MARKETING_VERSION`.
- **`ci_scripts/ci_pre_xcodebuild.sh`** — stamps each Xcode Cloud build with `CI_BUILD_NUMBER`, so every
  TestFlight upload has a unique, increasing build number. The repo itself is never modified.
- No third-party dependencies.
- Repo: `https://github.com/jiroikedafeingold/wishcast` (public).

## 0. Share the scheme (required, ~10 s)

Xcode Cloud only sees **shared** schemes. In Xcode: **Product ▸ Scheme ▸ Manage Schemes…**, tick
**Shared** for **Wishcast**, then commit the new `Wishcast.xcodeproj/xcshareddata/` folder.

## 1. App Store Connect app record

Create the app in **App Store Connect ▸ Apps ▸ + ▸ New App** (Apple's API can't create app records):
platform iOS (add macOS later if wanted), name **Wishcast**, primary language English (U.S.), bundle ID
`com.jirofeingold.Wishcast`, SKU `wishcast`.

## 2. Turn on Xcode Cloud (~5 min)

1. In Xcode: **Product ▸ Xcode Cloud ▸ Create Workflow…**
2. Pick the **Wishcast** app, **Grant Access**, connect **GitHub** and authorize Apple's GitHub app for
   `jiroikedafeingold/wishcast`.
3. Review the default workflow and **Start Build**.

## 3. Recommended workflow

- **Start condition**: Branch Changes on `main`.
- **Environment**: latest released Xcode.
- **Actions**: **Archive** (scheme *Wishcast*, platform iOS, distribution **TestFlight (Internal)**).
- **Post-action**: **TestFlight Internal Testing** → add yourself as a tester.

## 4. Each release

1. Bump `MARKETING_VERSION` (patch by default); push to `main` → Xcode Cloud archives to TestFlight.
2. Advance the App Store subtitle to the next line of `fastlane/subtitle_rotation.txt`.
3. `source ~/Projects/AppStoreConnect/credentials.env` then
   `LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 fastlane upload_store version:X.Y.Z`.
4. Attach the build to the version in App Store Connect and submit for review.
