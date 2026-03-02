//
//  WiFiDataManager.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import Foundation
import AppKit

class WiFiDataManager {

    static let shared = WiFiDataManager()

    fileprivate let systemConfigurationFolder: String = "/Library/Preferences"
    fileprivate let wifiKnownNetworksFile: String = "com.apple.wifi.known-networks.plist"

    // Computed property for full file path
    private var wifiKnownNetworksPath: String {
        return systemConfigurationFolder + "/" + wifiKnownNetworksFile
    }

    // Known PLIST Keys
    
    let AddReason = "AddReason"
    let AddedAt = "AddedAt"
    
    let CaptiveProfile = "CaptiveProfile"
    let CaptiveNetwork = "CaptiveNetwork"
    let CaptiveWebSheetLoginDate = "CaptiveWebSheetLoginDate"
    let Hidden = "Hidden"
    
    let JoinedBySystemAt = "JoinedBySystemAt"
    let JoinedByUserAt = "JoinedByUserAt"
    
    let SSID = "SSID"
    let SupportedSecurityTypes = "SupportedSecurityTypes"
    let WEPSubtype = "WEPSubtype"
    let SystemMode = "SystemMode"
    let UpdatedAt = "UpdatedAt"
    
    let __OSSpecific__ = "__OSSpecific__"
    let BSSIDList = "BSSIDList"
    let LEAKY_AP_BSSID = "LEAKY_AP_BSSID"
    let LEAKY_AP_LEARNED_DATA = "LEAKY_AP_LEARNED_DATA"
    
    let ChannelHistory = "ChannelHistory"
    let Channel = "Channel"
    let Timestamp = "Timestamp"
    
    let CollocatedGroup = "CollocatedGroup"
    
    let RoamingProfileType = "RoamingProfileType"
    let TemporarilyDisabled = "TemporarilyDisabled"
    let UserPreferredOrderTimestamp = "UserPreferredOrderTimestamp"
    let WasHiddenBefore = "WasHiddenBefore"
    
    
    var wifidatalist: Array<WiFiData> = Array<WiFiData>()

    init() {
        // Validate system paths exist
        validateSystemPaths()

        // Try to load WiFi data if accessible
        if FileManager.default.isReadableFile(atPath: wifiKnownNetworksPath) {
            reloadData()
        } else {
            print("Unable to load \(wifiKnownNetworksFile) - need to get user permissions")
        }
    }

    /// Validates that required system paths exist
    private func validateSystemPaths() {
        let fileManager = FileManager.default

        // Check if system configuration folder exists
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: systemConfigurationFolder, isDirectory: &isDirectory) {
            print("ERROR: System configuration folder not found at: \(systemConfigurationFolder)")
            print("This is a critical system folder. Your macOS installation may be corrupted.")
        } else if !isDirectory.boolValue {
            print("ERROR: Expected directory at: \(systemConfigurationFolder), but found a file instead.")
        }

