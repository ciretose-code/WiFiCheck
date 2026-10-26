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
    let qrString: String

    @State private var image: NSImage?
    @State private var pasteboardClearWorkItem: DispatchWorkItem?

    /// WIFI QR payloads embed the password as a `P:` field when present.
    private var includesPassword: Bool {
        qrString.contains(";P:")
    }

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
                copyImageToPasteboard()
            }
            .disabled(image == nil)
            if includesPassword {
                Text("Clipboard clears in \(Constants.qrPasteboardClearDelay)s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 280)
        .restoredPresentationControls()
        .onAppear {
            renderQR()
        }
    }

    private func renderQR() {
        image = generateQRCode(from: qrString)
        // CIQRCodeGenerator can return nil immediately after a keychain ACL
        // dialog; retry once the security window is fully gone.
        if image == nil {
            DispatchQueue.main.async {
                image = generateQRCode(from: qrString)
            }
        }
    }

    private func copyImageToPasteboard() {
        guard let image else { return }
        pasteboardClearWorkItem?.cancel()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        guard includesPassword else { return }

        // Only clear if the pasteboard still holds what we wrote (user hasn't replaced it).
        let changeCount = NSPasteboard.general.changeCount
        let workItem = DispatchWorkItem {
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
        pasteboardClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .seconds(Constants.qrPasteboardClearDelay),
            execute: workItem
        )
    }
}
