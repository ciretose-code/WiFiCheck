import Foundation
import os.log

private let kWifiPlistPath = "/Library/Preferences/com.apple.wifi.known-networks.plist"
private let kMachServiceName = "com.ciretose.macos.tool.WiFiCheck.helper"
private let logger = Logger(subsystem: "com.ciretose.wificheck", category: "WiFiCheckHelper")

/// Only the WiFi Check app may talk to this privileged helper.
/// Team ID comes from `WiFiCheckTeamID` in Info.plist (`$(DEVELOPMENT_TEAM)` via Config/Local.xcconfig).
private let kClientCodeSigningRequirement: String = {
    guard let teamID = Bundle.main.object(forInfoDictionaryKey: "WiFiCheckTeamID") as? String,
          !teamID.isEmpty,
          !teamID.hasPrefix("$(") else {
        fatalError("WiFiCheckTeamID missing — copy Config/Local.xcconfig.template to Config/Local.xcconfig and set DEVELOPMENT_TEAM")
    }
    // OU is quoted because Team IDs can start with a digit.
    return #"identifier "com.ciretose.macos.tool.WiFiCheck" and anchor apple generic and certificate leaf[subject.OU] = "\#(teamID)""#
}()


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

        // Residual race: there is no supported lock or API coordinating with airportd/wifid.
        // Concurrent system writes can still lose updates or briefly diverge from this
        // read→mutate→replace. We harden with round-trip parse validation and a short-lived
        // backup aside; long-term prefer a public forget API if Apple ships one.
        let url = URL(fileURLWithPath: kWifiPlistPath)
        let dir = url.deletingLastPathComponent()
        let tmpURL = dir.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        let backupURL = dir.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).bak")

        do {
            let data = try Data(contentsOf: url)
            let updated = try removingKnownNetwork(from: data, wifiID: wifiID)

            // Refuse to replace the live store with bytes we cannot re-parse as a dictionary
            // that no longer contains the deleted key.
            var verifyFormat: PropertyListSerialization.PropertyListFormat = .binary
            let verified = try PropertyListSerialization.propertyList(
                from: updated, options: [], format: &verifyFormat
            )
            guard let verifiedNetworks = verified as? [String: Any],
                  verifiedNetworks[wifiID] == nil else {
                throw HelperError.make(
                    code: 4,
                    message: "Rewritten known-networks plist failed validation before replace."
                )
            }

            // Short-lived backup of the pre-delete bytes; removed after a successful replace
            // (and on failure) so we do not leave an aside copy behind.
            try data.write(to: backupURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: backupURL.path
            )
            defer { try? FileManager.default.removeItem(at: backupURL) }

            try updated.write(to: tmpURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmpURL.path)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
            logger.info("Deleted known-networks entry")
            reply(true, nil)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            try? FileManager.default.removeItem(at: backupURL)
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
