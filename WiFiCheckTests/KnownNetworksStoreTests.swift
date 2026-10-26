import XCTest

final class KnownNetworksStoreTests: XCTestCase {

    // MARK: - isValidKnownNetworkID

    func testRejectsNonWifiSSIDPrefix() {
        XCTAssertFalse(isValidKnownNetworkID("wifi.bssid.<aabbcc>"))
        XCTAssertFalse(isValidKnownNetworkID("ssid.<486f6d65>"))
        XCTAssertFalse(isValidKnownNetworkID("HomeNet"))
        XCTAssertFalse(isValidKnownNetworkID(""))
    }

    func testRejectsEmptySuffix() {
        XCTAssertFalse(isValidKnownNetworkID("wifi.ssid."))
    }

    func testRejectsOversizedIDs() {
        let oversized = "wifi.ssid." + String(repeating: "A", count: 257)
        XCTAssertFalse(isValidKnownNetworkID(oversized))
    }

    func testRejectsUnexpectedCharacters() {
        XCTAssertFalse(isValidKnownNetworkID("wifi.ssid.<HomeNet>"))
        XCTAssertFalse(isValidKnownNetworkID("wifi.ssid.<48/6f>"))
        XCTAssertFalse(isValidKnownNetworkID("wifi.ssid.<48-6f>"))
        XCTAssertFalse(isValidKnownNetworkID("wifi.ssid.486f6d65!"))
        XCTAssertFalse(isValidKnownNetworkID("wifi.ssid.<486f6d65\n>"))
    }

    func testAcceptsValidHexForm() {
        XCTAssertTrue(isValidKnownNetworkID("wifi.ssid.486f6d654e6574"))
        XCTAssertTrue(isValidKnownNetworkID("wifi.ssid.ABCDEF0123456789"))
    }

    func testAcceptsSpacedAndBracketedAppleKeyForms() {
        XCTAssertTrue(isValidKnownNetworkID("wifi.ssid.<486f6d654e6574>"))
        XCTAssertTrue(isValidKnownNetworkID("wifi.ssid.<4D7946726565 57696669>"))
        XCTAssertTrue(isValidKnownNetworkID("wifi.ssid.<4D 79 46 72>"))
    }

    func testAcceptsBoundaryLengthSuffix() {
        let maxRest = "wifi.ssid." + String(repeating: "a", count: 256)
        XCTAssertTrue(isValidKnownNetworkID(maxRest))
    }

    // MARK: - removingKnownNetwork

    func testRemovingKnownNetworkSucceedsForSingleKey() throws {
        let wifiID = "wifi.ssid.<486f6d654e6574>"
        let plist: [String: Any] = [
            wifiID: ["SSID": "HomeNet"],
            "wifi.ssid.<43616665>": ["SSID": "Cafe"],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)

        let updated = try removingKnownNetwork(from: data, wifiID: wifiID)

        var format: PropertyListSerialization.PropertyListFormat = .binary
        let result = try PropertyListSerialization.propertyList(from: updated, options: [], format: &format)
        let networks = try XCTUnwrap(result as? [String: Any])
        XCTAssertNil(networks[wifiID])
        XCTAssertNotNil(networks["wifi.ssid.<43616665>"])
        XCTAssertEqual(networks.count, 1)
    }

    func testRemovingKnownNetworkThrowsWhenKeyMissing() throws {
        let plist: [String: Any] = [
            "wifi.ssid.<43616665>": ["SSID": "Cafe"],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)

        XCTAssertThrowsError(
            try removingKnownNetwork(from: data, wifiID: "wifi.ssid.<486f6d654e6574>")
        ) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, HelperError.domain)
            XCTAssertEqual(nsError.code, 3)
        }
    }

    func testRemovingKnownNetworkThrowsForInvalidPlistShape() throws {
        // Valid plist, but a top-level array rather than a dictionary of networks.
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["not", "a", "dictionary"],
            format: .binary,
            options: 0
        )

        XCTAssertThrowsError(
            try removingKnownNetwork(from: data, wifiID: "wifi.ssid.<486f6d654e6574>")
        ) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, HelperError.domain)
            XCTAssertEqual(nsError.code, 2)
        }
    }
}
