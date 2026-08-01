import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';

/// An [http.Client] that records whether [close] was called and delegates
/// requests to a handler — used to assert the caller's client is left open.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._handler);

  final Future<http.Response> Function(http.Request) _handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => closed = true;
}

const _minimalProfile = '{"id":"1","login":"l","client_id":"c"}';

void main() {
  group('getUserInfo', () {
    test('issues GET /info with the OAuth header and format=json', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(_minimalProfile, 200);
      });

      await YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client);

      expect(captured.method, 'GET');
      expect(captured.url.host, 'login.yandex.ru');
      expect(captured.url.path, '/info');
      expect(captured.url.queryParameters['format'], 'json');
      expect(captured.headers['Authorization'], 'OAuth TKN');
    });

    test('parses the profile body', () async {
      final client = MockClient(
        (req) async => http.Response(
          '{"id":"42","login":"vasya","client_id":"c","default_email":"v@ya.ru"}',
          200,
        ),
      );

      final info = await YandexLoginSdk.getUserInfo(
        token: 'TKN',
        httpClient: client,
      );

      expect(info.id, '42');
      expect(info.defaultEmail, 'v@ya.ru');
    });

    test('throws YandexAuthInvalidTokenException on HTTP 401', () async {
      final client = MockClient((req) async => http.Response('no', 401));
      expect(
        () => YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client),
        throwsA(
          isA<YandexAuthInvalidTokenException>()
              .having((e) => e.code, 'code', 'UNAUTHORIZED'),
        ),
      );
    });

    test('throws YandexAuthException(HTTP_500) on a server error', () async {
      final client = MockClient((req) async => http.Response('boom', 500));
      expect(
        () => YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client),
        throwsA(
          isA<YandexAuthException>().having((e) => e.code, 'code', 'HTTP_500'),
        ),
      );
    });

    test('maps a transport failure to CONNECTION_ERROR', () async {
      final client = MockClient((req) async => throw Exception('network down'));
      expect(
        () => YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'CONNECTION_ERROR'),
        ),
      );
    });

    test('maps an elapsed timeout to TIMEOUT', () async {
      final client = MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(_minimalProfile, 200);
      });
      expect(
        () => YandexLoginSdk.getUserInfo(
          token: 'TKN',
          httpClient: client,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(
          isA<YandexAuthException>().having((e) => e.code, 'code', 'TIMEOUT'),
        ),
      );
    });

    test('succeeds when the response arrives within the timeout', () async {
      final client = MockClient(
        (req) async => http.Response(_minimalProfile, 200),
      );

      final info = await YandexLoginSdk.getUserInfo(
        token: 'TKN',
        httpClient: client,
        timeout: const Duration(seconds: 5),
      );

      expect(info.id, '1');
    });

    test('rejects an empty token before issuing any request', () async {
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return http.Response(_minimalProfile, 200);
      });

      expect(
        () => YandexLoginSdk.getUserInfo(token: '', httpClient: client),
        throwsA(
          isA<YandexAuthException>().having((e) => e.code, 'code', 'BAD_ARGS'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(called, isFalse);
    });

    test('maps a non-JSON body to BAD_RESPONSE', () async {
      final client = MockClient((req) async => http.Response('not json', 200));
      expect(
        () => YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'BAD_RESPONSE'),
        ),
      );
    });

    test('maps a non-object JSON body to BAD_RESPONSE', () async {
      final client = MockClient((req) async => http.Response('[]', 200));
      expect(
        () => YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'BAD_RESPONSE'),
        ),
      );
    });

    test('maps a wrongly-typed field (valid JSON object) to BAD_RESPONSE',
        () async {
      // 200 + valid JSON object, but `login` is a number — the cast in
      // fromJson throws a TypeError, which must still surface as BAD_RESPONSE.
      final client = MockClient(
        (req) async => http.Response('{"id":"1","login":123}', 200),
      );
      expect(
        () => YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'BAD_RESPONSE'),
        ),
      );
    });
  });

  group('getJwt', () {
    test('issues GET /info with format=jwt and returns the body verbatim',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('the.jwt.token', 200);
      });

      final jwt = await YandexLoginSdk.getJwt(token: 'TKN', httpClient: client);

      expect(jwt, 'the.jwt.token');
      expect(captured.url.queryParameters['format'], 'jwt');
      expect(captured.headers['Authorization'], 'OAuth TKN');
      expect(captured.url.queryParameters.containsKey('jwt_secret'), isFalse);
    });

    test('appends jwt_secret when provided', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('jwt', 200);
      });

      await YandexLoginSdk.getJwt(
        token: 'TKN',
        jwtSecret: 'sec',
        httpClient: client,
      );

      expect(captured.url.queryParameters['jwt_secret'], 'sec');
    });

    test('throws YandexAuthInvalidTokenException on HTTP 401', () async {
      final client = MockClient((req) async => http.Response('no', 401));
      expect(
        () => YandexLoginSdk.getJwt(token: 'TKN', httpClient: client),
        throwsA(isA<YandexAuthInvalidTokenException>()),
      );
    });

    test('maps a transport failure to CONNECTION_ERROR', () async {
      final client = MockClient((req) async => throw Exception('down'));
      expect(
        () => YandexLoginSdk.getJwt(token: 'TKN', httpClient: client),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'CONNECTION_ERROR'),
        ),
      );
    });

    test('rejects an empty token', () async {
      final client = MockClient((req) async => http.Response('jwt', 200));
      expect(
        () => YandexLoginSdk.getJwt(token: '', httpClient: client),
        throwsA(
          isA<YandexAuthException>().having((e) => e.code, 'code', 'BAD_ARGS'),
        ),
      );
    });

    test('maps an elapsed timeout to TIMEOUT', () async {
      final client = MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('jwt', 200);
      });
      expect(
        () => YandexLoginSdk.getJwt(
          token: 'TKN',
          httpClient: client,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(
          isA<YandexAuthException>().having((e) => e.code, 'code', 'TIMEOUT'),
        ),
      );
    });
  });

  group('client lifecycle', () {
    test('does not close a caller-supplied client', () async {
      final client = _RecordingClient(
        (req) async => http.Response(_minimalProfile, 200),
      );

      await YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client);

      expect(client.closed, isFalse);
    });

    test('creates and closes its own client when none is supplied', () async {
      final client = _RecordingClient(
        (req) async => http.Response(_minimalProfile, 200),
      );
      YandexLoginSdk.httpClientFactory = () => client;
      addTearDown(() => YandexLoginSdk.httpClientFactory = http.Client.new);

      await YandexLoginSdk.getUserInfo(token: 'TKN');

      expect(client.closed, isTrue);
    });

    test('closes its own client even when the request fails', () async {
      final client = _RecordingClient(
        (req) async => http.Response('no', 401),
      );
      YandexLoginSdk.httpClientFactory = () => client;
      addTearDown(() => YandexLoginSdk.httpClientFactory = http.Client.new);

      await expectLater(
        YandexLoginSdk.getUserInfo(token: 'TKN'),
        throwsA(isA<YandexAuthInvalidTokenException>()),
      );

      expect(client.closed, isTrue);
    });

    test('does not close a caller-supplied client on error', () async {
      final client = _RecordingClient((req) async => throw Exception('down'));

      await expectLater(
        YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'CONNECTION_ERROR'),
        ),
      );

      expect(client.closed, isFalse);
    });
  });

  group('onLog', () {
    setUp(() => YandexLoginSdk.onLog = null);
    tearDown(() => YandexLoginSdk.onLog = null);

    test('getUserInfo emits an info event on success', () async {
      final levels = <YandexLogLevel>[];
      YandexLoginSdk.onLog =
          (level, message, {error, stackTrace}) => levels.add(level);
      final client = MockClient(
        (req) async => http.Response(_minimalProfile, 200),
      );

      await YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client);

      expect(levels, contains(YandexLogLevel.info));
    });

    test('getUserInfo emits a warning event on 401', () async {
      final levels = <YandexLogLevel>[];
      YandexLoginSdk.onLog =
          (level, message, {error, stackTrace}) => levels.add(level);
      final client = MockClient((req) async => http.Response('no', 401));

      await expectLater(
        YandexLoginSdk.getUserInfo(token: 'TKN', httpClient: client),
        throwsA(isA<YandexAuthInvalidTokenException>()),
      );

      expect(levels, contains(YandexLogLevel.warning));
    });

    test('getJwt emits a debug event with the JWT length on success', () async {
      final messages = <String>[];
      YandexLoginSdk.onLog =
          (level, message, {error, stackTrace}) => messages.add(message);
      final client = MockClient((req) async => http.Response('abc', 200));

      await YandexLoginSdk.getJwt(token: 'TKN', httpClient: client);

      expect(messages, contains('getJwt() received JWT (length=3)'));
    });
  });
}
