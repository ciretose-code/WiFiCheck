import XCTest
@testable import WiFiCheck

final class SSIDParsingTests: XCTestCase {

    private let manager = WiFiDataManager.shared

    func testParseWiFiSSIDHexWithBracketsAndSpaces() {
        // "MyFreeWifi" as hex pairs with a space separator
        let decoded = manager.parseWiFiSSID("wifi.ssid.<4D7946726565 57696669>")
        XCTAssertEqual(decoded, "MyFreeWifi")
    }

    func testParseWiFiSSIDHexWithoutSpaces() {
        let decoded = manager.parseWiFiSSID("wifi.ssid.<486f6d654e6574>")
        XCTAssertEqual(decoded, "HomeNet")
    }

    func testParseWiFiSSIDUTF8Multibyte() {
        // "café" in UTF-8: 63 61 66 c3 a9
        let decoded = manager.parseWiFiSSID("wifi.ssid.<636166c3a9>")
        XCTAssertEqual(decoded, "café")
    }

    func testParseWiFiSSIDPassthroughWhenNotAppleFormat() {
        XCTAssertEqual(manager.parseWiFiSSID("plain-ssid"), "plain-ssid")
    }

    func testSSIDStringPrefersUTF8ThenLatin1() {
        var utf8 = WiFiData()
        utf8.SSID = Data("café".utf8)
        XCTAssertEqual(utf8.ssidString(), "café")

        // Latin-1 encoding of café: 63 61 66 e9 (not valid UTF-8)
        var latin1 = WiFiData()
        latin1.SSID = Data([0x63, 0x61, 0x66, 0xe9])
        XCTAssertEqual(latin1.ssidString(), "café")

        var missing = WiFiData()
        missing.SSID = nil
        XCTAssertEqual(missing.ssidString(), "Unknown")
    }
}
