//
//  WiFiQRCode.swift
//  WiFiCheck
//

import SwiftUI
import CoreImage
import AppKit

private func escapeWiFiValue(_ value: String) -> String {
    var result = ""
    for char in value {
        switch char {
        case "\\", ";", ",", "\"", ":":
            result.append("\\")
            result.append(char)
        default:
            result.append(char)
        }
    }
    return result
}

func wifiQRString(ssid: String, password: String?, security: WiFiData.SecurityType, isHidden: Bool) -> String {
    let authType: String
    switch security {
    case .wpa, .wpa2, .wpa3:
        authType = "WPA"
    case .wep:
        authType = "WEP"
    case .open, .unknown:
        authType = "nopass"
    }

    var components = ["WIFI:T:\(authType)", "S:\(escapeWiFiValue(ssid))"]

    if authType != "nopass", let pwd = password, !pwd.isEmpty {
        components.append("P:\(escapeWiFiValue(pwd))")
    }

    if isHidden {
        components.append("H:true")
    }

    return components.joined(separator: ";") + ";;"
}

func generateQRCode(from string: String) -> NSImage? {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(string.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")

    guard let ciImage = filter.outputImage else { return nil }

    let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    let rep = NSCIImageRep(ciImage: scaled)
    let image = NSImage(size: rep.size)
    image.addRepresentation(rep)
    return image
}

struct WiFiQRCodeView: View {
    let ssid: String
    let image: NSImage?

    var body: some View {
        VStack(spacing: 12) {
            if let image {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 250, height: 250)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 250, height: 250)
                    .overlay(Text("QR Code Unavailable").foregroundColor(.secondary))
            }
            Text(ssid)
                .font(.headline)
            Text("Scan with phone camera to join")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Copy Image") {
                if let image {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([image])
                }
            }
            .disabled(image == nil)
        }
        .frame(minWidth: 280)
    }
}
