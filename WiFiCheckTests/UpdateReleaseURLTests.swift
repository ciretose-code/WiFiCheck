import XCTest
@testable import WiFiCheck

final class UpdateReleaseURLTests: XCTestCase {

    func testAllowsHTTPSGitHubReleaseURL() {
        let url = URL(string: "https://github.com/ciretose-code/WiFiCheck/releases/tag/v1.2.3")!
        XCTAssertTrue(UpdateChecker.isAllowedReleaseURL(url))
    }

    func testAllowsGitHubHostCaseInsensitively() {
        let url = URL(string: "https://GitHub.com/ciretose-code/WiFiCheck/releases/tag/v1.2.3")!
        XCTAssertTrue(UpdateChecker.isAllowedReleaseURL(url))
    }

    func testRejectsNonHTTPS() {
        let url = URL(string: "http://github.com/ciretose-code/WiFiCheck/releases/tag/v1.2.3")!
        XCTAssertFalse(UpdateChecker.isAllowedReleaseURL(url))
    }

    func testRejectsNonGitHubHost() {
        let url = URL(string: "https://evil.example/phishing")!
        XCTAssertFalse(UpdateChecker.isAllowedReleaseURL(url))
    }

    func testRejectsGitHubLookalikeHost() {
        let url = URL(string: "https://github.com.evil.example/releases")!
        XCTAssertFalse(UpdateChecker.isAllowedReleaseURL(url))
    }

    func testRejectsGitHubSubdomain() {
        let url = URL(string: "https://gist.github.com/someone/abc")!
        XCTAssertFalse(UpdateChecker.isAllowedReleaseURL(url))
    }

    func testRejectsCredentialBearingURL() {
        let url = URL(string: "https://attacker@github.com/ciretose-code/WiFiCheck/releases/tag/v1.2.3")!
        XCTAssertFalse(UpdateChecker.isAllowedReleaseURL(url))
    }

    func testOpenableHTMLURLThrowsForUntrustedHost() {
        let release = UpdateRelease(
            tagName: "v9.9.9",
            htmlURL: URL(string: "https://evil.example/release")!
        )
        XCTAssertThrowsError(try release.openableHTMLURL()) { error in
            XCTAssertEqual(error as? UpdateCheckError, .untrustedReleaseURL)
        }
    }
}
