import XCTest
@testable import WiFiCheck

final class ForgetAuthenticationTests: XCTestCase {

    private let key = ForgetAuthentication.preferenceKey

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testDefaultRequiresAuthentication() {
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertTrue(ForgetAuthentication.isRequired)
    }

    func testPreferenceOffDisablesRequirement() {
        UserDefaults.standard.set(false, forKey: key)
        XCTAssertFalse(ForgetAuthentication.isRequired)
    }

    func testAuthorizeSkipsPromptWhenPreferenceOff() {
        UserDefaults.standard.set(false, forKey: key)
        let exp = expectation(description: "authorize")
        ForgetAuthentication.authorizeIfRequired(reason: "unit test") { result in
            if case .failure(let error) = result {
                XCTFail("expected success, got \(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}
