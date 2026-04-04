import Foundation

private let kWifiPlistPath = "/Library/Preferences/com.apple.wifi.known-networks.plist"
private let kMachServiceName = "com.ciretose.macos.tool.WiFiCheck.helper"

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
