import AuthenticationServices
import Flutter
import UIKit
import YandexLoginSDK

/// Flutter plugin wrapping the official Yandex `YandexLoginSDK` (iOS).
///
/// Apps that use the modern `UISceneDelegate` lifecycle (default for projects
/// created with Flutter 3+) must forward URL callbacks from their
/// `SceneDelegate.scene(_:openURLContexts:)` to
/// `YandexLoginSdkPlugin.handle(openURL:)`. AppDelegate-only apps don't need
/// any extra wiring — the plugin registers itself as a `FlutterApplicationLifeCycleDelegate`.
public class YandexLoginSdkPlugin: NSObject, FlutterPlugin {

    private var pendingResult: FlutterResult?
    private var activatedClientId: String?
    private var channel: FlutterMethodChannel?
    private var loggingEnabled = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "yandex_login_sdk",
            binaryMessenger: registrar.messenger()
        )
        let instance = YandexLoginSdkPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        YandexLoginSDK.shared.add(observer: instance)
    }

    /// Mirrors a native diagnostic event into the Dart-side
    /// `YandexLoginSdk.onLog` hook. Gated by the `nativeLogging` flag the Dart
    /// layer sends with each signIn (true only while a log handler is
    /// installed).
    private func nativeLog(_ level: String, _ message: String) {
        guard loggingEnabled else { return }
        channel?.invokeMethod("log", arguments: ["level": level, "message": message])
    }

    /// Forwards a URL callback to the underlying Yandex SDK. Call this from
    /// your `SceneDelegate.scene(_:openURLContexts:)`:
    ///
    /// ```swift
    /// func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    ///     for ctx in URLContexts {
    ///         _ = YandexLoginSdkPlugin.handle(openURL: ctx.url)
    ///     }
    /// }
    /// ```
    @discardableResult
    public static func handle(openURL url: URL) -> Bool {
        return YandexLoginSDK.shared.tryHandleOpenURL(url)
    }

    /// Forwards a Universal Link callback to the underlying Yandex SDK.
    @discardableResult
    public static func handle(continue userActivity: NSUserActivity) -> Bool {
        return YandexLoginSDK.shared.tryHandleUserActivity(userActivity)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "signIn":
            handleSignIn(call, result: result)
        case "signOut":
            handleSignOut(result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Clears the SDK's locally-cached login state.
    ///
    /// `YandexLoginSDK.logout()` removes the stored token/JWT, the PKCE
    /// verifier and CSRF states from the Keychain. It is local-only: it does
    /// not revoke the token on Yandex's servers. Clearing the cache forces the
    /// next `authorize` to present interactive UI instead of returning the
    /// cached result.
    private func handleSignOut(_ result: @escaping FlutterResult) {
        do {
            try YandexLoginSDK.shared.logout()
            result(nil)
        } catch {
            result(FlutterError(code: "SDK_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func handleSignIn(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard pendingResult == nil else {
            result(FlutterError(code: "BUSY", message: "Another sign-in is in progress", details: nil))
            return
        }
        guard
            let args = call.arguments as? [String: Any],
            let clientId = args["clientId"] as? String,
            !clientId.isEmpty
        else {
            result(FlutterError(code: "BAD_ARGS", message: "clientId is required", details: nil))
            return
        }
        let strategy: YandexLoginSDK.AuthorizationStrategy =
            (args["strategy"] as? String) == "webOnly" ? .webOnly : .default
        loggingEnabled = (args["nativeLogging"] as? Bool) ?? false
        do {
            // Re-activate when the app switches to a different OAuth client;
            // repeated activation with the same id is a cheap assignment.
            if activatedClientId != clientId {
                try YandexLoginSDK.shared.activate(with: clientId)
                activatedClientId = clientId
            }
            guard let rootVC = Self.topViewController() else {
                result(FlutterError(code: "NO_VC", message: "Root view controller not found", details: nil))
                return
            }
            pendingResult = result
            nativeLog("debug", "starting authorization (strategy=\(strategy))")
            try YandexLoginSDK.shared.authorize(
                with: rootVC,
                customValues: nil,
                authorizationStrategy: strategy
            )
        } catch {
            pendingResult = nil
            nativeLog("error", "authorize failed to start: \(error.localizedDescription)")
            result(FlutterError(code: "SDK_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first
        var vc = window?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }

    /// `localizedDescription` is translated by the system, so cancellation is
    /// detected by error domain + code first; the English substring check is
    /// only a last resort for the SDK's own (non-localized) messages, such as
    /// `userClosedWebViewController`.
    private static func isCancellation(_ error: Error) -> Bool {
        if let asError = error as? ASWebAuthenticationSessionError,
           asError.code == .canceledLogin {
            return true
        }
        let nsError = error as NSError
        switch (nsError.domain, nsError.code) {
        case (ASWebAuthenticationSessionErrorDomain, ASWebAuthenticationSessionError.canceledLogin.rawValue),
             // SFAuthenticationErrorDomain / canceledLogin — the symbol is
             // deprecated, the literal avoids a build warning.
             ("com.apple.SafariServices.Authentication", 1),
             (NSCocoaErrorDomain, NSUserCancelledError):
            return true
        default:
            break
        }
        if let sdkError = error as? YandexLoginSDKError,
           sdkError.message.contains("closed the view controller") {
            return true
        }
        let desc = nsError.localizedDescription.lowercased()
        return desc.contains("cancel") || desc.contains("close")
    }

    // MARK: - UIApplicationDelegate (registered via addApplicationDelegate)

    public func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return YandexLoginSDK.shared.tryHandleOpenURL(url)
    }

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return YandexLoginSDK.shared.tryHandleUserActivity(userActivity)
    }
}

extension YandexLoginSdkPlugin: YandexLoginSDKObserver {
    public func didFinishLogin(with result: Result<LoginResult, Error>) {
        guard let pending = pendingResult else { return }
        pendingResult = nil
        switch result {
        case .success(let loginResult):
            nativeLog("debug", "sign-in succeeded")
            pending([
                "token": loginResult.token,
                "jwt": loginResult.jwt,
            ])
        case .failure(let error):
            let cancelled = Self.isCancellation(error)
            nativeLog(
                cancelled ? "info" : "error",
                cancelled ? "sign-in cancelled by user" : "sign-in failed: \(error.localizedDescription)"
            )
            pending(FlutterError(
                code: cancelled ? "CANCELLED" : "SDK_ERROR",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }
}
