import XCTest
import ServiceManagement
@testable import WiFiCheck

final class HelperInstallPlanTests: XCTestCase {

    func testEnabledWithReachableHelperIsNoop() {
        let plan = WiFiDataManager.planHelperInstall(
            status: .enabled,
            binaryExists: true,
            machServiceReachable: true
        )
        XCTAssertEqual(plan, .noop)
    }

    /// SMAppService can report `.enabled` while launchd has no job (stranded BTM).
    /// Install must re-register instead of short-circuiting as healthy.
    func testEnabledButUnreachableForcesReregister() {
        let plan = WiFiDataManager.planHelperInstall(
            status: .enabled,
            binaryExists: true,
            machServiceReachable: false
        )
        XCTAssertEqual(plan, .unregisterThenRegister)
    }

    func testEnabledWithMissingBinaryForcesReregister() {
        let plan = WiFiDataManager.planHelperInstall(
            status: .enabled,
            binaryExists: false,
            machServiceReachable: false
        )
        XCTAssertEqual(plan, .unregisterThenRegister)
    }

    func testRequiresApprovalForcesReregister() {
        let plan = WiFiDataManager.planHelperInstall(
            status: .requiresApproval,
            binaryExists: true,
            machServiceReachable: false
        )
        XCTAssertEqual(plan, .unregisterThenRegister)
    }

    func testNotRegisteredRegistersOnly() {
        let plan = WiFiDataManager.planHelperInstall(
            status: .notRegistered,
            binaryExists: true,
            machServiceReachable: false
        )
        XCTAssertEqual(plan, .registerOnly)
    }

    func testNotFoundRegistersOnly() {
        let plan = WiFiDataManager.planHelperInstall(
            status: .notFound,
            binaryExists: false,
            machServiceReachable: false
        )
        XCTAssertEqual(plan, .registerOnly)
    }
}
