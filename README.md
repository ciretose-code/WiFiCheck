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

Networks can also be forgotten. Forget removes the entry from known-networks history, the preferred list, and the saved password.
From the app menu, WiFi Check can also manually compare your installed version against the latest GitHub release.

---

## Why it needs special access

macOS protects the Wi-Fi preferences file (`com.apple.wifi.known-networks.plist`) under System Integrity Protection. Reading it requires one of two approaches:

**Option 1 — Privileged Helper (recommended)**
Installs a small background daemon that reads the file as root. Requires three one-time steps: entering your admin password, enabling the app in System Settings → Login Items, and granting Full Disk Access to the helper.

**Option 2 — Import a file**
Export the plist manually to a private folder (owner-only permissions) and open it in WiFi Check:
```bash
mkdir -p "$HOME/Library/Application Support/WiFiCheck"
sudo cp /Library/Preferences/com.apple.wifi.known-networks.plist "$HOME/Library/Application Support/WiFiCheck/wifi-networks.plist"
sudo chown "$USER" "$HOME/Library/Application Support/WiFiCheck/wifi-networks.plist"
chmod 600 "$HOME/Library/Application Support/WiFiCheck/wifi-networks.plist"
```
Then use **Load File** in Setup (preferred — the app deletes the copy after a successful import) or File → Open. If you open the file another way, delete the copy yourself afterward. No helper required, but data won't update automatically.

---

## Building

Requires Xcode 26+ and macOS 26.

```bash
git clone https://github.com/ciretose-code/WiFiCheck.git
cd WiFiCheck
cp Config/Local.xcconfig.template Config/Local.xcconfig
# Set DEVELOPMENT_TEAM in Config/Local.xcconfig to your Apple Team ID
open WiFiCheck.xcodeproj
```

`Config/Local.xcconfig` is gitignored so Team IDs stay out of the repo. Build and run the `WiFiCheck` scheme. For testing the privileged helper, install to `/Applications` first:

```bash
./Scripts/install-dev.sh
```

---

## Background

Built as an exercise in SwiftUI and to scratch a personal itch — I wanted visibility into my Mac's full Wi-Fi history.
