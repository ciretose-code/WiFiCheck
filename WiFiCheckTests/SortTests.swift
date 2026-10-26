import XCTest
@testable import WiFiCheck

final class SortTests: XCTestCase {

    private let manager = WiFiDataManager.shared

    override func tearDown() {
        // Leave shared manager clean for other suites that load fixtures.
        manager.wifidatalist = []
        super.tearDown()
    }

    func testSortByPreferredOrder() {
        seed([
            make(id: "c", ssid: "C", preferred: 300),
            make(id: "a", ssid: "A", preferred: 100),
            make(id: "b", ssid: "B", preferred: 200),
        ])

        let sorted = manager.sortByPreferredOrder().map { $0.ssidString() }
        XCTAssertEqual(sorted, ["A", "B", "C"])
    }

    func testSortByAlphabeticalCaseInsensitive() {
        seed([
            make(id: "1", ssid: "banana"),
            make(id: "2", ssid: "Apple"),
            make(id: "3", ssid: "cherry"),
        ])

        let sorted = manager.sortByAlphabetical().map { $0.ssidString() }
        XCTAssertEqual(sorted, ["Apple", "banana", "cherry"])
    }

    func testSortByRecentUser() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        seed([
            make(id: "old", ssid: "Old", userJoined: older, systemJoined: newer),
            make(id: "new", ssid: "New", userJoined: newer, systemJoined: older),
        ])

        let sorted = manager.sortByRecentUser().map { $0.ssidString() }
        XCTAssertEqual(sorted, ["New", "Old"])
    }

    func testSortByRecentSystem() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        seed([
            make(id: "old", ssid: "Old", userJoined: newer, systemJoined: older),
            make(id: "new", ssid: "New", userJoined: older, systemJoined: newer),
        ])

        let sorted = manager.sortByRecentSystem().map { $0.ssidString() }
        XCTAssertEqual(sorted, ["New", "Old"])
    }

    // MARK: - Helpers

    private func seed(_ networks: [WiFiData]) {
        manager.wifidatalist = networks
    }

    private func make(
        id: String,
        ssid: String,
        preferred: Int = Int.max,
        userJoined: Date? = nil,
        systemJoined: Date? = nil
    ) -> WiFiData {
        var data = WiFiData()
        data.WiFiID = id
        data.SSID = Data(ssid.utf8)
        data.PreferredOrder = preferred
        data.JoinedByUserAt = userJoined
        data.JoinedBySystemAt = systemJoined
        return data
    }
}
