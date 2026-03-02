//
//  WiFiDataManager.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import Foundation

class WiFiDataManager {
    
    static let shared = WiFiDataManager()

    fileprivate let systemConfigurationFolder: String = "/Library/Preferences"
    fileprivate let wifiKnownNetworksFile: String = "com.apple.wifi.known-networks.plist"
    
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
        if FileManager.default.isReadableFile(atPath: systemConfigurationFolder+"/"+wifiKnownNetworksFile) {
            reloadData()
        } else {
            print("Unable to load \(wifiKnownNetworksFile) - need to get user permissions")
        }
    }
    
    func reloadData() {
        wifidatalist = load(systemConfigurationFolder+"/"+wifiKnownNetworksFile)
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
    
    // Convert the airport plist id to an SSID
    func parseWiFiSSID(_ appleWiFiID: String) -> String {
        // Parse the Apple Plist Key into the SSID
        if (appleWiFiID.hasPrefix("wifi.ssid.")) {
            let index = appleWiFiID.index(appleWiFiID.startIndex, offsetBy: 10)
            let preSSID = String(appleWiFiID[index...])
            // preSSID now should look like <65776545 88776655>
            // This is now raw ascii that we'll need to convert to a string
            var parsedSSID = ""
            var intSSID = ""
            var count = 0
            for ch in preSSID {
                count = count + 1
                if (ch == "<") {
                    // Starting char
                    count = 0
                } else if (ch == " ") {
                    // Skip
                    count = 0
                } else if (ch == ">") {
                    // Last char
                    count = 0
                } else {
                    if count == 1 {
                        intSSID = "\(ch)"
                    } else if count == 2 {
                        intSSID = "\(intSSID)\(ch)"
                        count = 0
                        if let hexValue = Int(intSSID, radix: 16),
                           let unicodeScalar = UnicodeScalar(hexValue) {
                            let asciiToChar = Character(unicodeScalar)
                            parsedSSID = "\(parsedSSID)\(asciiToChar)"
                        }
                    }
                }
            }
            return parsedSSID
        }
        return appleWiFiID
    }
    
    
    //class WiFiIdentifier: Equatable {
    //    let wifiKey: String
    //    static func == (lhs: WiFiIdentifier, rhs: WiFiIdentifier) -> Bool { lhs.wifiKey == rhs.wifiKey }
    //    init(_ wifiKey: String) { self.wifiKey = wifiKey }
    //}
    
    
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
        let need = !FileManager.default.isReadableFile(atPath: systemConfigurationFolder+"/"+wifiKnownNetworksFile)
        if !need {
            reloadData()
        }
        return need
    }
    
    /// New async version with completion handler to avoid blocking the UI thread.
//    func isWiFiFileReadable(atPath filename: String, withPassword password: String? = nil, completion: @escaping (Bool) -> Void) {
//        if !FileManager.default.isReadableFile(atPath: filename) {
//            DispatchQueue.global(qos: .userInitiated).async {
//                var errorInfo: NSDictionary?
//                let script: NSAppleScript?
//                if let password = password {
//                    script = NSAppleScript(source: """
//                    do shell script "chmod 644 \(filename)" password "\(password)" with administrator privileges
//                    """)
//                } else {
//                    script = NSAppleScript(source: """
//                    do shell script "chmod 644 \(filename)" with administrator privileges
//                    """)
//                }
//                _ = script?.executeAndReturnError(&errorInfo)
//                DispatchQueue.main.async {
//                    completion(errorInfo == nil)
//                }
//            }
//        } else {
//            completion(true)
//        }
//    }
    
    
    
    // Load data
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

        // Parse property list with proper error handling
        let _rawContent: Any
        do {
            _rawContent = try PropertyListSerialization.propertyList(from: _data, options: .mutableContainersAndLeaves, format: nil)
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
    
}
