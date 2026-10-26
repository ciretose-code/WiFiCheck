import Foundation

enum HelperError {
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
