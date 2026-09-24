import Foundation

private let kWifiPlistPath = "/Library/Preferences/com.apple.wifi.known-networks.plist"
private let kMachServiceName = "com.ciretose.macos.tool.WiFiCheck.helper"

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
