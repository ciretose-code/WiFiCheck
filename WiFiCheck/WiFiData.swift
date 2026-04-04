//
//  WiFiData.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import Foundation
import SwiftUI

struct WiFiData: Hashable, Codable, Identifiable {

    var id: String { WiFiID }

    var WiFiID: String = "InvalidID"
    var AddReason: String = ""
    var AddedAt: Date? = nil
    var CaptiveProfile: Array<CaptiveProfileData> = []
    
    var PasswordSharingDisabled: Bool = true
    var Hidden: Bool = false
    
    var JoinedBySystemAt: Date? = nil
    var JoinedBySystemAtWeek: Int = -1
    var JoinedByUserAt: Date? = nil
    
    var SSID: Data? = nil
    var SupportedSecurityTypes: String = ""
    var WEPSubtype: String = ""
    var SystemMode: Bool = false
    var UpdatedAt: Date? = nil

    // New top-level fields from real plist
    var BrokenBackhaulState: String = ""
    var BrokenBackhaulStateUpdatedAt: Date? = nil
    var CachedPrivateMACAddress: String = ""
    var CachedPrivateMACAddressUpdatedAt: Date? = nil
    var is2GHzBssPresent: Bool = false
    var LastDisconnectReason: Int = -1
    var LastDisconnectTimestamp: Date? = nil
    var LastDiscoveredAt: Date? = nil
    var Moving: Bool = false
    var PersonalHotspot: Bool = false
    var PrivateMACAddressEvaluatedAt: Date? = nil
    var PrivacyProxyEnabled: Bool = false
    var PrivateMACAddressEvaluationState: String = ""
    var UserPreferredNetworkNames: [String] = []

    // BSSList — top-level array in the real plist
    var BSSList: Array<BSSData> = []

    // __OSSpecific__ fields
    var ChannelHistory: Array<ChannelData> = []
    var CollocatedGroup: Array<CollocatedGroupData> = []
    var RoamingProfileType: String = ""
    var TemporarilyDisabled: Bool = false
    var UserPreferredOrderTimestamp: Date? = nil

    var PreferredOrder: Int = Int.max
    
    enum SecurityType {
        case unknown, open, wep, wpa, wpa2, wpa3
    }

    struct CaptiveProfileData: Hashable, Codable, Identifiable {
        var id: Self { self }
        var CaptiveNetwork: Bool = false
        var CaptiveWebSheetLoginDate: Date? = nil
    }

    struct ChannelData: Hashable, Codable, Identifiable {
        var id: Self { self }
        var Channel: Int = -1
        var Timestamp: Date = Date(timeIntervalSince1970: 0)
        
        func joinedTime(_ relative: Bool = true) -> String {
            if (relative) {
                return Utils.relativeDateToString(Timestamp) ?? "Unknown"
            } else {
                return Utils.dateToString(Timestamp) ?? "Unknown"
            }
        }
    }

    /// Represents a single BSS (Basic Service Set) entry from the BSSList array
    struct BSSData: Hashable, Codable, Identifiable {
        var id: Self { self }
        var BSSID: String = ""
        var Channel: Int = -1
        var ChannelFlags: Int = -1
        var LastAssociatedAt: Date? = nil
        var AWDLRealTimeModeTimestamp: Date? = nil
        var DHCPServerID: Data? = nil
        var IPv4NetworkSignature: String = ""
        var IPv6NetworkSignature: String = ""
        var DHCPv6ServerID: Data? = nil
        var Colocated5GHzRNRChannel: Int = -1
        var Colocated5GHzRNRChannelFlags: Int = -1
        var LocationLatitude: Double? = nil
        var LocationLongitude: Double? = nil
        var LocationAccuracy: Double? = nil
        var LocationTimestamp: Date? = nil
    }

    struct CollocatedGroupData: Hashable, Codable, Identifiable {
        var id: Self { self }
        var ssid: String = ""
    }

   
    func ssidString() -> String {
        guard let ssid = self.SSID,
              let ssidString = String(data: ssid, encoding: .utf8) else {
            return "Unknown"
        }
        return ssidString
    }
    
    func getSecurityName() -> String {
        let name: String = SupportedSecurityTypes
        if securityType() == .open {
            return "\(name) (No Password)"
        } else if securityType() == .unknown {
            return "\(name) (Unknown)"
        } else {
            return name
        }
    }
    
    func securityType() -> SecurityType {
        if SupportedSecurityTypes.contains("WPA3") {
            return .wpa3
        } else if SupportedSecurityTypes.contains("WPA2") {
            return .wpa2
        } else if (SupportedSecurityTypes.contains("WPA")) {
            return .wpa
        } else if (SupportedSecurityTypes.contains("WEP")) {
            return .wep
        } else if (SupportedSecurityTypes.contains("Open")) {
            return .open
        } else {
            return .unknown
        }
    }
    
    func joinedByUserAt() -> Date {
        return JoinedByUserAt ?? Date(timeIntervalSince1970: 0)
    }
    
    func joinedByUserAtString() -> String {
        return Utils.dateToString(JoinedByUserAt) ?? "Never from this Device"
    }
    
    func joinedBySystemAt() -> Date {
        return JoinedBySystemAt ?? Date(timeIntervalSince1970: 0)
    }
    
    func joinedBySystemAtString() -> String {
        return Utils.dateToString(JoinedBySystemAt) ?? "Never from this Device"
    }
    
    func addedAt() -> Date {
        return AddedAt ?? Date(timeIntervalSince1970: 0)
    }
    
    func addedAtString() -> String {
        return Utils.dateToString(AddedAt) ?? "Unknown"
    }
    
    
    func userPreferredOrderTimestamp() -> String {
        return Utils.dateToString(UserPreferredOrderTimestamp) ?? "Never from this Device"
    }
    
    func isCaptive() -> Bool {
        guard !CaptiveProfile.isEmpty,
              let cpd = CaptiveProfile.first else {
            return false
        }
        return cpd.CaptiveNetwork
    }
    
    func captiveLogin() -> String {
        guard !CaptiveProfile.isEmpty,
              let cpd = CaptiveProfile.first else {
            return "Unknown"
        }
        return Utils.relativeDateToString(cpd.CaptiveWebSheetLoginDate) ?? "Unknown"
    }

    func hiddenStateText() -> String {
        if Hidden  {
            return "Hidden"
        } else {
            return "Visible"
        }
    }

    func hiddenStateImage() -> String {
        if Hidden {
            return "eye.slash"
        } else {
            return "eye"
        }
    }

    func disconnectReasonText() -> String {
        switch LastDisconnectReason {
        case -1: return "Unknown"
        case 0: return "No reason"
        case 1: return "Unspecified"
        case 2: return "Previous auth invalid"
        case 3: return "Leaving BSS"
        case 4: return "Inactivity"
        case 5: return "Too many associated stations"
        case 8: return "Disassociated"
        case 11: return "Not in BSS range"
        case 15: return "4-way handshake timeout"
        case 23: return "IEEE 802.1X auth failed"
        default: return "Code \(LastDisconnectReason)"
        }
    }
}
