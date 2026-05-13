# WiFi/Check – Copilot Instructions

## Project Overview

WiFi/Check is a **macOS-only SwiftUI app** for inspecting the system Wi-Fi known-networks plist, showing connection history, security details, BSSID/channel history, and stored passwords. The current docs and project settings target **Xcode 26+** and **macOS 26+**.

The app has two supported data-access paths:

1. **Privileged helper (recommended)** — a launchd daemon installed with `SMAppService.daemon` reads `/Library/Preferences/com.apple.wifi.known-networks.plist` as root and returns the raw plist over XPC.
2. **Manual file import** — the user copies the plist to a readable location or opens/drags in a plist file; this works without the helper but does not provide live system access.

## Build, Test, and Lint

Build the main app from Xcode or from the command line:

```bash
xcodebuild -project WiFiCheck.xcodeproj -scheme WiFiCheck -allowProvisioningUpdates build
```

Build just the helper target when isolating daemon/XPC issues:

```bash
xcodebuild -project WiFiCheck.xcodeproj -scheme WiFiCheckHelper -allowProvisioningUpdates build
```

For helper testing, the built app must be installed to `/Applications` because `SMAppService.daemon` will not work correctly from DerivedData:

```bash
./Scripts/install-dev.sh
```

The release pipeline is scripted here:

```bash
./Scripts/release.sh
```

There are **no XCTest targets** in this repo today, so there is no single-test command to run. There is also **no lint/formatter configuration**; follow the existing Swift style and rely on Xcode compiler diagnostics.

## High-Level Architecture

The app uses a **singleton-service pattern**, not MVVM. There is no `ObservableObject` or `@EnvironmentObject`; views keep local `@State` and call shared services directly.

- **`WiFiCheck` target** — the SwiftUI app.
- **`WiFiCheckHelper` target** — a privileged background helper/launch daemon that reads the protected plist as root.
- **`WiFiHelperProtocol.swift`** — the shared XPC contract; it must stay in sync across both targets.

The main flow is:

1. `WiFiListView` / `WiFiListPane` own the UI state for sorting, searching, setup, helper install/remove, file import, and initial loading.
2. `WiFiDataManager.shared` is the central integration point. It checks direct file access, installs/uninstalls the helper, loads raw plist data via XPC or file import, parses the plist, stores the in-memory `[WiFiData]`, and provides the sorting methods used by the sidebar.
3. `NetworkSetup.shared` wraps `/usr/sbin/networksetup` to detect the actual Wi-Fi interface, fetch the preferred network order, read the current SSID, and remove saved networks.
4. `WiFiDataDetail` renders the selected network and handles password reveal, QR popover, and "Forget Network". The forget action is only available for live system data, not imported plist files.

`WiFiData` mirrors the real plist structure rather than introducing a separate view model. It carries top-level fields, `BSSList`, `CaptiveProfile`, and `__OSSpecific__` content, and also provides display helpers such as security classification and human-readable disconnect reasons.

The plist is parsed manually with `PropertyListSerialization` because the top level is a `Dictionary<String, AnyObject>`, not a clean Codable shape.

## Key Conventions

**Dependency-free app**: `CONTRIBUTING.md` explicitly asks contributors to keep the project dependency-free and avoid new entitlements or privacy permissions without strong justification.

**Add plist fields in three places**: when supporting a new plist field, update:

1. the string key stored on `WiFiDataManager`
2. the assignment in `WiFiDataManager.parseWiFiData(from:)`
3. the matching property on `WiFiData`

**Preserve plist naming**: `WiFiData` property names intentionally use plist-style PascalCase (`JoinedByUserAt`, `AddReason`, etc.). Do not "Swiftify" them.

**Preserve Apple's typo**: the real plist key is `BrokenBackhaulStateUdatedAt` (missing the second `p`). Keep that typo in the parser constant so lookups still work.

**Do not treat Wi-Fi IDs as plain SSIDs**: plist entries use `wifi.ssid.<hexdata>` keys. Use `WiFiDataManager.parseWiFiSSID(_:)` when decoding network IDs or collocated-group values.

**Helper/XPC names must stay aligned**: the app target, helper target, Mach service name (`com.ciretose.macos.tool.WiFiCheck.helper`), and daemon plist name all have to match for helper installation and XPC communication to work.

**Imported file state changes behavior**: `loadedFromDrop` / `isLoadedFromFile` are behavioral flags, not just provenance. Imported plist data should not be treated like live system data; for example, the UI hides "Forget Network" for imported files.

**All shelling out goes through `Utils.runCommand`**: do not instantiate `Process` directly outside `Utils`. `runCommand` already uses argument arrays, captures stdout/stderr, and enforces a timeout.

**Use shared date formatting helpers**: `Utils.relativeDateToString` is the standard user-facing "recent date" formatter, while `Utils.dateToString` is the full timestamp format. Follow the cached formatter pattern in `Utils` for any new formatters.

**Use project logging conventions**: use `Logger` with subsystem `com.ciretose.wificheck`, and mark user/network data as `.private` while keeping non-sensitive paths `.public`.

**Use `WiFiButtonStyle` for action buttons**: setup, password, destructive, and other app action buttons consistently use the custom `WiFiButtonStyle` from `WiFiCheckApp.swift`.

**Security display is centralized**: `WiFiData.securityType()` and `Utils.getSecurityColor(_:)` define the shared mapping used across list/detail UI:

- WPA3 → green
- WPA2/WPA → teal
- WEP → orange
- Open → red
- Unknown → gray

**Preferred order comes from `networksetup`, not plist order**: `NetworkSetup.getPreferredNetworkOrder()` assigns values in increments of `Constants.networkOrderIncrement` (100), and networks missing from the preferred list fall back to `Int.max`.

**Code review agent**: `.github/agents/swift-code-reviewer.agent.md` is the project-specific reviewer for Swift/macOS bug-finding tasks.
