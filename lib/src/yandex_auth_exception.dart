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
