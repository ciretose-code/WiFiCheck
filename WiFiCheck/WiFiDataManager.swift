//
//  WiFiDataManager.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import Foundation
import AppKit
import os.log
import ServiceManagement

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
    let PasswordSharingDisabled = "PasswordSharingDisabled"
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
    let PrivacyProxyEnabled = "PrivacyProxyEnabled"
    let PrivateMACAddressEvaluationState = "PrivateMACAddressEvaluationState"
    let UserPreferredNetworkNames = "UserPreferredNetworkNames"

    // BSSList keys
    let BSSList = "BSSList"
    let BSSID = "BSSID"
    let ChannelFlags = "ChannelFlags"
    let LastAssociatedAt = "LastAssociatedAt"
    let AWDLRealTimeModeTimestamp = "AWDLRealTimeModeTimestamp"
    let DHCPServerID = "DHCPServerID"
    let IPv4NetworkSignature = "IPv4NetworkSignature"
    let IPv6NetworkSignature = "IPv6NetworkSignature"
    let DHCPv6ServerID = "DHCPv6ServerID"
    let Colocated5GHzRNRChannel = "colocated5GHzRNRChannel"
    let Colocated5GHzRNRChannelFlags = "colocated5GHzRNRChannelFlags"
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
    /// True when data was loaded from an arbitrary plist file (drag-and-drop or File > Open).
    /// False when loaded via the privileged helper (live system data).
    private(set) var isLoadedFromFile: Bool = false

    init() {
        validateSystemPaths()
        if hasDirectAccess() {
            reloadData()
        } else {
            Self.logger.info("Unable to load WiFi preferences - root access required")
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

    private func findStringArray(_ value: AnyObject?) -> [String] {
        guard let arr = value as? [String] else { return [] }
        return arr
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
            bss.DHCPv6ServerID = findData(dict[DHCPv6ServerID])
            bss.Colocated5GHzRNRChannel = findInt(dict[Colocated5GHzRNRChannel])
            bss.Colocated5GHzRNRChannelFlags = findInt(dict[Colocated5GHzRNRChannelFlags])
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
    /// - The hexdata section contains pairs of hex digits representing UTF-8 bytes
    /// - Format: `<4D7946726565 57696669>` where spaces are optional separators
    ///
    /// **Example:**
    /// ```
    /// Input:  "wifi.ssid.<4D7946726565 57696669>"
    /// Decode: 4D=M, 79=y, 46=F, 72=r, 65=e, 65=e, 57=W, 69=i, 66=f, 69=i
    /// Output: "MyFreeWifi"
    /// ```
    ///
    /// Bytes are accumulated as [UInt8] and decoded as UTF-8 at the end, so multi-byte
    /// characters (e.g. Chinese, Arabic, emoji) are handled correctly.
    ///
    /// - Parameter appleWiFiID: The Apple plist key in format "wifi.ssid.<hexdata>"
    /// - Returns: The decoded SSID string, or the original input if not in Apple's format
    func parseWiFiSSID(_ appleWiFiID: String) -> String {
        guard appleWiFiID.hasPrefix("wifi.ssid.") else {
            return appleWiFiID
        }

        let preSSID = String(appleWiFiID.dropFirst(10))
        var bytes = [UInt8]()
        var hexBuf = ""

        for ch in preSSID {
            switch ch {
            case "<", ">", " ":
                hexBuf = ""
            default:
                hexBuf.append(ch)
                if hexBuf.count == 2 {
                    if let byte = UInt8(hexBuf, radix: 16) {
                        bytes.append(byte)
                    }
                    hexBuf = ""
                }
            }
        }

        // Decode as UTF-8 first (handles multi-byte characters like emoji, CJK, etc.),
        // fall back to Latin-1 for legacy non-UTF-8 SSIDs, then return the original.
        return String(bytes: bytes, encoding: .utf8)
            ?? String(bytes: bytes, encoding: .isoLatin1)
            ?? appleWiFiID
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
        return !hasDirectAccess()
    }

    /// Checks if the app can actually open the WiFi preferences file.
    /// Uses a real open() attempt rather than access()/isReadableFile because the
    /// file is chmod 600 root:wheel — access() checks DAC and always returns false
    /// for non-root, even when Full Disk Access (MAC-layer override) has been granted.
    /// - Returns: true if the file can be read (FDA granted)
    func hasDirectAccess() -> Bool {
        guard let fh = FileHandle(forReadingAtPath: wifiKnownNetworksPath) else { return false }
        fh.closeFile()
        return true
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

        Self.logger.warning("WiFiCheck does not have Full Disk Access")
        Self.logger.info("The WiFi preferences file is protected by System Integrity Protection.")
        Self.logger.info("To read WiFi history: sudo cp /Library/Preferences/com.apple.wifi.known-networks.plist ~/Downloads/wifi-networks.plist")

        return false
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
            wifidata.PasswordSharingDisabled = findBool(value[PasswordSharingDisabled])
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
            wifidata.PrivacyProxyEnabled = findBool(value[PrivacyProxyEnabled])
            wifidata.PrivateMACAddressEvaluationState = findString(value[PrivateMACAddressEvaluationState])
            wifidata.UserPreferredNetworkNames = findStringArray(value[UserPreferredNetworkNames])

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
        isLoadedFromFile = true
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
        isLoadedFromFile = true
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

    // MARK: - Privileged Helper (SMAppService / Option 1)

    private static let kHelperMachService = "com.ciretose.macos.tool.WiFiCheck.helper"
    private static let kDaemonPlistName   = "com.ciretose.macos.tool.WiFiCheck.helper.plist"

    /// Current registration status of the privileged daemon.
    var helperStatus: SMAppService.Status {
        SMAppService.daemon(plistName: Self.kDaemonPlistName).status
    }

    /// Whether the privileged helper is installed and running.
    var helperIsRunning: Bool { helperStatus == .enabled }

    /// Register the daemon with the system (shows macOS admin-auth sheet).
    /// Calls `completion` on the main thread with success/failure.
    /// Must be called from the main thread — SMAppService presents UI.
    func installHelper(completion: @escaping (Bool, Error?) -> Void) {
        assert(Thread.isMainThread, "installHelper must be called on the main thread")

        let service = SMAppService.daemon(plistName: Self.kDaemonPlistName)
        let currentStatus = service.status
        Self.logger.info("SMAppService status before register: \(String(describing: currentStatus))")

        // Already running and the helper binary is where we expect it — nothing to do.
        if currentStatus == .enabled && helperBinaryExists {
            completion(true, nil)
            return
        }

        // If a stale registration exists (enabled with missing binary, or requiresApproval
        // from a prior install with a different bundle layout), unregister first so
        // register() installs the current bundle's plist fresh.
        if currentStatus == .enabled || currentStatus == .requiresApproval {
            Self.logger.info("Stale registration detected (status=\(currentStatus.rawValue)) — unregistering first")
            do {
                try service.unregister()
                Self.logger.info("Unregistered OK")
            } catch {
                // Unregister failing is non-fatal; attempt register() regardless.
                Self.logger.warning("Unregister failed (non-fatal): \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            try service.register()
            if service.status == .requiresApproval {
                Self.logger.info("Registered — requiresApproval, opening System Settings")
                SMAppService.openSystemSettingsLoginItems()
                completion(false, Self.requiresApprovalError)
            } else {
                completion(true, nil)
            }
        } catch {
            let nsErr = error as NSError
            if service.status == .requiresApproval {
                Self.logger.info("register() threw but status is requiresApproval — opening System Settings")
                SMAppService.openSystemSettingsLoginItems()
                completion(false, Self.requiresApprovalError)
            } else {
                Self.logger.error("register() failed: \(nsErr.domain) \(nsErr.code) — \(nsErr.localizedDescription)")
                completion(false, error)
            }
        }
    }

    /// `true` when the helper binary exists at the expected bundle-relative path.
    private var helperBinaryExists: Bool {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons")
            .appendingPathComponent(Self.kHelperMachService)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Sentinel error used to signal that the daemon is registered but needs
    /// user approval in System Settings → Privacy & Security → Login Items.
    static let requiresApprovalError = NSError(
        domain: "com.ciretose.wificheck.helperInstall",
        code: 100,
        userInfo: [NSLocalizedDescriptionKey:
            "The helper is registered and System Settings has been opened. " +
            "Enable WiFi Check under Privacy & Security → Login Items & Extensions, then click Install Helper again."]
    )

    /// Unregister the daemon (for debugging / uninstall).
    func uninstallHelper(completion: @escaping (Bool, Error?) -> Void) {
        let service = SMAppService.daemon(plistName: Self.kDaemonPlistName)
        do {
            try service.unregister()
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }

    /// Read the WiFi plist via the privileged helper over XPC.
    /// Calls `completion` on the main thread with the parsed networks and any error.
    func loadViaHelper(completion: @escaping ([WiFiData]?, Error?) -> Void) {
        let connection = NSXPCConnection(machServiceName: Self.kHelperMachService,
                                         options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: WiFiHelperProtocol.self)

        // Guard against completion being called more than once (timeout vs reply race).
        var finished = false
        let finish: ([WiFiData]?, Error?) -> Void = { result, error in
            guard !finished else { return }
            finished = true
            DispatchQueue.main.async { completion(result, error) }
        }

        connection.invalidationHandler = {
            Self.logger.error("XPC connection invalidated")
            finish(nil, nil)
        }
        connection.interruptionHandler = {
            Self.logger.error("XPC connection interrupted")
            finish(nil, nil)
        }
        connection.resume()

        // 15-second safety net so the spinner can never hang forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if !finished {
                Self.logger.error("XPC reply timed out after 15 s")
                connection.invalidate()
                finish(nil, nil)
            }
        }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            Self.logger.error("XPC proxy error: \(error.localizedDescription, privacy: .public)")
            connection.invalidate()
            finish(nil, error)
        }) as? WiFiHelperProtocol else {
            connection.invalidate()
            finish(nil, nil)
            return
        }

        proxy.readWifiPlist { data, error in
            connection.invalidate()
            guard let data = data else {
                Self.logger.error("Helper returned no data: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                finish(nil, error)
                return
            }
            let parsed = self.parseWiFiData(from: data)
            self.wifidatalist = parsed
            self.wifidatalist = self.sortByPreferredOrder()
            self.loadedFromDrop = true
            self.isLoadedFromFile = false
            finish(parsed, nil)
        }
    }

}
