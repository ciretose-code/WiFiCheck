//
//  WiFiDataManager.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import Foundation
import AppKit
import os.log

class WiFiDataManager {

    // MARK: - Logging

    private static let logger = Logger(subsystem: "com.ciretose.wificheck", category: "WiFiDataManager")

    static let shared = WiFiDataManager()

    fileprivate let systemConfigurationFolder: String = Constants.systemConfigurationFolder
    fileprivate let wifiKnownNetworksFile: String = Constants.wifiKnownNetworksFile

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
    let JoinedBySystemAtWeek = "JoinedBySystemAtWeek"
    let JoinedByUserAt = "JoinedByUserAt"
    
    let SSID = "SSID"
    let SupportedSecurityTypes = "SupportedSecurityTypes"
    let WEPSubtype = "WEPSubtype"
    let SystemMode = "SystemMode"
    let UpdatedAt = "UpdatedAt"

    // New top-level keys
    let BrokenBackhaulState = "BrokenBackhaulState"
    let BrokenBackhaulStateUpdatedAt = "BrokenBackhaulStateUdatedAt" // typo is in the plist
    let CachedPrivateMACAddress = "CachedPrivateMACAddress"
    let CachedPrivateMACAddressUpdatedAt = "CachedPrivateMACAddressUpdatedAt"
    let Is2GHzBssPresent = "is2GHzBssPresent"
    let LastDisconnectReason = "LastDisconnectReason"
    let LastDisconnectTimestamp = "LastDisconnectTimestamp"
    let LastDiscoveredAt = "LastDiscoveredAt"
    let Moving = "Moving"
    let PersonalHotspot = "PersonalHotspot"
    let PrivateMACAddressEvaluatedAt = "PrivateMACAddressEvaluatedAt"

    // BSSList keys
    let BSSList = "BSSList"
    let BSSID = "BSSID"
    let ChannelFlags = "ChannelFlags"
    let LastAssociatedAt = "LastAssociatedAt"
    let AWDLRealTimeModeTimestamp = "AWDLRealTimeModeTimestamp"
    let DHCPServerID = "DHCPServerID"
    let IPv4NetworkSignature = "IPv4NetworkSignature"
    let IPv6NetworkSignature = "IPv6NetworkSignature"
    let Location = "Location"
    let LocationLatitude = "LocationLatitude"
    let LocationLongitude = "LocationLongitude"
    let LocationAccuracy = "LocationAccuracy"
    let LocationTimestamp = "LocationTimestamp"
    
    let __OSSpecific__ = "__OSSpecific__"
    let ChannelHistory = "ChannelHistory"
    let Channel = "Channel"
    let Timestamp = "Timestamp"
    let CollocatedGroup = "CollocatedGroup"
    let RoamingProfileType = "RoamingProfileType"
    let TemporarilyDisabled = "TemporarilyDisabled"
    let UserPreferredOrderTimestamp = "UserPreferredOrderTimestamp"
    
    
    var wifidatalist: Array<WiFiData> = Array<WiFiData>()
    private(set) var loadedFromDrop: Bool = false

    init() {
        // Validate system paths exist
        validateSystemPaths()

        // Try to load WiFi data if accessible
        if FileManager.default.isReadableFile(atPath: wifiKnownNetworksPath) {
            reloadData()
        } else {
            Self.logger.info("Unable to load WiFi preferences - user permissions required")
        }
    }

    /// Validates that required system paths exist
    private func validateSystemPaths() {
        let fileManager = FileManager.default

        // Check if system configuration folder exists
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: systemConfigurationFolder, isDirectory: &isDirectory) {
            Self.logger.error("System configuration folder not found at: \(self.systemConfigurationFolder, privacy: .public)")
            Self.logger.error("This is a critical system folder. Your macOS installation may be corrupted.")
        } else if !isDirectory.boolValue {
            Self.logger.error("Expected directory at: \(self.systemConfigurationFolder, privacy: .public), but found a file instead.")
        }

        // Check if WiFi known networks file exists (may not exist until user has connected to WiFi)
        let fullPath = wifiKnownNetworksPath
        if !fileManager.fileExists(atPath: fullPath) {
            Self.logger.info("WiFi known networks file not found at: \(fullPath, privacy: .public)")
            Self.logger.info("This file will be created when you connect to a WiFi network, or may require administrator access.")
        } else if !fileManager.isReadableFile(atPath: fullPath) {
            Self.logger.info("WiFi known networks file exists but is not readable: \(fullPath, privacy: .public)")
            Self.logger.info("You will need to grant Full Disk Access to read this file.")
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
        cp.CaptiveNetwork = findBool(dict[CaptiveNetwork])
        cp.CaptiveWebSheetLoginDate = findDate(dict[CaptiveWebSheetLoginDate])
        cpList.append(cp)
        return cpList
    }

