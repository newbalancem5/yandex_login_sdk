import '../yandex_login_sdk_platform_interface.dart';
import 'yandex_auth_exception.dart';
import 'yandex_log.dart';
import 'yandex_login_result.dart';

/// Entry point for the Yandex Login SDK plugin.
abstract final class YandexLoginSdk {
  /// Optional log listener.
  ///
  /// Set this to receive diagnostic events from the plugin — start/finish of
  /// the sign-in flow, cancellation, fallback paths, mapped error codes.
  /// Defaults to `null`, which silences all output.
  ///
  /// ```dart
  /// YandexLoginSdk.onLog = (level, message, {error, stackTrace}) {
  ///   // forward to your logger of choice
  ///   print('[yandex_login_sdk:${level.name}] $message');
  /// };
  /// ```
  static set onLog(YandexLogHandler? handler) => YandexLog.handler = handler;

  /// Currently installed log handler.
  static YandexLogHandler? get onLog => YandexLog.handler;

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
  static Future<YandexLoginResult> signIn({required String clientId}) async {
    YandexLog.info('signIn() invoked');
    try {
      final result = await YandexLoginSdkPlatform.instance.signIn(
        clientId: clientId,
      );
      YandexLog.info('signIn() succeeded');
      return result;
    } on YandexAuthCancelledException {
      YandexLog.info('signIn() cancelled by user');
      rethrow;
    } on YandexAuthUnsupportedException {
      YandexLog.warn('signIn() unsupported on this platform');
      rethrow;
    } on YandexAuthException catch (e, st) {
      YandexLog.error(
        'signIn() failed: ${e.code ?? '-'} ${e.message}',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
