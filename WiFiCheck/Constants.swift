//
//  Constants.swift
//  WiFiCheck
//
//  Created by Claude Code on 3/2/26.
//

import Foundation

/// Application-wide constants
enum Constants {

    // MARK: - Network Configuration

    /// Increment value for preferred network ordering
    /// Networks are assigned order values in increments of 100 to allow easy reordering
    static let networkOrderIncrement = 100

    /// Default WiFi network interface device name
    static let defaultWiFiDevice = "en0"

    /// WiFi service name used by networksetup
    static let wifiServiceName = "Wi-Fi"

    // MARK: - Security

    /// Duration in seconds before auto-hiding displayed passwords
    static let passwordAutoHideDelay = 30

    /// Duration in seconds before clearing a password-bearing QR image from the pasteboard
    static let qrPasteboardClearDelay = 30

    /// Keychain service name for WiFi passwords
    static let keychainService = "AirPort"

    // MARK: - App Updates

    /// GitHub repository owner used for manual update checks
    static let gitHubOwner = "ciretose-code"

    /// GitHub repository name used for manual update checks
    static let gitHubRepository = "WiFiCheck"

    /// GitHub API endpoint for the latest published release
    static let gitHubLatestReleaseAPI = "https://api.github.com/repos/\(gitHubOwner)/\(gitHubRepository)/releases/latest"

    // MARK: - File Paths

    /// System configuration folder containing network preferences
    static let systemConfigurationFolder = "/Library/Preferences"

    /// WiFi known networks plist filename
    static let wifiKnownNetworksFile = "com.apple.wifi.known-networks.plist"

    /// Maximum accepted size for user-imported known-networks plists (drag/drop or Open).
    /// Real `com.apple.wifi.known-networks.plist` files are typically well under 1 MB even with
    /// hundreds of networks and BSS history; 5 MB leaves headroom while bounding memory/CPU
    /// spent on PropertyListSerialization for arbitrary dropped files.
    static let maxKnownNetworksImportBytes = 5 * 1024 * 1024

    /// Legacy Apple known-networks dictionary keys (`wifi.ssid.<hex>`).
    static let knownNetworkSSIDKeyPrefix = "wifi.ssid."

    /// macOS 27+ known-networks dictionary keys (`wifi.network.ssid.<plaintext SSID>`).
    static let knownNetworkSSIDKeyPrefixModern = "wifi.network.ssid."

    /// True for either legacy hex keys or modern plaintext SSID keys.
    static func isKnownNetworkKey(_ key: String) -> Bool {
        key.hasPrefix(knownNetworkSSIDKeyPrefixModern) || key.hasPrefix(knownNetworkSSIDKeyPrefix)
    }

    /// Networksetup command line utility path
    static let networksetupPath = "/usr/sbin/networksetup"

    /// Airport framework utility path (optional, for advanced features)
    static let airportCommandPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

    /// Nested privileged helper app name (copied into Contents/Library/LaunchDaemons).
    static let helperAppName = "WiFiCheckHelper.app"

    /// Executable name inside the nested helper app.
    static let helperExecutableName = "WiFiCheckHelper"

    /// Nested helper bundle ID (Mach service / codesign requirement).
    static let helperBundleIdentifier = "com.ciretose.macos.tool.WiFiCheck.helper"

    /// Host app bundle ID — prefer this for Full Disk Access. The helper is
    /// launchd-exec'd without Launch Services identity, so FDA on the helper
    /// alone is path+cdhash and dies on updates; AssociatedBundleIdentifiers
    /// ties the daemon to this host identity.
    static let appBundleIdentifier = "com.ciretose.macos.tool.WiFiCheck"

    /// SMAppService `BundleProgram` path relative to the host app bundle.
    static let helperBundleProgramRelativePath =
        "Contents/Library/LaunchDaemons/\(helperAppName)/Contents/MacOS/\(helperExecutableName)"

    /// Absolute path of the nested helper .app inside the running host app bundle.
    static var helperAppPath: String {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons")
            .appendingPathComponent(helperAppName)
            .path
    }

    /// Absolute path of the helper executable inside the nested helper .app.
    static var helperBinaryPath: String {
        URL(fileURLWithPath: helperAppPath)
            .appendingPathComponent("Contents/MacOS")
            .appendingPathComponent(helperExecutableName)
            .path
    }

    /// Path to add in System Settings → Full Disk Access (the host app).
    static var fullDiskAccessTargetPath: String {
        Bundle.main.bundlePath
    }
}
