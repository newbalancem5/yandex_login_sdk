/// Base exception for Yandex authorization failures.
class YandexAuthException implements Exception {
  const YandexAuthException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() =>
      'YandexAuthException(${code ?? '-'}): $message${details == null ? '' : ' [$details]'}';
}

/// Thrown when the user cancels the authorization flow.
///
/// Catch this separately to avoid showing an error UI on intentional cancel.
class YandexAuthCancelledException extends YandexAuthException {
  const YandexAuthCancelledException()
      : super('User cancelled Yandex authorization', code: 'CANCELLED');
}

/// Thrown when the plugin is invoked on a platform without native support
/// (e.g. desktop/web). Use this signal to fall back to your own WebView flow.
class YandexAuthUnsupportedException extends YandexAuthException {
  const YandexAuthUnsupportedException()
      : super(
          'Yandex Login SDK is not available on this platform',
          code: 'UNSUPPORTED',
        );
}

/// Thrown when `signIn` is called while another sign-in flow is already in
/// progress on the native side.
///
/// Wait for the first call to complete (or fail) before starting another one —
/// e.g. disable the login button while a sign-in is pending.
///
/// Subclass of [YandexAuthException], so existing `catch` / `on
/// YandexAuthException` sites keep working unchanged.
class YandexAuthInProgressException extends YandexAuthException {
  const YandexAuthInProgressException()
      : super('Another Yandex sign-in is already in progress', code: 'BUSY');
}

/// Thrown when Yandex rejects the access token (HTTP 401) while fetching user
/// info or a JWT — the token is expired, revoked, or invalidated by a password
/// change or a 2FA toggle.
///
/// Subclass of [YandexAuthException], so existing `catch` / `on
/// YandexAuthException` sites keep working unchanged.
class YandexAuthInvalidTokenException extends YandexAuthException {
  const YandexAuthInvalidTokenException()
      : super(
          'Yandex rejected the access token (HTTP 401)',
          code: 'UNAUTHORIZED',
        );
}
