import '../yandex_login_sdk_platform_interface.dart';
import 'yandex_login_result.dart';

/// Entry point for the Yandex Login SDK plugin.
abstract final class YandexLoginSdk {
  /// Triggers Yandex authorization.
  ///
  /// On **Android** the SDK chains `NATIVE → CHROME_TAB → WEBVIEW`
  /// automatically: it tries an installed Yandex app first and falls back to a
  /// Chrome Custom Tab / WebView when none is available. The [clientId]
  /// argument is informational on Android — the actual value is read from
  /// the merged `AndroidManifest.xml` (see README setup).
  ///
  /// On **iOS** the SDK tries the installed Yandex apps first and falls back
  /// to `ASWebAuthenticationSession` (iOS 13+) or `SFSafariViewController`
  /// (iOS 12). [clientId] is used to activate the SDK at runtime.
  ///
  /// Throws:
  /// - [YandexAuthCancelledException] when the user cancels.
  /// - [YandexAuthUnsupportedException] on unsupported platforms.
  /// - [YandexAuthException] for any other SDK failure.
  static Future<YandexLoginResult> signIn({required String clientId}) {
    return YandexLoginSdkPlatform.instance.signIn(clientId: clientId);
  }
}
