import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'yandex_auth_exception.dart';
import 'yandex_log.dart';
import 'yandex_login_result.dart';
import 'yandex_login_sdk_api.dart';

/// A PKCE verifier/challenge pair (RFC 7636, `S256`).
typedef PkcePair = ({String verifier, String challenge});

/// Pure-Dart building blocks of the web OAuth flow (Authorization Code +
/// PKCE against `oauth.yandex.ru`). Kept free of any browser APIs so every
/// branch is unit-testable on the VM; the thin `YandexLoginSdkWeb` glue owns
/// the popup and messaging.
abstract final class YandexWebOAuth {
  static const String _authHost = 'oauth.yandex.ru';

  static final Random _random = Random.secure();

  /// URL-safe random token (CSRF `state`, PKCE verifier).
  static String generateRandomToken([int bytes = 32]) {
    final data = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return base64UrlEncode(data).replaceAll('=', '');
  }

  /// Generates a PKCE `code_verifier` and its `S256` challenge.
  static PkcePair createPkcePair() {
    final verifier = generateRandomToken(48); // 64 chars, within 43..128.
    final challenge =
        base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
            .replaceAll('=', '');
    return (verifier: verifier, challenge: challenge);
  }

  /// Builds the `oauth.yandex.ru/authorize` URL for the popup.
  static Uri buildAuthorizeUrl({
    required String clientId,
    required String redirectUri,
    required String state,
    required String codeChallenge,
  }) =>
      Uri.https(_authHost, '/authorize', {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

  /// Parses the `search + hash` payload relayed by the callback page and
  /// returns the authorization `code`.
  ///
  /// Throws [YandexAuthCancelledException] on `error=access_denied`,
  /// [YandexAuthException] with the OAuth `error` code on other errors, code
  /// `STATE_MISMATCH` when the CSRF state does not match, and `BAD_RESPONSE`
  /// when no code is present.
  static String parseCallback(String payload, {required String expectedState}) {
    final hashIndex = payload.indexOf('#');
    final search = hashIndex >= 0 ? payload.substring(0, hashIndex) : payload;
    final fragment = hashIndex >= 0 ? payload.substring(hashIndex + 1) : '';
    final params = <String, String>{
      ...Uri.splitQueryString(fragment),
      ...Uri.splitQueryString(
        search.startsWith('?') ? search.substring(1) : search,
      ),
    };

    final error = params['error'];
    if (error != null) {
      if (error == 'access_denied') {
        YandexLog.info('signIn() denied by user on the Yandex consent page');
        throw const YandexAuthCancelledException();
      }
      YandexLog.error('signIn() OAuth error: $error');
      throw YandexAuthException(
        params['error_description'] ?? 'Yandex OAuth error: $error',
        code: error,
      );
    }
    if (params['state'] != expectedState) {
      YandexLog.error('signIn() state mismatch in OAuth callback');
      throw const YandexAuthException(
        'OAuth state mismatch — possible CSRF, result discarded',
        code: 'STATE_MISMATCH',
      );
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      YandexLog.error('signIn() callback carried no authorization code');
      throw const YandexAuthException(
        'No authorization code in OAuth callback',
        code: 'BAD_RESPONSE',
      );
    }
    return code;
  }

  /// Exchanges the authorization [code] for an access token
  /// (`POST oauth.yandex.ru/token`, PKCE — no client secret involved).
  ///
  /// Closes the client only when it created one (a caller-supplied
  /// [httpClient] is left open for reuse).
  static Future<YandexLoginResult> exchangeCode({
    required String code,
    required String clientId,
    required String codeVerifier,
    http.Client? httpClient,
  }) async {
    // Shares the same default-client hook as getUserInfo/getJwt so tests
    // (ours and consumers') can stub every HTTP path through one seam.
    // ignore: invalid_use_of_visible_for_testing_member
    final client = httpClient ?? YandexLoginSdk.httpClientFactory();
    try {
      final response = await client.post(
        Uri.https(_authHost, '/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': clientId,
          'code_verifier': codeVerifier,
        },
      );
      final status = response.statusCode;
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } on FormatException {
        body = null;
      }
      if (status == 200) {
        final token = body?['access_token'];
        if (token is! String || token.isEmpty) {
          YandexLog.error('token exchange returned a malformed body');
          throw const YandexAuthException(
            'Malformed token response from Yandex',
            code: 'BAD_RESPONSE',
          );
        }
        YandexLog.debug('token exchange succeeded');
        return YandexLoginResult(
          token: token,
          expiresIn: (body?['expires_in'] as num?)?.toInt(),
          issuedAt: DateTime.now(),
        );
      }
      final error = body?['error'] as String?;
      YandexLog.error('token exchange failed: HTTP $status ${error ?? ''}');
      throw YandexAuthException(
        (body?['error_description'] as String?) ??
            'Yandex token endpoint returned HTTP $status',
        code: error ?? 'HTTP_$status',
      );
    } on YandexAuthException {
      rethrow;
    } catch (e, st) {
      YandexLog.error('token exchange transport failure',
          error: e, stackTrace: st);
      throw YandexAuthException(
        'Network error exchanging the authorization code: $e',
        code: 'CONNECTION_ERROR',
        details: e,
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
