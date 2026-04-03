# WiFi/Check – Copilot Instructions

## Project Overview

WiFi/Check is a **macOS-only SwiftUI app** (macOS 11.0+, Swift 5.0) that reads the system WiFi known-networks plist and displays connection history, security info, and stored passwords. The app requires **Full Disk Access** because `/Library/Preferences/com.apple.wifi.known-networks.plist` is protected on macOS Big Sur and later.

## Build

Open `WiFiCheck.xcodeproj` in Xcode and build the `WiFiCheck` scheme, or from the command line:

```bash
xcodebuild -project WiFiCheck.xcodeproj -scheme WiFiCheck build
```

There are no test targets.

## Architecture

The app follows a **singleton-service pattern**, not MVVM. There is no `ObservableObject` or `@EnvironmentObject`; views call the shared singletons directly.

- **`WiFiDataManager.shared`** — reads and parses the plist, owns the in-memory `[WiFiData]` list, handles sorting, and supports drag-and-drop loading when Full Disk Access is unavailable.
- **`NetworkSetup.shared`** — wraps the `networksetup` CLI tool to get preferred network order, active SSID, and remove networks. Detects the actual WiFi interface name (usually `en0`) at init.
- **`KeychainAccess`** — static methods only; reads WiFi passwords from Keychain under service name `"AirPort"`. Prefer the `getPassword(forNetwork:)` method that returns `Result<String, Error>` over the deprecated `getWiFiPassword(forNetwork:)` tuple version.
- **`Utils`** — static utility class for date formatting and `runCommand(_:withArgs:)`. All shell commands must go through `Utils.runCommand`; never create `Process` directly.
- **`Constants`** — `enum` (no cases) holding all app-wide literal values. Add new constants here.

### View hierarchy

```
WiFiCheckApp
└── ContentView
    └── WiFiListView              NavigationView wrapper + sidebar toggle
        ├── WiFiListPane          Sidebar: sort picker, network list, Remove/Show buttons
        └── WiFiDataDetail        Detail pane: dates, security, password reveal, channel history
```

Supporting views: `WiFiDataRow`, `WiFiDateBox`, `CheckboxView`, `CollocatedGroupView`, `ChannelHistoryView`, `BSSIDListView`.

Custom button style: **`WiFiButtonStyle`** (defined in `WiFiCheckApp.swift`) — takes `delete: Bool` and `disabled: Bool` parameters; use this for all action buttons.

### Data model

`WiFiData` is a plain `struct` (Hashable, Codable, Identifiable via `id: Self`). Property names use **PascalCase to match plist keys exactly** (e.g., `JoinedByUserAt`, `AddReason`). Don't change this casing.

The plist is parsed manually with `PropertyListSerialization` rather than `Codable` because the top-level structure is a `Dictionary<String, AnyObject>`. The `find*` helper methods on `WiFiDataManager` (`findBool`, `findInt`, `findString`, `findDate`, `findData`) are the safe extraction layer — use them when adding new plist fields.

## Key Conventions

**Plist key names as instance variables**: `WiFiDataManager` stores all plist key strings as `let` instance variables (e.g., `let AddReason = "AddReason"`). When adding support for a new plist field, add the key as an instance variable there and a matching property on `WiFiData`.

**Known plist typo**: The system plist has a typo — `BrokenBackhaulStateUdatedAt` (missing second `p`). The constant in `WiFiDataManager` intentionally preserves this typo to match the actual key.

**Apple WiFi ID format**: Plist keys use `wifi.ssid.<hexdata>` format. Use `WiFiDataManager.parseWiFiSSID(_:)` to decode them. Don't assume the key is a plain SSID string.

**Security color coding** (used consistently across `WiFiDataRow`, `WiFiDataDetail`, `Utils`):
- WPA3 → `.green`
- WPA2/WPA → `Color(NSColor.systemTeal)`
- WEP → `.yellow`
- Open → `.red`
- Unknown → `.gray`

**Logging**: Use `os.log` (`Logger`) with subsystem `"com.ciretose.wificheck"`. Mark user data as `.private` and non-sensitive paths as `.public`.

**Date display**: Use `Utils.relativeDateToString` for user-facing dates (shows relative time for dates within 9 months, falls back to "DD MMM YYYY"). Use `Utils.dateToString` for full absolute timestamps (e.g., tooltips).

**DateFormatter caching**: `Utils` caches static `DateFormatter` instances because they're expensive to allocate. Follow this pattern for any new formatters.

**Preferred order encoding**: Networks are assigned order values in increments of `Constants.networkOrderIncrement` (100) by `NetworkSetup.getPreferredNetworkOrder()`. Networks not in the preferred list get `Int.max`.

**Drag-and-drop fallback**: When Full Disk Access isn't granted, `WiFiListPane` shows a drop target. `WiFiDataManager.parseDroppedData(_:)` handles the dropped plist bytes and sets `loadedFromDrop = true`, which causes `needsPassword()` to return `false`.

**Shell command safety**: `Utils.runCommand` passes arguments as an array to `Process` (not a shell string), has a 30-second timeout, and captures both stdout and stderr. `NetworkSetup.deleteNetwork` validates SSIDs against a shell metacharacter blocklist before calling out.

## Sample Data

`SampleData/com.apple.wifi.known-networks.plist` is a real plist for local development. Drag it onto the app window to load it without Full Disk Access.

## Custom Agent

`.github/agents/swift-code-reviewer.agent.md` defines a code review agent specialized for this project. Invoke it when asked to review Swift code for bugs or issues.
