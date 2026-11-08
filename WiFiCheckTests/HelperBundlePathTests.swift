import XCTest
@testable import WiFiCheck

final class HelperBundlePathTests: XCTestCase {

    /// Nested helper must be an .app (not a bare Mach-O beside the launchd plist).
    func testHelperIsPackagedAsAppBundle() {
        XCTAssertTrue(Constants.helperAppName.hasSuffix(".app"))
        XCTAssertEqual(Constants.helperAppName, "WiFiCheckHelper.app")
        XCTAssertEqual(Constants.helperBundleIdentifier, "com.ciretose.macos.tool.WiFiCheck.helper")
    }

    /// SMAppService BundleProgram is relative to the host app bundle and must
    /// point at the nested helper executable inside WiFiCheckHelper.app.
    func testBundleProgramPointsAtNestedHelperExecutable() {
        XCTAssertEqual(
            Constants.helperBundleProgramRelativePath,
            "Contents/Library/LaunchDaemons/WiFiCheckHelper.app/Contents/MacOS/WiFiCheckHelper"
        )
    }

    /// Existence checks look under LaunchDaemons for the nested helper .app.
    func testHelperAppPathIsUnderLaunchDaemons() {
        let appURL = URL(fileURLWithPath: Constants.helperAppPath)
        XCTAssertEqual(appURL.lastPathComponent, "WiFiCheckHelper.app")
        XCTAssertEqual(appURL.deletingLastPathComponent().lastPathComponent, "LaunchDaemons")
    }

    /// Full Disk Access should target the host app (stable LS identity), not the
    /// launchd-exec'd helper binary.
    func testFullDiskAccessTargetsHostApp() {
        XCTAssertEqual(Constants.appBundleIdentifier, "com.ciretose.macos.tool.WiFiCheck")
        XCTAssertEqual(
            URL(fileURLWithPath: Constants.fullDiskAccessTargetPath).pathExtension,
            "app"
        )
    }
}
