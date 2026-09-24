import Foundation
import os.log

private let kWifiPlistPath = "/Library/Preferences/com.apple.wifi.known-networks.plist"
private let kMachServiceName = "com.ciretose.macos.tool.WiFiCheck.helper"
private let logger = Logger(subsystem: "com.ciretose.wificheck", category: "WiFiCheckHelper")

private enum HelperError {
    static let domain = "com.ciretose.wificheck.helper"

    static func make(code: Int, message: String) -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

/// Accepts only Apple known-networks keys: `wifi.ssid.<hex bytes, optional spaces/brackets>`.
func isValidKnownNetworkID(_ wifiID: String) -> Bool {
    let prefix = "wifi.ssid."
    guard wifiID.hasPrefix(prefix) else { return false }
    let rest = wifiID.dropFirst(prefix.count)
    guard !rest.isEmpty, rest.count <= 256 else { return false }
    return rest.allSatisfy { $0.isHexDigit || $0 == " " || $0 == "<" || $0 == ">" }
}

/// Removes `wifiID` from a known-networks plist blob and returns the rewritten bytes.
func removingKnownNetwork(from data: Data, wifiID: String) throws -> Data {
    var format: PropertyListSerialization.PropertyListFormat = .binary
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
    guard var networks = plist as? [String: Any] else {
        throw HelperError.make(code: 2, message: "The known-networks file is not a valid property list dictionary.")
    }
    guard networks.removeValue(forKey: wifiID) != nil else {
        throw HelperError.make(code: 3, message: "That network was not found in the known-networks store.")
    }
    return try PropertyListSerialization.data(fromPropertyList: networks, format: format, options: 0)
}

/// Only the WiFi Check app may talk to this privileged helper.
/// Team ID is the app target `DEVELOPMENT_TEAM` in the Xcode project (quoted because it starts with a digit).
private let kClientCodeSigningRequirement =
    #"identifier "com.ciretose.macos.tool.WiFiCheck" and anchor apple generic and certificate leaf[subject.OU] = "6D39SX3E6V""#

final class HelperDelegate: NSObject, NSXPCListenerDelegate, WiFiHelperProtocol {

    func readWifiPlist(reply: @escaping (Data?, Error?) -> Void) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: kWifiPlistPath))
            reply(data, nil)
        } catch {
            reply(nil, error)
        }
    }

    func deleteWifiNetwork(wifiID: String, reply: @escaping (Bool, Error?) -> Void) {
        guard isValidKnownNetworkID(wifiID) else {
            logger.error("Rejected delete for invalid wifiID")
            reply(false, HelperError.make(code: 1, message: "Invalid Wi-Fi network identifier."))
            return
        }

        let url = URL(fileURLWithPath: kWifiPlistPath)
        let tmpURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")

        do {
            let data = try Data(contentsOf: url)
            let updated = try removingKnownNetwork(from: data, wifiID: wifiID)
            try updated.write(to: tmpURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmpURL.path)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
            logger.info("Deleted known-networks entry")
            reply(true, nil)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            logger.error("Failed to delete known-networks entry: \(error.localizedDescription, privacy: .public)")
            reply(false, error)
        }
    }

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Must be set before resume(); a peer that fails this requirement is invalidated.
        connection.setCodeSigningRequirement(kClientCodeSigningRequirement)
        connection.exportedInterface = NSXPCInterface(with: WiFiHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: kMachServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
