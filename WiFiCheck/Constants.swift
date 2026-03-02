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

    // MARK: - Security

    /// Duration in seconds before auto-hiding displayed passwords
    static let passwordAutoHideDelay = 30

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
