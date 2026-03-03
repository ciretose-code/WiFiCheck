//
//  NetworkSetup.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/23/21.
//

import Foundation
import os.log

class NetworkSetup {

    private static let logger = Logger(subsystem: "com.ciretose.wificheck", category: "NetworkSetup")

    static let shared = NetworkSetup()

    fileprivate let airportCommand: String = Constants.airportCommandPath

    private let networksetup: String = Constants.networksetupPath
    private var devicename: String = Constants.defaultWiFiDevice
    private let wifiservice: String = Constants.wifiServiceName

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
    /// Queries the system using `networksetup -listallhardwareports` to find the actual WiFi device name.
    /// On most Macs this is "en0", but it can vary. The detected device name is stored in `devicename`.
    ///
    /// This method parses the output looking for a line containing "Hardware Port" and "Wi-Fi",
    /// then extracts the device name from the following "Device:" line.
    private func setWiFiDevice() {
        var output: String = ""

        do {
            output = try Utils.runCommand(networksetup, withArgs: ["-listallhardwareports"])
        } catch let e as RuntimeError {
            Self.logger.error("RuntimeError: \(String(describing: e.kind), privacy: .public) - \(e.message, privacy: .public)")
        } catch {
            Self.logger.error("Error: \(error.localizedDescription, privacy: .public)")
        }

        if !output.isEmpty {
            let networks = output.components(separatedBy: .newlines).dropFirst()
            var getNext: Bool = false
            for network in networks {
                let n = network.trimmingCharacters(in: .whitespacesAndNewlines)
                if getNext {
                    if let range = n.range(of: "Device:") {
                        let d = n[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                        devicename = d
                    }
                    getNext = false
                }
                if n.contains("Hardware Port") && n.contains("Wi-Fi") {
                    getNext = true
                }
            }
        }
    }

    /// Retrieves the currently connected WiFi network SSID
    ///
    /// Executes `networksetup -getairportnetwork <device>` to query the active WiFi connection.
    /// If the device is not connected to WiFi, returns an empty string.
    ///
    /// - Returns: The SSID of the currently connected network, or an empty string if not connected or on error
    func getAirportNetwork() -> String {
        var ssid: String = ""
        var output: String = ""

        do {
            output = try Utils.runCommand(networksetup, withArgs: ["-getairportnetwork", devicename])
        } catch let e as RuntimeError {
            Self.logger.error("RuntimeError: \(String(describing: e.kind), privacy: .public) - \(e.message, privacy: .public)")
            return ssid
        } catch {
            Self.logger.error("Error: \(error.localizedDescription, privacy: .public)")
            return ssid
        }

        if !output.isEmpty {
            if let range = output.range(of: "Network:") {
                let outstr = output[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                ssid = outstr
            }
        }
        return ssid

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

        if !output.isEmpty {
            let networks = output.components(separatedBy: .newlines).dropFirst()
            var i = Constants.networkOrderIncrement
            for network in networks {
                let n = network.trimmingCharacters(in: .whitespacesAndNewlines)
                prefWiFi[n] = i
                i += Constants.networkOrderIncrement
            }
        }
        return prefWiFi
    }
    
    /// Removes a WiFi network from the system's list of known networks
    ///
    /// Executes `networksetup -removepreferredwirelessnetwork <device> <network>` to delete the
    /// specified network from the user's saved networks. This removes the network's stored password
    /// from the keychain and prevents automatic reconnection.
    ///
    /// **Security:** This method validates input to prevent command injection attacks by rejecting
    /// network names containing shell metacharacters (`;|&$\`<>()[]{}*?~!`).
    ///
    /// - Parameter network: The SSID of the network to remove
    /// - Returns: `true` if the network was successfully removed, `false` if the operation failed,
    ///            the network doesn't exist, or the network name contains invalid characters
    func deleteNetwork(_ network: String) -> Bool {
        // Input validation to prevent command injection
        // Network SSIDs should not contain shell metacharacters
        let dangerousCharacters = CharacterSet(charactersIn: ";|&$`<>()[]{}*?~!")
        if network.rangeOfCharacter(from: dangerousCharacters) != nil {
            Self.logger.error("Invalid network name contains dangerous characters: \(network, privacy: .public)")
            return false
        }

        // Additional validation: network name should not be empty
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
