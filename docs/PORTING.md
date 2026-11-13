# Porting notes

This document tracks how the Android implementation maps onto the iOS app and
what is intentionally missing from the first version.

## Architecture

| Android | iOS |
| --- | --- |
| `parser/feed` (SAX-based RSS/Atom/RDF parser) | `Packages/AntennaPodCore/Sources/AntennaPodCore/FeedParser.swift` (Foundation `XMLParser`, namespace-agnostic lookups) |
| `model/feed` (`Feed`, `FeedItem`, `FeedMedia`) | `Podcast`, `Episode`, `Media` value types |
| `storage/database` (Room/SQLite) | `LibraryStore` JSON file with atomic writes and `.bak` fallback |
| `storage/importexport` (OPML) | `OPML.parse` / `OPML.write` |
| `net/download` (DownloadService) | `DownloadManager` with a background `URLSession` |
| `playback/service` (Media3/ExoPlayer + MediaSession) | `PlaybackController` with `AVPlayer`, `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` |
| `ui/` XML layouts + fragments | SwiftUI views under `AntennaPod/Features` |
| `FeedItemFilter` / `FeedFilter` | Sort options and the Inbox/Favorites computed views in `Library` |

Feed parsing is covered by unit tests in `Packages/AntennaPodCore/Tests`.

## Feature matrix

| Feature | Status |
| --- | --- |
| Subscribe by feed URL | Done |
| Search via iTunes directory | Done |
| OPML import/export | Done |
| RSS 2.0, Atom, RDF/RSS 1.0 | Done |
| iTunes namespace (author, artwork, duration, explicit, season/episode) | Done |
| Podcast Index chapters/transcripts/funding URLs | Parsed and stored, UI not implemented |
| Episode list, sorting, played/favorite flags | Done |
| Streaming playback | Done |
| Background downloads | Done |
| Up-next queue, reorder, play next | Done |
| Playback speed, skip forward/back, sleep timer | Done |
| Background audio + lock screen/Control Center | Done |
| Feed refresh (ETag/Last-Modified) | Done |
| Auto-download latest episodes | Done |
| Auto-delete played downloads | Setting exists; not enforced |
| Stream only on Wi-Fi | Setting exists; not enforced |
| Chapters UI | Not yet |
| Transcripts UI | Not yet |
| gpodder.net sync | Not yet (fields reserved in settings) |
| Statistics | Not yet |
| Episode filters / custom sorting rules | Not yet |
| Widgets, CarPlay, Chromecast | Not yet |
| Sleep timer fade-out / shake-to-reset | Not yet |

## Known differences

- **Persistence**: JSON instead of SQLite/Room. Fine for thousands of episodes,
  but there are no migrations yet; `LibraryStore.Envelope.schemaVersion` is
  reserved for that.
- **Episode identity**: `podcastID#guid` (falling back to enclosure, link, or
  title). Android uses a database row id, so exported OPML is compatible but
  playback positions are not migrated.
- **Search**: iTunes Search API only (same directory AntennaPod uses by
  default); Podcast Index search is not wired up.
- **Images**: `AsyncImage` with no disk cache. Artwork is refetched by the
  system cache, not by AntennaPod's own image loader.
- **Downloads**: one background session; no per-podcast network policy and no
  resumable queue after app termination beyond what `URLSession` restores.
- **Sleep timer**: fixed minutes only, no "end of episode" or fade-out.
- **Localization**: English only.

## Upstream references

The Android implementation is available on the `android-reference` branch.
Useful starting points when adding a feature:

- `parser/feed/src/main/java/de/danoeh/antennapod/parser/feed/FeedHandler.java`
- `storage/database/src/main/java/de/danoeh/antennapod/storage/database/DBReader.java`
- `playback/service/src/main/java/de/danoeh/antennapod/playback/service/PlaybackService.java`
- `ui/` for screen structure and strings
