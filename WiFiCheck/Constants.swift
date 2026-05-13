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

    /// Networksetup command line utility path
    static let networksetupPath = "/usr/sbin/networksetup"

    /// Airport framework utility path (optional, for advanced features)
    static let airportCommandPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
}
