import XCTest
@testable import WiFiCheck

final class NetworkSetupTests: XCTestCase {

    func testPreferredNetworkOrderEnglishHeader() throws {
        let output = try Fixtures.string("preferred-networks-english.txt")
        let order = NetworkSetup.preferredNetworkOrder(from: output)

        XCTAssertEqual(order["HomeNet"], 100)
        XCTAssertEqual(order["Cafe WiFi"], 200)
        XCTAssertEqual(order["Work(Guest)"], 300)
        XCTAssertEqual(order.count, 3)
    }

    func testPreferredNetworkOrderNonEnglishHeader() throws {
        let output = try Fixtures.string("preferred-networks-german.txt")
        let order = NetworkSetup.preferredNetworkOrder(from: output)

        // Header is skipped by indentation rules, not by English text match.
        XCTAssertEqual(order["Zuhause"], 100)
        XCTAssertEqual(order["Büro*"], 200)
        XCTAssertNil(order["Bevorzugte Netzwerke auf en0:"])
        XCTAssertEqual(order.count, 2)
    }

    func testPreferredNetworkOrderEmptyOutput() throws {
        let output = try Fixtures.string("preferred-networks-empty.txt")
        XCTAssertTrue(NetworkSetup.preferredNetworkOrder(from: output).isEmpty)
    }

    func testPreferredNetworkOrderBlankLinesAndIndentedOnly() {
        let output = """

\tAlpha
\tBeta
"""
        let order = NetworkSetup.preferredNetworkOrder(from: output)
        XCTAssertEqual(order["Alpha"], 100)
        XCTAssertEqual(order["Beta"], 200)
    }
}