        // Check if WiFi known networks file exists (may not exist until user has connected to WiFi)
        let fullPath = wifiKnownNetworksPath
        if !fileManager.fileExists(atPath: fullPath) {
            print("INFO: WiFi known networks file not found at: \(fullPath)")
            print("This file will be created when you connect to a WiFi network, or may require administrator access.")
        } else if !fileManager.isReadableFile(atPath: fullPath) {
            print("INFO: WiFi known networks file exists but is not readable: \(fullPath)")
            print("You will need to grant administrator access to read this file.")
        }
    }
    
    func reloadData() {
        wifidatalist = load(wifiKnownNetworksPath)
        wifidatalist = sortByPreferredOrder()
    }
    
    
    func getWiFiDataList() -> Array<WiFiData> {
        return wifidatalist
    }
    
    fileprivate func findBool(_ value: AnyObject?) -> Bool {
        guard let value = value, let result = value as? Bool else {
            return false
        }
        return result
    }

    fileprivate func findInt(_ value: AnyObject?) -> Int {
        guard let value = value, let result = value as? Int else {
            return -1
        }
        return result
    }

    fileprivate func findString(_ value: AnyObject?) -> String {
        guard let value = value, let result = value as? String else {
            return ""
        }
        return result
    }

    fileprivate func findDate(_ value: AnyObject?) -> Date? {
        guard let value = value else {
            return nil
        }
        return value as? Date
    }

    fileprivate func findData(_ value: AnyObject?) -> Data? {
        guard let value = value else {
            return nil
        }
        return value as? Data
    }
    
    
    fileprivate func findCaptiveProfile(_ value: AnyObject?) -> Array<WiFiData.CaptiveProfileData> {
        var cpList = Array<WiFiData.CaptiveProfileData>()
        guard let value = value, let dict = value as? Dictionary<String,AnyObject> else {
            return cpList
        }
        var cp = WiFiData.CaptiveProfileData()
        cp.CaptiveNetwork = findInt(dict[CaptiveNetwork])
        cp.CaptiveWebSheetLoginDate = findDate(dict[CaptiveWebSheetLoginDate])
        cpList.append(cp)
        return cpList
    }
    
    fileprivate func findBSSIDList(_ value: AnyObject?) -> Array<WiFiData.BSSIDData> {
        var bssidList = Array<WiFiData.BSSIDData>()
        guard let value = value, let arr = value as? Array<Dictionary<String,AnyObject>> else {
            return bssidList
        }
        for dict in arr {
            var bssid = WiFiData.BSSIDData()
            bssid.LEAKY_AP_BSSID = findString(dict[LEAKY_AP_BSSID])
            bssid.LEAKY_AP_LEARNED_DATA = findData(dict[LEAKY_AP_LEARNED_DATA]) ?? Data()
            // Manufacturer lookup not yet implemented
            bssid.Manufacturer = ""
            bssidList.append(bssid)
        }
        return bssidList
    }
    
    fileprivate func sortChannelHistory(_ items: [WiFiData.ChannelData]) -> [WiFiData.ChannelData] {
        items.sorted { a, b in
            return a.Timestamp.moreRecentThan(b.Timestamp)
        }
    }
    
    fileprivate func findChannelHistory(_ value: AnyObject?) -> Array<WiFiData.ChannelData> {
        var channelHistory = Array<WiFiData.ChannelData>()
        guard let value = value, let arr = value as? Array<Dictionary<String,AnyObject>> else {
            return channelHistory
        }
        for dict in arr {
            var chan = WiFiData.ChannelData()
            chan.Channel = findInt(dict[Channel])
            chan.Timestamp = findDate(dict[Timestamp]) ?? Date(timeIntervalSince1970: 0)
            channelHistory.append(chan)
        }
        return sortChannelHistory(channelHistory)
    }
    
    fileprivate func findCollocatedGroup(_ value: AnyObject?) -> Array<WiFiData.CollocatedGroupData> {
        var collocatedGroup = Array<WiFiData.CollocatedGroupData>()
        guard let value = value, let arr = value as? Array<String> else {
            return collocatedGroup
        }
        for str in arr {
            var cg = WiFiData.CollocatedGroupData()
            cg.ssid = parseWiFiSSID(str)
            collocatedGroup.append(cg)
        }
        return collocatedGroup
    }
    
    /// Parses Apple's internal WiFi SSID format into a human-readable SSID string.
    ///
    /// Apple stores WiFi SSIDs in the known networks plist using a special format where the SSID
    /// is encoded as hexadecimal values within angle brackets. This function decodes that format.
    ///
    /// **Format Details:**
    /// - Input: `"wifi.ssid.<hexdata>"`
    /// - The hexdata section contains pairs of hex digits representing ASCII/Unicode characters
    /// - Format: `<4D7946726565 57696669>` where spaces are optional separators
    /// - Each pair of hex digits (e.g., "4D") represents one character
    ///
    /// **Example:**
    /// ```
    /// Input:  "wifi.ssid.<4D7946726565 57696669>"
    /// Decode: 4D=M, 79=y, 46=F, 72=r, 65=e, 65=e, 57=W, 69=i, 66=f, 69=i
    /// Output: "MyFreeWifi"
    /// ```
    ///
    /// **Algorithm:**
    /// 1. Remove the "wifi.ssid." prefix (first 10 characters)
    /// 2. Iterate through remaining characters
    /// 3. Skip '<', '>', and space characters
    /// 4. Collect hex digits in pairs (two characters at a time)
    /// 5. Convert each hex pair to its corresponding Unicode character
    /// 6. Build the final SSID string from the decoded characters
    ///
    /// - Parameter appleWiFiID: The Apple plist key in format "wifi.ssid.<hexdata>"
    /// - Returns: The decoded SSID string, or the original input if not in Apple's format
    func parseWiFiSSID(_ appleWiFiID: String) -> String {
        // Check if this is an Apple WiFi SSID format (starts with "wifi.ssid.")
        if (appleWiFiID.hasPrefix("wifi.ssid.")) {
            // Strip the "wifi.ssid." prefix (10 characters)
            let index = appleWiFiID.index(appleWiFiID.startIndex, offsetBy: 10)
            let preSSID = String(appleWiFiID[index...])
            // preSSID now contains the hex-encoded data like: <4D7946726565 57696669>

            var parsedSSID = ""      // Final decoded SSID
            var intSSID = ""         // Temporary storage for hex pair (e.g., "4D")
            var count = 0            // Counter for hex digits (0, 1, or 2)

            // Process each character in the hex string
            for ch in preSSID {
                count = count + 1

                if (ch == "<") {
                    // Opening angle bracket - marks start of hex data
                    count = 0
                } else if (ch == " ") {
                    // Space separator - skip it
                    count = 0
                } else if (ch == ">") {
                    // Closing angle bracket - marks end of hex data
                    count = 0
                } else {
                    // Processing hex digits
                    if count == 1 {
                        // First hex digit of the pair
                        intSSID = "\(ch)"
                    } else if count == 2 {
                        // Second hex digit of the pair - now convert to character
                        intSSID = "\(intSSID)\(ch)"
                        count = 0

                        // Convert hex string to integer, then to Unicode character
                        if let hexValue = Int(intSSID, radix: 16),
                           let unicodeScalar = UnicodeScalar(hexValue) {
                            let asciiToChar = Character(unicodeScalar)
                            parsedSSID = "\(parsedSSID)\(asciiToChar)"
                        }
                        // Note: Invalid hex values are silently skipped
                    }
                }
            }
            return parsedSSID
        }
        // Not in Apple's format - return as-is
        return appleWiFiID
    }

    func sortByPreferredOrder() -> [WiFiData] {
        wifidatalist.sorted { a, b in
            return a.PreferredOrder < b.PreferredOrder
        }
    }
    
    func sortByRecentUser() -> [WiFiData] {
        wifidatalist.sorted { a, b in
            if a.joinedByUserAt() == b.joinedByUserAt() {
                if a.joinedBySystemAt() == b.joinedBySystemAt() {
                    if a.addedAt() == b.addedAt() {
                        return a.ssidString() < b.ssidString()
                    } else {
                        return a.addedAt().moreRecentThan(b.addedAt())
                    }
                } else {
                    return a.joinedBySystemAt().moreRecentThan(b.joinedBySystemAt())
                }
            } else {
                return a.joinedByUserAt().moreRecentThan(b.joinedByUserAt())
            }
        }
    }
    
    func sortByRecentSystem() -> [WiFiData] {
        wifidatalist.sorted { a, b in
            if a.joinedBySystemAt() == b.joinedBySystemAt() {
                if a.joinedByUserAt() == b.joinedByUserAt() {
                    if a.addedAt() == b.addedAt() {
                        return a.ssidString() < b.ssidString()
                    } else {
                        return a.addedAt().moreRecentThan(b.addedAt())
                    }
                } else {
                    return a.joinedByUserAt().moreRecentThan(b.joinedByUserAt())
                }
            } else {
                return a.joinedBySystemAt().moreRecentThan(b.joinedBySystemAt())
            }
        }
    }
    
    func sortByAlphabetical() -> [WiFiData] {
        wifidatalist.sorted { a, b in
            var res = false
            res = a.ssidString().lowercased() < b.ssidString().lowercased()
            return res
        }
    }
    
    func needsPassword() -> Bool {
        let need = !FileManager.default.isReadableFile(atPath: wifiKnownNetworksPath)
        if !need {
            reloadData()
        }
        return need
    }

    /// Checks if the app has direct access to read the WiFi preferences file
    /// - Returns: true if the app can read the file without admin privileges
    func hasDirectAccess() -> Bool {
        return FileManager.default.isReadableFile(atPath: wifiKnownNetworksPath)
    }


    /// Attempts to load WiFi data - requires Full Disk Access
    /// - Returns: true if data was successfully loaded, false if Full Disk Access needed
    func requestFilePermissions() -> Bool {
        // Try direct access (requires Full Disk Access to be granted)
        if hasDirectAccess() {
            print("Full Disk Access granted - loading data directly")
            reloadData()
            return wifidatalist.count > 0
        }

        print("")
        print("⚠️  WiFi/Check does not have Full Disk Access")
        print("")
        print("The WiFi preferences file is protected by System Integrity Protection.")
        print("Even administrator privileges cannot bypass this protection.")
        print("")
        print("To grant Full Disk Access:")
        print("1. Click 'Open System Settings' in the alert")
        print("2. Click the lock icon and enter your password")
        print("3. Click the '+' button")
        print("4. Navigate to Applications and select WiFi/Check.app")
        print("5. Quit and relaunch WiFi/Check")
        print("6. Click 'Check Access' again")
        print("")

        return false
    }

    /// Opens System Settings to the Full Disk Access pane
    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    /// Parses WiFi data from raw plist data
    /// - Parameter data: Raw plist data to parse
    /// - Returns: Array of WiFiData objects
    private func parseWiFiData(from data: Data) -> Array<WiFiData> {
        // Parse property list with proper error handling
        let _rawContent: Any
        do {
            _rawContent = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil)
        } catch {
            print("Error parsing property list: \(error.localizedDescription)")
            return Array<WiFiData>()
        }

        let preferredNetworks: Dictionary<String,Int> = NetworkSetup.shared.getPreferredNetworkOrder()

        var _knownNetworks: Array<WiFiData> = []

        guard let knownNetworks = _rawContent as? Dictionary<String,AnyObject> else {
            print("Error: Invalid property list format")
            return Array<WiFiData>()
        }

        for (wifiKey, valueDict) in knownNetworks {
            guard let value = valueDict as? Dictionary<String,AnyObject> else {
                print("Warning: Skipping invalid WiFi entry: \(wifiKey)")
                continue
            }

            var wifidata = WiFiData()
            wifidata.WiFiID = wifiKey
            wifidata.AddReason = findString(value[AddReason])
            wifidata.AddedAt = findDate(value[AddedAt])
            wifidata.CaptiveProfile = findCaptiveProfile(value[CaptiveProfile])
            wifidata.Hidden = findBool(value[Hidden])
            wifidata.JoinedBySystemAt = findDate(value[JoinedBySystemAt])
            wifidata.JoinedByUserAt = findDate(value[JoinedByUserAt])
            wifidata.SSID = findData(value[SSID])
            wifidata.SupportedSecurityTypes = findString(value[SupportedSecurityTypes])
            wifidata.WEPSubtype = findString(value[WEPSubtype])
            wifidata.SystemMode = findBool(value[SystemMode])
            wifidata.UpdatedAt = findDate(value[UpdatedAt])

            // Parse OS-specific data with error handling
            if let osvalue = value[__OSSpecific__] as? Dictionary<String,AnyObject> {
                wifidata.BSSIDList = findBSSIDList(osvalue[BSSIDList])
                wifidata.ChannelHistory = findChannelHistory(osvalue[ChannelHistory])
                wifidata.CollocatedGroup = findCollocatedGroup(osvalue[CollocatedGroup])
                wifidata.RoamingProfileType = findString(osvalue[RoamingProfileType])
                wifidata.TemporarilyDisabled = findBool(osvalue[TemporarilyDisabled])
                wifidata.UserPreferredOrderTimestamp = findDate(osvalue[UserPreferredOrderTimestamp])
                wifidata.WasHiddenBefore = findDate(osvalue[WasHiddenBefore])
            } else {
                print("Warning: Missing __OSSpecific__ data for network: \(wifiKey)")
            }

            // Set preferred order
            wifidata.PreferredOrder = preferredNetworks[wifidata.ssidString()] ?? Int.max

            _knownNetworks.append(wifidata)
        }
        return _knownNetworks
    }

    // Load data from file
    func load(_ filename: String) -> Array<WiFiData> {

        if !FileManager.default.isReadableFile(atPath: filename) {
            print("Error: File is not readable at path: \(filename)")
            return Array<WiFiData>()
        }

        let _fileurl = URL(fileURLWithPath: filename)

        // Load file data with proper error handling
        let _data: Data
        do {
            _data = try Data(contentsOf: _fileurl)
        } catch {
            print("Error reading file: \(error.localizedDescription)")
            return Array<WiFiData>()
        }

        return parseWiFiData(from: _data)
    }
    
}
