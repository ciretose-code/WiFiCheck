# WiFi Check

A macOS app that displays detailed information about the Wi-Fi networks your Mac has connected to, sourced directly from the system's protected Wi-Fi preferences file.

**Requires macOS 26 or later.**

---

## What it shows

For each known network:

- **SSID**, security type, and hidden/visible status
- **Connection timestamps** — when the network was joined automatically or manually, when it was added, last discovered, last disconnected, and profile update time
- **Disconnect reason**
- **Access points (BSSIDs)** — channel, frequency band, last seen, router IP, and location on a map (when available)
- **Channel history** — past channels the network has been seen on
- **Collocated networks** — other networks seen at the same physical location
- **Network details** — roaming profile, private MAC address, MAC evaluation state, backhaul state, preferred network names
- **Flags** — Personal Hotspot, Temporarily Disabled, Moving, iCloud Sync (System Mode), Privacy Proxy
- **Captive portal** — last login date for networks requiring web authentication
- **Password** — reads from your Keychain with your permission, auto-hides after a configurable timeout

Networks can also be removed from your preferred networks list.
From the app menu, WiFi Check can also manually compare your installed version against the latest GitHub release.

---

## Why it needs special access

macOS protects the Wi-Fi preferences file (`com.apple.wifi.known-networks.plist`) under System Integrity Protection. Reading it requires one of two approaches:

**Option 1 — Privileged Helper (recommended)**
Installs a small background daemon that reads the file as root. Requires three one-time steps: entering your admin password, enabling the app in System Settings → Login Items, and granting Full Disk Access to the helper.

**Option 2 — Import a file**
Export the plist manually and open it in WiFi Check:
```bash
sudo cp /Library/Preferences/com.apple.wifi.known-networks.plist ~/Downloads/wifi-networks.plist
```
Then use File → Open in the app. No helper required, but data won't update automatically.

---

## Building

Requires Xcode 26+ and macOS 26.

```bash
git clone https://github.com/ciretose-code/WiFiCheck.git
cd WiFiCheck
open WiFiCheck.xcodeproj
```

Build and run the `WiFiCheck` scheme. For testing the privileged helper, install to `/Applications` first:

```bash
./Scripts/install-dev.sh
```

---

## Background

Built as an exercise in SwiftUI and to scratch a personal itch — I wanted visibility into my Mac's full Wi-Fi history.
