//
//  WiFiData.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import Foundation
import SwiftUI

struct WiFiData: Hashable, Codable, Identifiable {

    var id: Self { self }
    
    var WiFiID: String = "InvalidID"
    var AddReason: String = ""
    var AddedAt: Date? = nil
    var CaptiveProfile: Array<CaptiveProfileData> = []
    
    var PasswordSharingDisabled: Bool = true //something new?
    var Hidden: Bool = false
    
    var JoinedBySystemAt: Date? = nil
    var JoinedByUserAt: Date? = nil
    
    var SSID: Data? = nil // Base64 Encoded SSID String
    var SupportedSecurityTypes: String = ""
    var WEPSubtype: String = ""
    var SystemMode: Bool = false
    var UpdatedAt: Date? = nil
    
//    var __OSSpecific__: Dictionary
    var BSSIDList: Array<BSSIDData> = []
    var ChannelHistory: Array<ChannelData> = []
    var CollocatedGroup: Array<CollocatedGroupData> = []
    var RoamingProfileType: String = ""
    var TemporarilyDisabled: Bool = false
    var UserPreferredOrderTimestamp: Date? = nil
    var WasHiddenBefore: Date? = nil
    
    var PreferredOrder: Int = Int.max
    
    enum SecurityType {
        case unknown, open, wep, wpa, wpa2, wpa3
    }

    struct CaptiveProfileData: Hashable, Codable, Identifiable {
        var id: Self { self }
        var CaptiveNetwork: Int = 0
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

    struct BSSIDData: Hashable, Codable, Identifiable {
        var id: Self { self }
        var LEAKY_AP_BSSID: String = ""
        var LEAKY_AP_LEARNED_DATA: Data = Data() // No clue what this means yet
        var Manufacturer: String = ""
        var normalizedMAC: String? = nil
        var normalizedOUI: String? = nil
        var SSID: String = ""
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
        } else if (SupportedSecurityTypes.contains("WPA2") && !SupportedSecurityTypes.contains("WPA3")) {
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
    
    func userPreferredOrder() -> Int64 {
        guard let addedDate = AddedAt else {
            return 0
        }
        return addedDate.currentTimeMillis()
    }
    
    func isCaptive() -> Bool {
        guard !CaptiveProfile.isEmpty,
              let cpd = CaptiveProfile.first else {
            return false
        }
        return cpd.CaptiveNetwork != 0
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
}
