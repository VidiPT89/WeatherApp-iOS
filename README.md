# 📱 WeatherApp — iOS Client

> Native SwiftUI client for the [Weather API Aggregator](https://github.com/VidiPT89/WeatherAPI) — proves the same backend contract that powers the [web client](https://github.com/VidiPT89/WeatherApp) serves a native mobile app too.

**Live demo:** not published (no App Store account for this project) — can also point at the live backend directly, see *How to Run*.

One of three clients (Web / iOS / [Android](https://github.com/VidiPT89/WeatherApp-Android)) built on top of the same backend. This app talks directly to the Weather API — it never talks to Open-Meteo/OpenWeatherMap directly.

## 📦 What's Inside

- 🔎 City search with debounced autocomplete (backend geocoding endpoint) — also used on the Favorites tab now, so a favorite can only be added from a real geocoded suggestion, not free-typed text that the weather-by-name lookup might later fail to resolve
- 🌡️ Current weather + hourly/daily forecast chart (Swift Charts), with a °C/°F toggle — the hourly chart's default visible window is 12h (up from 7h) plus a non-scrolling "next 24h at a glance" sparkline above it, so a full day's temperatures are readable with far less paging
- 👆 Tap the weather, sea-conditions or "Mais sobre hoje" cards on the Dashboard for an expanded detail sheet (fuller current-conditions breakdown, the full day's tide events, or a multi-day view of UV/activity/fishing/surf conditions)
- 🧩 **Home-screen widget** (`WeatherWidget`, small + medium) — mirrors the last weather the app itself fetched via an App Group; it never fetches independently, it just refreshes whenever the Dashboard loads a new city
- ⚡ **Cache badge** — "dados frescos" vs "servido da cache há Xs", ticking live from the response's `fromCache` flag and timestamp
- 🔁 **Fallback banner** — appears when the response was served by the secondary provider
- 🔐 Auth (register/login, JWT in Keychain), favorite cities (add via autocomplete + swipe-to-delete), search history, saved unit preference
- 🛡️ Admin section (Settings → "Administração", role-gated) — list every account and delete one (swipe-to-delete), except the caller's own
- ✅ Loading, error and empty states throughout

## 🛠️ Tech Stack

![Swift](https://img.shields.io/badge/Swift%206-F05138?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0066CC?style=flat&logo=swift&logoColor=white)
![Swift Charts](https://img.shields.io/badge/Swift%20Charts-0066CC?style=flat)
![XCTest](https://img.shields.io/badge/XCTest-147EFB?style=flat&logo=xcode&logoColor=white)

Project generated/managed with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) rather than a hand-edited `.xcodeproj`, so the project structure is plain text and reviewable in git.

## 🏗️ Architecture

```
WeatherApp-iOS (SwiftUI)
   │  URLSession + Bearer token from Keychain — no BFF, talks to the API directly
   ▼
WeatherAPI (Spring Boot, sibling repo, localhost:8080)
   │  cache (Caffeine) → circuit breaker + retry → provider adapters
   ▼
Open-Meteo / OpenWeatherMap (external providers)
```

```
WeatherApp-iOS/
├── Models/          # Codable structs mirroring the backend DTOs exactly
├── Networking/      # APIClient (actor, URLSession), AuthStore (Keychain), KeychainHelper
├── ViewModels/      # one @Observable view model per screen
├── Views/           # Auth, Dashboard (weather card, cache badge, fallback banner, forecast chart,
│                    # + detail sheets), Favorites, History, Settings (incl. admin user list), MainTabView
├── Shared/          # WeatherWidgetSnapshot + App-Group UserDefaults store, compiled into both
│                    # the app and WeatherWidget targets
└── Info.plist       # NSAppTransportSecurity localhost exception (plain HTTP in local dev)

WeatherWidget/       # WidgetKit extension target: small/medium home-screen widget, app-driven only
```

### Why these choices

- **Direct-to-API, no BFF**: unlike the web client (which proxies through Next.js Route Handlers to keep the JWT out of browser JS), a native app's Keychain is already a secure, sandboxed place to hold a token — no XSS surface to defend against, so there's no need for a server-side proxy layer.
- **Local-datetime forecast decoding**: `hourly[].time`/`daily[].date` come back from the API without a timezone offset (Open-Meteo's `timezone=auto` already localizes them), so they're decoded as plain `Date`/`DateComponents` via a custom formatter instead of `.iso8601`, which would reject them.
- **XCUITest over manual driving**: this environment doesn't have screen-recording permission for computer-use automation, so the golden path (register → search → cache badge flips → favorites → history → settings) is captured as a real, re-runnable `XCUITest` instead of a one-off manual walkthrough — arguably stronger verification since it re-runs on every future change.
- **App-driven widget, not a polling one**: `WeatherWidget` never calls the network itself — its `TimelineProvider` reads a small `Codable` snapshot the main app wrote to a shared App Group container after its own last successful Dashboard fetch, and uses a `.never` reload policy since the app calls `WidgetCenter.shared.reloadAllTimelines()` right after writing a fresh snapshot. Simpler than giving the widget its own fetch/refresh schedule, and the data is never more stale than "whatever the app itself last saw" — which is the whole point of a glance widget.

## 🚀 How to Run

Prerequisites: Xcode 16+, and the [Weather API](https://github.com/VidiPT89/WeatherAPI) running locally on `http://localhost:8080` (see that repo's README) — or point `APIClient`'s base URL at the live deployment: `https://weather-api-production-68ff.up.railway.app`.

```bash
open WeatherApp-iOS.xcodeproj
# ⌘R on the WeatherApp-iOS scheme, any iOS 17+ simulator
```

Or from the command line:

```bash
xcodebuild -project WeatherApp-iOS.xcodeproj -scheme WeatherApp-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

If `project.yml` changes, regenerate the project with `xcodegen generate`.

The `WeatherWidget` extension has its own scheme, useful for iterating on the widget in isolation (Xcode's widget preview support works from either scheme):

```bash
xcodebuild -project WeatherApp-iOS.xcodeproj -scheme WeatherWidgetExtension \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## ✅ Tests

```bash
xcodebuild test -project WeatherApp-iOS.xcodeproj -scheme WeatherApp-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

- **Unit tests** (`WeatherApp-iOSTests`): model decoding fixtures (including the local-datetime forecast parsing), `APIClient` error-decoding and token-refresh handling (retry-once on an expired access token, propagating the original error when the refresh token itself is rejected, single-flighting concurrent refreshes) against a mocked `URLProtocol`, `AuthStore`'s logout-vs-in-flight-refresh race handling (both the resurrection-after-logout case and the newer forced-logout-on-refresh-failure case), cache-age formatting, weather-condition keyword matching, `FavoritesViewModel.addFavorite(city:)` (success, the 409 duplicate-favorite message, blank-input guard).
- **UI test** (`WeatherApp-iOSUITests/GoldenPathUITests.swift`): drives the real app against a live backend end-to-end — register → search a city → confirm weather + forecast render → search again and confirm the cache badge flips to "servido da cache" → toggle the forecast chart tabs → add a favorite → jump back to it → check history → toggle units in settings.

Given the project's scope (three client apps on one backend), test effort is weighted toward decoding/business-logic and one comprehensive end-to-end flow, rather than unit-testing pure SwiftUI layout.

## 📝 Notes

- No clear-history UI — matches the backend's intentional v1 scope (no delete endpoint exists yet for history). Favorites can be removed (swipe-to-delete).
- Requires the backend reachable at `http://localhost:8080`; the simulator shares the host's network namespace so no special host mapping is needed (unlike the Android emulator, which needs `10.0.2.2`).

## 📄 License

MIT — see [LICENSE](LICENSE).

---

Developed by **David Arsénio Martins**
🌐 [ividi.dev](https://ividi.dev/) · 💻 [github.com/VidiPT89](https://github.com/VidiPT89/)
