import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yandex_login_sdk/src/yandex_web_oauth.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';

void main() {
  group('generateRandomToken', () {
    test('is URL-safe, unpadded and unique', () {
      final a = YandexWebOAuth.generateRandomToken();
      final b = YandexWebOAuth.generateRandomToken();
      expect(a, isNot(b));
      expect(a, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(a.length, greaterThanOrEqualTo(43));
    });
  });

  group('createPkcePair', () {
    test('challenge is the unpadded base64url S256 of the verifier', () {
      final pair = YandexWebOAuth.createPkcePair();
      expect(pair.verifier.length, inInclusiveRange(43, 128));
      expect(pair.verifier, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      final expected =
          base64UrlEncode(sha256.convert(ascii.encode(pair.verifier)).bytes)
              .replaceAll('=', '');
      expect(pair.challenge, expected);
    });
  });

  group('buildAuthorizeUrl', () {
    test('carries every OAuth parameter', () {
      final url = YandexWebOAuth.buildAuthorizeUrl(
        clientId: 'cid',
        redirectUri: 'https://app.example/yandex_auth_callback.html',
        state: 'st',
        codeChallenge: 'ch',
      );
      expect(url.host, 'oauth.yandex.ru');
      expect(url.path, '/authorize');
      expect(url.queryParameters, {
        'response_type': 'code',
        'client_id': 'cid',
        'redirect_uri': 'https://app.example/yandex_auth_callback.html',
        'state': 'st',
        'code_challenge': 'ch',
        'code_challenge_method': 'S256',
      });
    });
  });

  group('parseCallback', () {
    test('returns the code on a valid payload', () {
      final code = YandexWebOAuth.parseCallback(
        '?code=abc&state=st',
        expectedState: 'st',
      );
      expect(code, 'abc');
    });

    test('reads parameters from the fragment as well', () {
      final code = YandexWebOAuth.parseCallback(
        '#code=abc&state=st',
        expectedState: 'st',
      );
      expect(code, 'abc');
    });

    test('maps access_denied to YandexAuthCancelledException', () {
      expect(
        () => YandexWebOAuth.parseCallback(
          '?error=access_denied&state=st',
          expectedState: 'st',
        ),
        throwsA(isA<YandexAuthCancelledException>()),
      );
    });

    test('maps other OAuth errors to YandexAuthException with the code', () {
      expect(
        () => YandexWebOAuth.parseCallback(
          '?error=server_error&error_description=boom&state=st',
          expectedState: 'st',
        ),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'server_error')
              .having((e) => e.message, 'message', 'boom'),
        ),
      );
    });

    test('falls back to a generic message without error_description', () {
      expect(
        () => YandexWebOAuth.parseCallback(
          '?error=server_error&state=st',
          expectedState: 'st',
        ),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.message, 'message', contains('server_error')),
        ),
      );
    });

    test('rejects a state mismatch', () {
      expect(
        () => YandexWebOAuth.parseCallback(
          '?code=abc&state=evil',
          expectedState: 'st',
        ),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'STATE_MISMATCH'),
        ),
      );
    });

    test('rejects a payload without a code', () {
      expect(
        () => YandexWebOAuth.parseCallback('?state=st', expectedState: 'st'),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'BAD_RESPONSE'),
        ),
      );
    });
  });

  group('exchangeCode', () {
    test('POSTs the PKCE parameters and parses the token', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          '{"access_token":"tok","expires_in":31536000,"token_type":"bearer"}',
          200,
        );
      });

      final result = await YandexWebOAuth.exchangeCode(
        code: 'abc',
        clientId: 'cid',
        codeVerifier: 'ver',
        httpClient: client,
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://oauth.yandex.ru/token');
      expect(captured.bodyFields, {
        'grant_type': 'authorization_code',
        'code': 'abc',
        'client_id': 'cid',
        'code_verifier': 'ver',
      });
      expect(result.token, 'tok');
      expect(result.expiresIn, 31536000);
      expect(result.issuedAt, isNotNull);
      expect(result.jwt, isNull);
    });

    test('maps an OAuth error body to its error code', () {
      final client = MockClient(
        (req) async => http.Response(
          '{"error":"invalid_grant","error_description":"Code expired"}',
          400,
        ),
      );
      expect(
        () => YandexWebOAuth.exchangeCode(
          code: 'abc',
          clientId: 'cid',
          codeVerifier: 'ver',
          httpClient: client,
        ),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'invalid_grant')
              .having((e) => e.message, 'message', 'Code expired'),
        ),
      );
    });

    test('maps a non-JSON error response to HTTP_<status>', () {
      final client = MockClient((req) async => http.Response('oops', 502));
      expect(
        () => YandexWebOAuth.exchangeCode(
          code: 'abc',
          clientId: 'cid',
          codeVerifier: 'ver',
          httpClient: client,
        ),
        throwsA(
          isA<YandexAuthException>().having((e) => e.code, 'code', 'HTTP_502'),
        ),
      );
    });

    test('maps a malformed 200 body to BAD_RESPONSE', () {
      final client = MockClient(
        (req) async => http.Response('{"token_type":"bearer"}', 200),
      );
      expect(
        () => YandexWebOAuth.exchangeCode(
          code: 'abc',
          clientId: 'cid',
          codeVerifier: 'ver',
          httpClient: client,
        ),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'BAD_RESPONSE'),
        ),
      );
    });

    test('maps a non-JSON 200 body to BAD_RESPONSE', () {
      final client = MockClient((req) async => http.Response('not json', 200));
      expect(
        () => YandexWebOAuth.exchangeCode(
          code: 'abc',
          clientId: 'cid',
          codeVerifier: 'ver',
          httpClient: client,
        ),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'BAD_RESPONSE'),
        ),
      );
    });

    test('maps a transport failure to CONNECTION_ERROR', () {
      final client = MockClient((req) async => throw Exception('down'));
      expect(
        () => YandexWebOAuth.exchangeCode(
          code: 'abc',
          clientId: 'cid',
          codeVerifier: 'ver',
          httpClient: client,
        ),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'CONNECTION_ERROR'),
        ),
      );
    });

    test('does not close a caller-supplied client', () async {
      var closed = false;
      final inner = MockClient(
        (req) async => http.Response(
          '{"access_token":"tok","expires_in":10}',
          200,
        ),
      );
      final client = _CloseTrackingClient(inner, () => closed = true);

      await YandexWebOAuth.exchangeCode(
        code: 'abc',
        clientId: 'cid',
        codeVerifier: 'ver',
        httpClient: client,
      );

      expect(closed, isFalse);
    });

    test('creates and closes its own client when none is supplied', () async {
      var closed = false;
      final inner = MockClient(
        (req) async => http.Response(
          '{"access_token":"tok","expires_in":10}',
          200,
        ),
      );
      YandexLoginSdk.httpClientFactory =
          () => _CloseTrackingClient(inner, () => closed = true);
      addTearDown(() => YandexLoginSdk.httpClientFactory = http.Client.new);

      final result = await YandexWebOAuth.exchangeCode(
        code: 'abc',
        clientId: 'cid',
        codeVerifier: 'ver',
      );

      expect(result.token, 'tok');
      expect(closed, isTrue);
    });
  });
}

class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient(this._inner, this._onClose);
  final http.Client _inner;
  final void Function() _onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() => _onClose();
}
