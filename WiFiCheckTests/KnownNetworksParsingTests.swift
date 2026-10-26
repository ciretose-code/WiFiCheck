import XCTest
@testable import WiFiCheck

final class KnownNetworksParsingTests: XCTestCase {

    private let manager = WiFiDataManager.shared

    override func tearDown() {
        manager.wifidatalist = []
        super.tearDown()
    }

    func testParseDroppedSamplePlist() throws {
        let data = try Fixtures.data("known-networks-sample.plist")
        XCTAssertTrue(manager.parseDroppedData(data))

        let networks = manager.getWiFiDataList()
        XCTAssertEqual(networks.count, 3)

        let bySSID = Dictionary(uniqueKeysWithValues: networks.map { ($0.ssidString(), $0) })

        let home = try XCTUnwrap(bySSID["HomeNet"])
        XCTAssertEqual(home.SupportedSecurityTypes, "WPA3 Personal")
        XCTAssertEqual(home.securityType(), .wpa3)
        XCTAssertFalse(home.Hidden)
        XCTAssertEqual(home.BSSList.count, 1)
        XCTAssertEqual(home.BSSList[0].BSSID, "aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(home.BSSList[0].Channel, 36)
        XCTAssertEqual(home.BSSList[0].ChannelFlags, 16)
        XCTAssertEqual(try XCTUnwrap(home.BSSList[0].LocationLatitude), 37.7749, accuracy: 0.0001)
        XCTAssertEqual(home.ChannelHistory.count, 2)
        // Channel history is sorted most-recent first.
        XCTAssertEqual(home.ChannelHistory[0].Channel, 36)
        XCTAssertEqual(home.ChannelHistory[1].Channel, 11)
        XCTAssertEqual(home.CollocatedGroup.count, 1)
        XCTAssertEqual(home.CollocatedGroup[0].ssid, "Cafe WiFi")
        XCTAssertEqual(home.CachedPrivateMACAddress, "12:34:56:78:9a:bc")
        XCTAssertEqual(home.UserPreferredNetworkNames, ["HomeNet"])
        XCTAssertTrue(manager.isLoadedFromFile)

        let cafe = try XCTUnwrap(bySSID["Cafe WiFi"])
        XCTAssertTrue(cafe.Hidden)
        XCTAssertTrue(cafe.SystemMode)
        XCTAssertTrue(cafe.TemporarilyDisabled)
        XCTAssertEqual(cafe.securityType(), .wpa2)

        let open = try XCTUnwrap(bySSID["OpenNet"])
        XCTAssertEqual(open.securityType(), .open)
    }

    func testLoadFromURL() throws {
        let url = Fixtures.url("known-networks-sample.plist")
        XCTAssertTrue(manager.loadFromURL(url))
        XCTAssertEqual(manager.getWiFiDataList().count, 3)
        XCTAssertTrue(manager.isLoadedFromFile)
    }

    func testLatin1SSIDFromPlist() throws {
        let data = try Fixtures.data("known-networks-latin1-ssid.plist")
        XCTAssertTrue(manager.parseDroppedData(data))
        XCTAssertEqual(manager.getWiFiDataList().first?.ssidString(), "café")
    }

    func testParseDroppedDataRejectsEmptyDictionary() throws {
        let empty = try PropertyListSerialization.data(fromPropertyList: [String: Any](), format: .xml, options: 0)
        XCTAssertFalse(manager.parseDroppedData(empty))
    }

    func testParseDroppedDataRejectsInvalidPlist() {
        XCTAssertFalse(manager.parseDroppedData(Data("not a plist".utf8)))
    }

    func testParseDroppedDataRejectsOversizedData() {
        let oversized = Data(count: Constants.maxKnownNetworksImportBytes + 1)
        XCTAssertFalse(manager.parseDroppedData(oversized))
        XCTAssertTrue(manager.getWiFiDataList().isEmpty)
    }

    func testLoadFromURLRejectsOversizedFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wificheck-oversized-\(UUID().uuidString).plist")
        let oversized = Data(count: Constants.maxKnownNetworksImportBytes + 1)
        try oversized.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertFalse(manager.loadFromURL(url))
        XCTAssertTrue(manager.getWiFiDataList().isEmpty)
    }

    func testParseDroppedDataRejectsNonKnownNetworksShape() throws {
        // Valid plist dictionary, but no wifi.ssid.* keys — not Apple known-networks.
        let unrelated: [String: Any] = [
            "CFBundleIdentifier": "com.example.app",
            "SomeSetting": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: unrelated, format: .xml, options: 0)
        XCTAssertFalse(manager.parseDroppedData(data))
        XCTAssertTrue(manager.getWiFiDataList().isEmpty)
    }
}
