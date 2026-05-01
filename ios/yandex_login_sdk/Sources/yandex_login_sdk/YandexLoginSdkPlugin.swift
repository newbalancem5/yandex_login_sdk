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
    private var isActivated = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "yandex_login_sdk",
            binaryMessenger: registrar.messenger()
        )
        let instance = YandexLoginSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        YandexLoginSDK.shared.add(observer: instance)
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
        default:
            result(FlutterMethodNotImplemented)
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
        do {
            if !isActivated {
                try YandexLoginSDK.shared.activate(with: clientId)
                isActivated = true
            }
            guard let rootVC = Self.topViewController() else {
                result(FlutterError(code: "NO_VC", message: "Root view controller not found", details: nil))
                return
            }
            pendingResult = result
            try YandexLoginSDK.shared.authorize(
                with: rootVC,
                customValues: nil,
                authorizationStrategy: .default
            )
        } catch {
            pendingResult = nil
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
            pending([
                "token": loginResult.token,
                "jwt": loginResult.jwt,
            ])
        case .failure(let error):
            let isCancel: Bool = {
                if let asError = error as? ASWebAuthenticationSessionError,
                   asError.code == .canceledLogin {
                    return true
                }
                let desc = (error as NSError).localizedDescription.lowercased()
                return desc.contains("cancel") || desc.contains("close")
            }()
            pending(FlutterError(
                code: isCancel ? "CANCELLED" : "SDK_ERROR",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }
}
