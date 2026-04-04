import Foundation

/// XPC protocol shared between the main app and the privileged helper daemon.
/// Compiled into both the WiFiCheck app target and the WiFiCheckHelper target.
@objc protocol WiFiHelperProtocol {
    /// Reads the protected WiFi known-networks plist and returns its raw Data.
    /// The helper runs as root (launchd daemon) so it can bypass the chmod 600 restriction.
    func readWifiPlist(reply: @escaping (Data?, Error?) -> Void)
}
