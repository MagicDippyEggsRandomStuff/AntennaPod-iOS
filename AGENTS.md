# AntennaPod iOS — Agent Guide

This repository is the native iOS port of AntennaPod. The Android sources live
on the `android-reference` branch; do not add Android code here.

## Layout

- `AntennaPod/` — SwiftUI app target. All Swift files under this directory are
  compiled automatically by the generated project.
- `Packages/AntennaPodCore/` — Foundation-only package (models, RSS/Atom/RDF
  parsing, OPML, networking, library logic, JSON persistence). Keep it free of
  UIKit/AVFoundation so it stays testable on Linux.
- `AntennaPod.xcodeproj/` — generated. Never hand-edit `project.pbxproj`; run
  `python3 scripts/generate_xcodeproj.py` after adding or removing Swift files.
- `scripts/generate_xcodeproj.py` — deterministic project generator.

## Coding conventions

- Deployment target is iOS 15.0. Do not use iOS 16+ APIs (`NavigationStack`,
  `Locale.Region`, `presentationDetents`, `ShareLink`, Swift Charts, etc.).
- Use `NavigationView` + `StackNavigationViewStyle` for navigation.
- Business logic belongs in `AntennaPodCore`; views should stay thin.
- Persistence goes through `LibraryStore`; do not add a second store.
- User-facing copy is plain English for now. Localization files do not exist
  yet; if you add a Strings catalog, add it to the Xcode target as a resource.
- Keep GPL-3.0 headers/attribution: this is a derivative work of AntennaPod.

## Building and testing

Linux cannot compile the SwiftUI layer. Verify the core on Linux:

```sh
swift test --package-path Packages/AntennaPodCore
```

On macOS, build the app:

```sh
xcodebuild \
  -project AntennaPod.xcodeproj \
  -scheme AntennaPod \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

CI (`.github/workflows/ios.yml`) runs core tests on macOS and Linux plus the
simulator build. There is no Xcode unit-test target yet; add tests to the core
package instead.

## Git

- `develop` is the iOS branch.
- `android-reference` preserves the upstream Android tree for reference.
- Do not commit the token file or derived data.