    fileprivate func findBSSList(_ value: AnyObject?) -> Array<WiFiData.BSSData> {
        var bssList = Array<WiFiData.BSSData>()
        guard let value = value, let arr = value as? Array<Dictionary<String,AnyObject>> else {
            return bssList
        }
        for dict in arr {
            var bss = WiFiData.BSSData()
            bss.BSSID = findString(dict[BSSID])
            bss.Channel = findInt(dict[Channel])
            bss.ChannelFlags = findInt(dict[ChannelFlags])
            bss.LastAssociatedAt = findDate(dict[LastAssociatedAt])
            bss.AWDLRealTimeModeTimestamp = findDate(dict[AWDLRealTimeModeTimestamp])
            bss.DHCPServerID = findData(dict[DHCPServerID])
            bss.IPv4NetworkSignature = findString(dict[IPv4NetworkSignature])
            bss.IPv6NetworkSignature = findString(dict[IPv6NetworkSignature])
            if let loc = dict[Location] as? Dictionary<String,AnyObject> {
                bss.LocationLatitude = loc[LocationLatitude] as? Double
                bss.LocationLongitude = loc[LocationLongitude] as? Double
                bss.LocationAccuracy = loc[LocationAccuracy] as? Double
                bss.LocationTimestamp = findDate(loc[LocationTimestamp])
            }
            bssList.append(bss)
        }
        return bssList
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

            var characters: [Character] = []  // Array to collect decoded characters (avoids O(n²) string concat)
            var intSSID = ""                   // Temporary storage for hex pair (e.g., "4D")
            var count = 0                      // Counter for hex digits (0, 1, or 2)

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
                            characters.append(Character(unicodeScalar))
                        }
                        // Note: Invalid hex values are silently skipped
                    }
                }
            }
            return String(characters)
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
            a.ssidString().lowercased() < b.ssidString().lowercased()
        }
    }
    
    func needsPassword() -> Bool {
        if loadedFromDrop { return false }
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
            Self.logger.info("Full Disk Access granted - loading data directly")
            reloadData()
            return wifidatalist.count > 0
        }

        Self.logger.warning("WiFi/Check does not have Full Disk Access")
        Self.logger.info("The WiFi preferences file is protected by System Integrity Protection.")
        Self.logger.info("To grant Full Disk Access: Open System Settings → Privacy & Security → Full Disk Access")

        return false
    }

    /// Opens System Settings to the Full Disk Access pane
    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    /// Opens the WiFi known networks plist file in its default application.
    /// Falls back to revealing it in Finder if it cannot be opened directly.
    func openKnownNetworksPlist() {
        let fileURL = URL(fileURLWithPath: wifiKnownNetworksPath)
        if !NSWorkspace.shared.open(fileURL) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        }
    }

    /// Reveals the WiFi known networks plist file in Finder.
    func revealKnownNetworksPlistInFinder() {
        let fileURL = URL(fileURLWithPath: wifiKnownNetworksPath)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
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
            Self.logger.error("Error parsing property list: \(error.localizedDescription, privacy: .public)")
            return Array<WiFiData>()
        }

        let preferredNetworks: Dictionary<String,Int> = NetworkSetup.shared.getPreferredNetworkOrder()

        var _knownNetworks: Array<WiFiData> = []

        guard let knownNetworks = _rawContent as? Dictionary<String,AnyObject> else {
            Self.logger.error("Invalid property list format")
            return Array<WiFiData>()
        }

        for (wifiKey, valueDict) in knownNetworks {
            guard let value = valueDict as? Dictionary<String,AnyObject> else {
                Self.logger.warning("Skipping invalid WiFi entry: \(wifiKey, privacy: .public)")
                continue
            }

            var wifidata = WiFiData()
            wifidata.WiFiID = wifiKey
            wifidata.AddReason = findString(value[AddReason])
            wifidata.AddedAt = findDate(value[AddedAt])
            wifidata.CaptiveProfile = findCaptiveProfile(value[CaptiveProfile])
            wifidata.Hidden = findBool(value[Hidden])
            wifidata.JoinedBySystemAt = findDate(value[JoinedBySystemAt])
            wifidata.JoinedBySystemAtWeek = findInt(value[JoinedBySystemAtWeek])
            wifidata.JoinedByUserAt = findDate(value[JoinedByUserAt])
            wifidata.SSID = findData(value[SSID])
            wifidata.SupportedSecurityTypes = findString(value[SupportedSecurityTypes])
            wifidata.WEPSubtype = findString(value[WEPSubtype])
            wifidata.SystemMode = findBool(value[SystemMode])
            wifidata.UpdatedAt = findDate(value[UpdatedAt])

            // New top-level fields
            wifidata.BrokenBackhaulState = findString(value[BrokenBackhaulState])
            wifidata.BrokenBackhaulStateUpdatedAt = findDate(value[BrokenBackhaulStateUpdatedAt])
            wifidata.CachedPrivateMACAddress = findString(value[CachedPrivateMACAddress])
            wifidata.CachedPrivateMACAddressUpdatedAt = findDate(value[CachedPrivateMACAddressUpdatedAt])
            wifidata.is2GHzBssPresent = findBool(value[Is2GHzBssPresent])
            wifidata.LastDisconnectReason = findInt(value[LastDisconnectReason])
            wifidata.LastDisconnectTimestamp = findDate(value[LastDisconnectTimestamp])
            wifidata.LastDiscoveredAt = findDate(value[LastDiscoveredAt])
            wifidata.Moving = findBool(value[Moving])
            wifidata.PersonalHotspot = findBool(value[PersonalHotspot])
            wifidata.PrivateMACAddressEvaluatedAt = findDate(value[PrivateMACAddressEvaluatedAt])

            // BSSList — top-level array of access points
            wifidata.BSSList = findBSSList(value[BSSList])

            // __OSSpecific__ fields
            if let osvalue = value[__OSSpecific__] as? Dictionary<String,AnyObject> {
                wifidata.ChannelHistory = findChannelHistory(osvalue[ChannelHistory])
                wifidata.CollocatedGroup = findCollocatedGroup(osvalue[CollocatedGroup])
                wifidata.RoamingProfileType = findString(osvalue[RoamingProfileType])
                wifidata.TemporarilyDisabled = findBool(osvalue[TemporarilyDisabled])
                wifidata.UserPreferredOrderTimestamp = findDate(osvalue[UserPreferredOrderTimestamp])
            } else {
                Self.logger.warning("Missing __OSSpecific__ data for network: \(wifiKey, privacy: .public)")
            }

            // Set preferred order
            wifidata.PreferredOrder = preferredNetworks[wifidata.ssidString()] ?? Int.max

            _knownNetworks.append(wifidata)
        }
        return _knownNetworks
    }

    /// Loads WiFi data from raw plist Data delivered by a drag-and-drop provider.
    /// - Parameter data: Raw plist bytes.
    /// - Returns: `true` if at least one network was parsed.
    @discardableResult
    func parseDroppedData(_ data: Data) -> Bool {
        let parsed = parseWiFiData(from: data)
        guard !parsed.isEmpty else {
            Self.logger.warning("parseDroppedData: no networks found in dropped data")
            return false
        }
        wifidatalist = parsed
        wifidatalist = sortByPreferredOrder()
        loadedFromDrop = true
        Self.logger.info("parseDroppedData: loaded \(parsed.count, privacy: .public) networks")
        return true
    }

    /// Loads WiFi data from an arbitrary plist file URL (e.g. drag-and-dropped file).
    /// - Parameter url: The file URL to load from.
    /// - Returns: `true` if the file was parsed successfully and contained at least one network.
    @discardableResult
    func loadFromURL(_ url: URL) -> Bool {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            Self.logger.error("loadFromURL: failed to read \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        let parsed = parseWiFiData(from: data)
        guard !parsed.isEmpty else {
            Self.logger.warning("loadFromURL: no networks found in \(url.path, privacy: .public)")
            return false
        }
        wifidatalist = parsed
        wifidatalist = sortByPreferredOrder()
        loadedFromDrop = true
        Self.logger.info("loadFromURL: loaded \(parsed.count, privacy: .public) networks from \(url.path, privacy: .public)")
        return true
    }

    // Load data from file
    func load(_ filename: String) -> Array<WiFiData> {

        if !FileManager.default.isReadableFile(atPath: filename) {
            Self.logger.error("File is not readable at path: \(filename, privacy: .public)")
            return Array<WiFiData>()
        }

        let _fileurl = URL(fileURLWithPath: filename)

        // Load file data with proper error handling
        let _data: Data
        do {
            _data = try Data(contentsOf: _fileurl)
        } catch {
            Self.logger.error("Error reading file: \(error.localizedDescription, privacy: .public)")
            return Array<WiFiData>()
        }

        return parseWiFiData(from: _data)
    }
    
}
