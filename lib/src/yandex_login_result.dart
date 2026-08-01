/// Successful Yandex authorization result.
class YandexLoginResult {
  const YandexLoginResult({
    required this.token,
    this.jwt,
    this.expiresIn,
    this.issuedAt,
  });

  /// OAuth 2.0 access token issued by Yandex.
  final String token;

  /// Yandex-issued JWT.
  ///
  /// Populated natively on **iOS** (from `LoginResult.jwt`); `null` on
  /// **Android** (the native `authsdk` does not return it here). For a JWT that
  /// is identical on both platforms, call `YandexLoginSdk.getJwt` instead.
  final String? jwt;

  /// Access-token lifetime in **seconds**, relative to the moment of issuance
  /// (the OAuth 2.0 `expires_in`) — *not* an absolute timestamp. See
  /// [expiresAt] for the absolute variant.
  ///
  /// Provided on **Android**; always `null` on **iOS** — the iOS SDK discards
  /// the OAuth `expires_in` and exposes no token expiry.
  final int? expiresIn;

  /// Moment this result was received on the Dart side. Set by the plugin when
  /// the native response arrives; `null` only for hand-constructed instances.
  final DateTime? issuedAt;

  /// Absolute expiry time ([issuedAt] + [expiresIn]), or `null` when either
  /// component is unavailable (always `null` on iOS — see [expiresIn]).
  DateTime? get expiresAt {
    final issued = issuedAt;
    final ttl = expiresIn;
    if (issued == null || ttl == null) return null;
    return issued.add(Duration(seconds: ttl));
  }

  @override
  String toString() =>
      'YandexLoginResult(token: ${_redact(token)}, jwt: ${jwt == null ? 'null' : _redact(jwt!)}, expiresIn: $expiresIn)';

  static String _redact(String s) => s.length <= 6
      ? '***'
      : '${s.substring(0, 4)}…${s.substring(s.length - 2)}';
}
