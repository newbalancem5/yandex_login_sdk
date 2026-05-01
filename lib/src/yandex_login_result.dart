/// Successful Yandex authorization result.
class YandexLoginResult {
  const YandexLoginResult({required this.token, this.jwt, this.expiresIn});

  /// OAuth 2.0 access token issued by Yandex.
  final String token;

  /// Yandex-issued JWT.
  ///
  /// Provided by the iOS SDK along with the access token. On Android the JWT
  /// is fetched separately and is not currently exposed; this field will be
  /// `null` on Android.
  final String? jwt;

  /// Token lifetime in seconds.
  ///
  /// Provided by the Android SDK; `null` on iOS.
  final int? expiresIn;

  @override
  String toString() =>
      'YandexLoginResult(token: ${_redact(token)}, jwt: ${jwt == null ? 'null' : _redact(jwt!)}, expiresIn: $expiresIn)';

  static String _redact(String s) => s.length <= 6
      ? '***'
      : '${s.substring(0, 4)}…${s.substring(s.length - 2)}';
}
