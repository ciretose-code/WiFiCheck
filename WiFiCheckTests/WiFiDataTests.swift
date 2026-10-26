import XCTest
@testable import WiFiCheck

final class WiFiDataTests: XCTestCase {

    func testSecurityTypePrecedence() {
        var data = WiFiData()

        data.SupportedSecurityTypes = "WPA3 Personal"
        XCTAssertEqual(data.securityType(), .wpa3)

        data.SupportedSecurityTypes = "WPA2/WPA3 Personal"
        XCTAssertEqual(data.securityType(), .wpa3)

        data.SupportedSecurityTypes = "WPA2 Personal"
        XCTAssertEqual(data.securityType(), .wpa2)

        data.SupportedSecurityTypes = "WPA Personal"
        XCTAssertEqual(data.securityType(), .wpa)

        data.SupportedSecurityTypes = "WEP"
        XCTAssertEqual(data.securityType(), .wep)

        data.SupportedSecurityTypes = "Open"
        XCTAssertEqual(data.securityType(), .open)

        data.SupportedSecurityTypes = ""
        XCTAssertEqual(data.securityType(), .unknown)
    }

    func testGetSecurityNameAnnotations() {
        var open = WiFiData()
        open.SupportedSecurityTypes = "Open"
        XCTAssertEqual(open.getSecurityName(), "Open (No Password)")

        var unknown = WiFiData()
        unknown.SupportedSecurityTypes = "Mystery"
        XCTAssertEqual(unknown.getSecurityName(), "Mystery (Unknown)")

        var wpa2 = WiFiData()
        wpa2.SupportedSecurityTypes = "WPA2 Personal"
        XCTAssertEqual(wpa2.getSecurityName(), "WPA2 Personal")
    }
}
