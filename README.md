# AntennaPod for iOS

A native SwiftUI port of [AntennaPod](https://antennapod.org), the open-source
podcast manager, targeting iOS 15 and later.

This repository contains the iOS app. The original Android sources are kept on
the [`android-reference`](https://github.com/MagicDippyEggsRandomStuff/AntennaPod-iOS/tree/android-reference)
branch so the port can be compared against the reference implementation.

## Status

This is an early MVP. It is usable for the core podcast workflow:

- Subscribe by search (iTunes directory), feed URL, or OPML import/export
- Podcast and episode lists with played/unplayed/favorite state
- Streaming and background download playback
- Up-next queue with reordering
- Playback speed, skip intervals, sleep timer
- Background audio, lock screen and Control Center controls
- Feed refresh with ETag/Last-Modified, auto-download, auto-delete hooks
- OPML import and export

Not yet implemented: chapters UI, transcripts, gpodder sync, statistics,
filters, widgets, CarPlay, Chromecast, and full AntennaPod settings parity. See
`docs/PORTING.md` for the feature matrix.

## Requirements

- macOS with Xcode 15 or newer (the project targets iOS 15)
- A device or simulator running iOS 15+

## Building

Open `AntennaPod.xcodeproj` in Xcode and run the `AntennaPod` scheme, or build
from the command line:

```sh
xcodebuild \
  -project AntennaPod.xcodeproj \
  -scheme AntennaPod \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The app is generated from the Swift sources under `AntennaPod/`. If you add or
remove a Swift file, regenerate the project:

```sh
python3 scripts/generate_xcodeproj.py
```

The shared `AntennaPodCore` package contains the feed parser, OPML support,
library model, download paths, and persistence. It has no UIKit dependency and
can be tested on any platform with a Swift toolchain:

```sh
swift test --package-path Packages/AntennaPodCore
```

CI runs the core tests, a simulator build, and an unsigned device build on
macOS; see `.github/workflows/ios.yml`.

## Installing a test build (TrollStore, iOS 15)

Every push to `develop` produces an unsigned IPA artifact, so no Apple
developer account or provisioning profile is needed:

1. Open the latest [Actions run](https://github.com/MagicDippyEggsRandomStuff/AntennaPod-iOS/actions/workflows/ios.yml)
   for the `develop` branch.
2. Download the `AntennaPod-unsigned-ipa` artifact (GitHub serves it as a zip;
   extract `AntennaPod-unsigned.ipa` from it).
3. Transfer the IPA to the device and open it with TrollStore. TrollStore signs
   and installs it locally.

The build is unsigned on purpose. Do not try to install it through Xcode,
Apple Configurator, or TestFlight; those paths require a valid signature.

TestFlight and App Store distribution will need a paid Apple Developer account
and real signing certificates, which can be added to the workflow later.

## Persistence

The library is stored as JSON in Application Support (`library.json`, with a
`.bak` fallback). This keeps the MVP dependency-free; a Core Data or SwiftData
store can replace `LibraryStore` later without touching the rest of the app.

## License

AntennaPod is licensed under the GNU General Public License v3.0. This port is a
derivative work and is distributed under the same license. See `LICENSE`.

AntennaPod is developed by the AntennaPod community. This iOS port is
independent and is not affiliated with the Android project's maintainers.
