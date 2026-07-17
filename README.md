# 📱 WeatherApp — iOS Client

> Native SwiftUI client for the [Weather API Aggregator](../WeatherAPI) — proves the same backend contract that powers the [web client](../WeatherApp) serves a native mobile app too.

**Live demo:** not published — runs in the iOS Simulator against the Weather API on `localhost:8080` (see *How to Run*).

One of three clients (Web / iOS / [Android](../WeatherApp-Android)) built on top of the same backend. This app talks directly to the Weather API over an HTTPS-exempted localhost connection — it never talks to Open-Meteo/OpenWeatherMap directly.

## 📦 What's Inside

- 🔎 City search with debounced autocomplete (backend geocoding endpoint)
- 🌡️ Current weather + hourly/daily forecast chart (Swift Charts), with a °C/°F toggle
- ⚡ **Cache badge** — "dados frescos" vs "servido da cache há Xs", ticking live from the response's `fromCache` flag and timestamp
- 🔁 **Fallback banner** — appears when the response was served by the secondary provider
- ⚖️ **Provider comparison screen** — the same city, side by side, across every configured provider, with a computed average
- 🔐 Auth (register/login, JWT in Keychain), favorite cities, search history, saved unit preference
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
├── Views/           # Auth, Dashboard (weather card, cache badge, fallback banner, forecast chart),
│                    # Favorites, History, Compare, Settings, MainTabView
└── Info.plist       # NSAppTransportSecurity localhost exception (plain HTTP in local dev)
```

### Why these choices

- **Direct-to-API, no BFF**: unlike the web client (which proxies through Next.js Route Handlers to keep the JWT out of browser JS), a native app's Keychain is already a secure, sandboxed place to hold a token — no XSS surface to defend against, so there's no need for a server-side proxy layer.
- **Local-datetime forecast decoding**: `hourly[].time`/`daily[].date` come back from the API without a timezone offset (Open-Meteo's `timezone=auto` already localizes them), so they're decoded as plain `Date`/`DateComponents` via a custom formatter instead of `.iso8601`, which would reject them.
- **XCUITest over manual driving**: this environment doesn't have screen-recording permission for computer-use automation, so the golden path (register → search → cache badge flips → favorites → history → compare → settings) is captured as a real, re-runnable `XCUITest` instead of a one-off manual walkthrough — arguably stronger verification since it re-runs on every future change.

## 🚀 How to Run

Prerequisites: Xcode 16+, and the [Weather API](../WeatherAPI) running locally on `http://localhost:8080` (see that repo's README).

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

## ✅ Tests

```bash
xcodebuild test -project WeatherApp-iOS.xcodeproj -scheme WeatherApp-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

- **Unit tests** (`WeatherApp-iOSTests`): model decoding fixtures (including the local-datetime forecast parsing), `APIClient` error-decoding against a mocked `URLProtocol`, cache-age formatting, weather-condition keyword matching, provider-comparison average logic.
- **UI test** (`WeatherApp-iOSUITests/GoldenPathUITests.swift`): drives the real app against a live backend end-to-end — register → search a city → confirm weather + forecast render → search again and confirm the cache badge flips to "servido da cache" → toggle the forecast chart tabs → add a favorite → jump back to it → check history → check compare (confirms the expected local fallback: `open-meteo` succeeds, `open-weather-map` fails since no API key is configured) → toggle units in settings.

Given the project's scope (three client apps on one backend), test effort is weighted toward decoding/business-logic and one comprehensive end-to-end flow, rather than unit-testing pure SwiftUI layout.

## 📝 Notes

- No delete-favorite/clear-history UI — matches the backend's intentional v1 scope (no delete endpoints exist yet).
- Requires the backend reachable at `http://localhost:8080`; the simulator shares the host's network namespace so no special host mapping is needed (unlike the Android emulator, which needs `10.0.2.2`).

## 📄 License

MIT.

---

Developed by **David Arsénio Martins**
🌐 [ividi.dev](https://ividi.dev/) · 💻 [github.com/VidiPT89](https://github.com/VidiPT89/)
