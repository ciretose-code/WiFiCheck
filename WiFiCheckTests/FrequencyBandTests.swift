import XCTest
@testable import WiFiCheck

final class FrequencyBandTests: XCTestCase {

    func testBandFromChannelFlagsTakesPrecedence() {
        // Channel 6 would look like 2.4 GHz by number, but 0x2000 means 6 GHz.
        XCTAssertEqual(Utils.frequencyBand(for: 6, flags: 0x2000), "6 GHz")
        XCTAssertEqual(Utils.frequencyBand(for: 36, flags: 0x10), "5 GHz")
        XCTAssertEqual(Utils.frequencyBand(for: 11, flags: 0x8), "2.4 GHz")
    }

    func testBandFromChannelNumberWhenFlagsUnset() {
        XCTAssertEqual(Utils.frequencyBand(for: 1), "2.4 GHz")
        XCTAssertEqual(Utils.frequencyBand(for: 14), "2.4 GHz")
        XCTAssertEqual(Utils.frequencyBand(for: 36), "5 GHz")
        XCTAssertEqual(Utils.frequencyBand(for: 149), "5 GHz")
        XCTAssertEqual(Utils.frequencyBand(for: 189), "6 GHz")
        XCTAssertEqual(Utils.frequencyBand(for: 233), "6 GHz")
    }

    func testUnknownForMissingOrOutOfRangeChannel() {
        XCTAssertEqual(Utils.frequencyBand(for: -1), "Unknown")
        XCTAssertEqual(Utils.frequencyBand(for: 0), "Unknown")
        XCTAssertEqual(Utils.frequencyBand(for: 20), "Unknown")
        XCTAssertEqual(Utils.frequencyBand(for: 15, flags: -1), "Unknown")
    }

    func testFlagsZeroFallsBackToChannelNumber() {
        XCTAssertEqual(Utils.frequencyBand(for: 11, flags: 0), "2.4 GHz")
    }
}
