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

CI runs both the core tests and a simulator build on macOS; see
`.github/workflows/ios.yml`.

## Persistence

The library is stored as JSON in Application Support (`library.json`, with a
`.bak` fallback). This keeps the MVP dependency-free; a Core Data or SwiftData
store can replace `LibraryStore` later without touching the rest of the app.

## License

AntennaPod is licensed under the GNU General Public License v3.0. This port is a
derivative work and is distributed under the same license. See `LICENSE`.

AntennaPod is developed by the AntennaPod community. This iOS port is
independent and is not affiliated with the Android project's maintainers.
