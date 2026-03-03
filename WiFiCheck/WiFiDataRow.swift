//
//  WiFiDataRow.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import SwiftUI

struct WiFiDataRow: View {

    var wifidata: WiFiData

    var body: some View {
        Label {
            Text(wifidata.ssidString())
                .font(.body)
                .foregroundColor(.primary)
        } icon: {
            HStack(spacing: 4) {
                Image(systemName: "wifi")
                    .renderingMode(.template)
                Image(systemName: securityIcon)
                    .renderingMode(.template)
                    .font(.caption)
            }
        }
        .accentColor(securityColor)
        .accessibilityLabel(accessibilityDescription)
    }

    /// Returns the color for the security level
    private var securityColor: Color {
        switch wifidata.securityType() {
        case .wpa3:
            return .green
        case .wpa2, .wpa:
            return Color(NSColor.systemTeal)
        case .wep:
            return .yellow
        case .open:
            return .red
        case .unknown:
            return .gray
        }
    }

    /// Returns the security icon for visual distinction (helps colorblind users)
    private var securityIcon: String {
        switch wifidata.securityType() {
        case .wpa3:
            return "checkmark.shield.fill"  // Best security
        case .wpa2:
            return "shield.fill"            // Good security
        case .wpa:
            return "shield"                 // Older but secure
        case .wep:
            return "exclamationmark.triangle.fill"  // Weak security warning
        case .open:
            return "lock.open.fill"         // No security
        case .unknown:
            return "questionmark.circle"    // Unknown
        }
    }

    /// Returns the accessibility description for screen readers
    private var accessibilityDescription: String {
        let securityLevel: String
        switch wifidata.securityType() {
        case .wpa3:
            securityLevel = "WPA3 secured"
        case .wpa2:
            securityLevel = "WPA2 secured"
        case .wpa:
            securityLevel = "WPA secured"
        case .wep:
            securityLevel = "WEP secured (weak security)"
        case .open:
            securityLevel = "Open unsecured"
        case .unknown:
            securityLevel = "Unknown security"
        }
        return "\(securityLevel) network: \(wifidata.ssidString())"
    }
}

struct WiFiDataRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WiFiDataRow(wifidata: WiFiDataManager.shared.getWiFiDataList()[0])
            WiFiDataRow(wifidata: WiFiDataManager.shared.getWiFiDataList()[1])
            WiFiDataRow(wifidata: WiFiDataManager.shared.getWiFiDataList()[2])
        }
        .previewLayout(.fixed(width:250, height: 70))
    }
}
