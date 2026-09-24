//
//  NetworkSetup.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/23/21.
//

import Foundation
import CoreWLAN
import os.log

class NetworkSetup {

    private static let logger = Logger(subsystem: "com.ciretose.wificheck", category: "NetworkSetup")

    static let shared = NetworkSetup()

    fileprivate let airportCommand: String = Constants.airportCommandPath

    private let networksetup: String = Constants.networksetupPath
    private var devicename: String = Constants.defaultWiFiDevice
    private let wifiservice: String = Constants.wifiServiceName

    /// CoreWLAN Wi-Fi interface used for the BSD device name and current SSID.
    private func wifiInterface() -> CWInterface? {
        let client = CWWiFiClient.shared()
        if let named = client.interface(withName: devicename) {
            return named
        }
        if let primary = client.interface() {
            return primary
        }
        return client.interfaces()?.first
    }

    init() {
        // Validate system paths exist
        validateSystemPaths()

        // Load the network setup
        // Get the device name
        setWiFiDevice()
    }

    /// Validates that required system command paths exist
    private func validateSystemPaths() {
        let fileManager = FileManager.default

        // Check networksetup command (required)
        if !fileManager.fileExists(atPath: networksetup) {
            Self.logger.error("networksetup command not found at: \(self.networksetup, privacy: .public)")
            Self.logger.error("This is a critical system utility. Your macOS installation may be corrupted.")
        }

        // Check airport command (optional, for advanced features)
        if !fileManager.fileExists(atPath: airportCommand) {
            Self.logger.warning("airport command not found at: \(self.airportCommand, privacy: .public)")
            Self.logger.info("Some advanced WiFi features may not be available. This path may have changed in your macOS version.")
        }
    }

    /// Detects and sets the WiFi network interface device name
    ///
    /// Uses CoreWLAN (`CWWiFiClient`) to read the BSD interface name (typically "en0").
    /// This avoids parsing localized `networksetup -listallhardwareports` labels.
    private func setWiFiDevice() {
        let client = CWWiFiClient.shared()
        let iface = client.interface() ?? client.interfaces()?.first
        if let name = iface?.interfaceName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            devicename = name
            return
        }
        Self.logger.warning("Unable to determine Wi-Fi interface via CoreWLAN; using default \(Constants.defaultWiFiDevice, privacy: .public)")
    }

    /// Retrieves the currently connected WiFi network SSID
    ///
    /// Uses CoreWLAN (`CWInterface.ssid()`) instead of parsing
    /// `networksetup -getairportnetwork` output, which uses a localized "Network:" label.
    ///
    /// - Returns: The SSID of the currently connected network, or an empty string if not connected or on error
    func getAirportNetwork() -> String {
        return wifiInterface()?.ssid() ?? ""
    }
    
    /// Retrieves the user's preferred WiFi network ordering from system preferences
    ///
    /// Executes `networksetup -listpreferredwirelessnetworks <device>` to get the list of known WiFi
    /// networks in the user's preferred connection order. Networks are assigned integer values in
    /// increments of 100 (e.g., 100, 200, 300...) to represent their priority order.
    ///
    /// The ordering determines which network macOS will automatically connect to when multiple
    /// known networks are available.
    ///
    /// - Returns: Dictionary mapping network SSID to priority value (lower = higher priority)
    func getPreferredNetworkOrder() -> Dictionary<String,Int> {

        var prefWiFi: Dictionary<String,Int> = [:]
        var output: String = ""

        do {
            output = try Utils.runCommand(networksetup, withArgs: ["-listpreferredwirelessnetworks", devicename])
        } catch let e as RuntimeError {
            Self.logger.error("RuntimeError: \(String(describing: e.kind), privacy: .public) - \(e.message, privacy: .public)")
            return prefWiFi
        } catch {
            Self.logger.error("Error: \(error.localizedDescription, privacy: .public)")
            return prefWiFi
        }

        return Self.preferredNetworkOrder(from: output)
    }

    /// Parses `networksetup -listpreferredwirelessnetworks` stdout without matching localized labels.
    ///
    /// The first content line is a header in the current locale. SSIDs follow, usually tab-indented.
    /// A missing or empty header is not treated as a parse failure.
    static func preferredNetworkOrder(from output: String) -> Dictionary<String, Int> {
        var prefWiFi: Dictionary<String, Int> = [:]
        guard !output.isEmpty else { return prefWiFi }

        var lines = output.components(separatedBy: .newlines)
        // Skip leading blank lines so an empty header translation is not a failure
        while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeFirst()
        }
        // Skip one unindented header line when present; indented first line is an SSID
        if let first = lines.first, first.first != "\t", first.first != " " {
            lines.removeFirst()
        }

        var i = Constants.networkOrderIncrement
        for network in lines {
            let n = network.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty else { continue }
            prefWiFi[n] = i
            i += Constants.networkOrderIncrement
        }
        return prefWiFi
    }
    
    /// Removes a WiFi network from the system's list of known networks
    ///
    /// Executes `networksetup -removepreferredwirelessnetwork <device> <network>` to delete the
    /// specified network from the user's saved networks. This removes the network's stored password
    /// from the keychain and prevents automatic reconnection.
    ///
    /// Arguments are passed directly to `Process` (not through a shell), so no shell injection
    /// is possible and no character filtering is needed. Valid SSIDs containing parentheses,
    /// asterisks, or other special characters are handled correctly.
    ///
    /// - Parameter network: The SSID of the network to remove
    /// - Returns: `true` if the network was successfully removed, `false` otherwise
    func deleteNetwork(_ network: String) -> Bool {
        // Validate that the network name is not empty
        guard !network.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.logger.error("Network name is empty")
            return false
        }

        var output: String = ""
        do {
            output = try Utils.runCommand(networksetup, withArgs: ["-removepreferredwirelessnetwork", devicename, network])
        } catch let e as RuntimeError {
            Self.logger.error("RuntimeError: \(String(describing: e.kind), privacy: .public) - \(e.message, privacy: .public)")
            return false
        } catch {
            Self.logger.error("Error: \(error.localizedDescription, privacy: .public)")
            return false
        }
        if !output.isEmpty {
            if output.contains("Removed") {
                return true
            }
        }
        return false
    }
}
