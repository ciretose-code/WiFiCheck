//
//  NetworkSetup.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/23/21.
//

import Foundation

class NetworkSetup {

    static let shared = NetworkSetup()

    fileprivate let airportCommand: String = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

    private let networksetup: String = "/usr/sbin/networksetup"
    private var devicename: String = "en0"
    private let wifiservice: String = "Wi-Fi"

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
            print("ERROR: networksetup command not found at: \(networksetup)")
            print("This is a critical system utility. Your macOS installation may be corrupted.")
        }

        // Check airport command (optional, for advanced features)
        if !fileManager.fileExists(atPath: airportCommand) {
            print("WARNING: airport command not found at: \(airportCommand)")
            print("Some advanced WiFi features may not be available. This path may have changed in your macOS version.")
        }
    }

    private func setWiFiDevice() {
        var output: String = ""
        
        do {
            output = try Utils.runCommand(networksetup, withArgs: ["-listallhardwareports"])
        } catch let e as RuntimeError {
            print("RuntimeError: \(e.kind) - \(e.message)")
        } catch {
            print("Error: \(error))")
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

    func getAirportNetwork() -> String {
        var ssid: String = ""
        var output: String = ""
        
        do {
            output = try Utils.runCommand(networksetup, withArgs: ["-getairportnetwork", devicename])
        } catch let e as RuntimeError {
            print("RuntimeError: \(e.kind) - \(e.message)")
            return ssid
        } catch {
            print("Error: \(error))")
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
    
    func getPreferredNetworkOrder() -> Dictionary<String,Int> {

        var prefWiFi: Dictionary<String,Int> = [:]
        var output: String = ""
        
        do {
            output = try Utils.runCommand(networksetup, withArgs: ["-listpreferredwirelessnetworks", devicename])
        } catch let e as RuntimeError {
            print("RuntimeError: \(e.kind) - \(e.message)")
            return prefWiFi
        } catch {
            print("Error: \(error))")
            return prefWiFi
        }
        
        if !output.isEmpty {
            let networks = output.components(separatedBy: .newlines).dropFirst()
            var i = 100
            for network in networks {
                let n = network.trimmingCharacters(in: .whitespacesAndNewlines)
                prefWiFi[n] = i
                i = i+100
            }
        }
        return prefWiFi
    }
    
    func deleteNetwork(_ network: String) -> Bool {
        var output: String = ""
        do {
            output = try Utils.runCommand(networksetup, withArgs: ["-removepreferredwirelessnetwork", devicename, network])
        } catch let e as RuntimeError {
            print("RuntimeError: \(e.kind) - \(e.message)")
            return false
        } catch {
            print("Error: \(error))")
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
