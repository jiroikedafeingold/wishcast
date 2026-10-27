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

1. In Xcode, open the **Report navigator** (⌘9), click the **Cloud** tab, then **Get Started**.
   (After the first build, **Integrate ▸ Create Workflow / Manage Workflows** is also available.)
2. Pick the **Wishcast** product, **Grant Access**, connect **GitHub** and authorize Apple's GitHub app
   for `jiroikedafeingold/wishcast`.
3. Review the default workflow (**Details** to add the TestFlight post-action) and **Start First Build**.
4. Commit and push the files Xcode adds under `Wishcast.xcodeproj/xcshareddata/` (the Xcode Cloud
   `manifest.json`, and the shared scheme if it creates one).

## 3. Recommended workflow

- **Start condition**: Branch Changes on `main`.
- **Environment**: latest released Xcode.
- **Actions** (current "Default" workflow): **Archive – iOS** (scheme *Wishcast*, distribution
  *App Store eligible*, so builds appear in TestFlight and can be attached to a version) and
  **Build – macOS**. There is no visionOS action: the app target doesn't support visionOS.
- **Post-action**: **TestFlight Internal Testing** → add yourself as a tester.

## 4. Each release

1. Bump `MARKETING_VERSION` (patch by default); push to `main` → Xcode Cloud archives to TestFlight.
2. Advance each locale's `subtitle.txt` to the next entry in `fastlane/subtitle_rotation.json`.
3. `source ~/Projects/AppStoreConnect/credentials.env` then
   `LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 fastlane upload_store version:X.Y.Z`.
4. Attach the build to the version in App Store Connect and submit for review.
