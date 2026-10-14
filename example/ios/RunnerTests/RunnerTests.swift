import Flutter
import UIKit
import XCTest

@testable import yandex_login_sdk

// Unit tests for the method-call dispatch of the Swift plugin layer. The
// happy path of signIn needs a real Yandex OAuth client and user interaction,
// so it is covered manually via the example app; these tests pin down the
// branches that are reachable without it.
//
// Run with `xcodebuild test -workspace Runner.xcworkspace -scheme Runner
// -destination 'platform=iOS Simulator,name=<device>'` from `example/ios/`
// after a `flutter build ios --simulator --debug`.

class RunnerTests: XCTestCase {

  private func call(
    _ plugin: YandexLoginSdkPlugin,
    _ method: String,
    _ arguments: Any? = nil
  ) -> Any? {
    let done = expectation(description: "result block must be called")
    var received: Any?
    plugin.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { result in
      received = result
      done.fulfill()
    }
    waitForExpectations(timeout: 1)
    return received
  }

  private func errorCode(_ result: Any?) -> String? {
    (result as? FlutterError)?.code
  }

  func testUnknownMethodReportsNotImplemented() {
    let result = call(YandexLoginSdkPlugin(), "getPlatformVersion")

    XCTAssertTrue(result as AnyObject === FlutterMethodNotImplemented)
  }

  func testSignOutResolvesWithNil() {
    let result = call(YandexLoginSdkPlugin(), "signOut")

    XCTAssertNil(result)
  }

  func testSignInWithoutArgumentsIsBadArgs() {
    XCTAssertEqual(errorCode(call(YandexLoginSdkPlugin(), "signIn")), "BAD_ARGS")
  }

  func testSignInWithoutClientIdIsBadArgs() {
    let result = call(YandexLoginSdkPlugin(), "signIn", ["strategy": "auto"])

    XCTAssertEqual(errorCode(result), "BAD_ARGS")
  }

  func testSignInWithEmptyClientIdIsBadArgs() {
    let result = call(YandexLoginSdkPlugin(), "signIn", ["clientId": ""])

    XCTAssertEqual(errorCode(result), "BAD_ARGS")
  }

  // Goes through the real YandexLoginSDK: activation fails because the host
  // Info.plist has no `yx<clientId>` URL scheme for this id.
  func testSignInWithUnregisteredClientIdFailsAndDoesNotStayBusy() {
    let plugin = YandexLoginSdkPlugin()
    let args = ["clientId": "unregistered_test_client"]

    XCTAssertEqual(errorCode(call(plugin, "signIn", args)), "SDK_ERROR")
    XCTAssertEqual(errorCode(call(plugin, "signIn", args)), "SDK_ERROR")
  }
}
