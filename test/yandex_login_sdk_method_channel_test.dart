import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';
import 'package:yandex_login_sdk/yandex_login_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelYandexLoginSdk();
  const channel = MethodChannel('yandex_login_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('parses success response with all fields', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'signIn');
      expect(call.arguments, {'clientId': 'cid'});
      return {'token': 'access_token', 'jwt': 'jwt_value', 'expiresIn': 3600};
    });

    final result = await platform.signIn(clientId: 'cid');

    expect(result.token, 'access_token');
    expect(result.jwt, 'jwt_value');
    expect(result.expiresIn, 3600);
  });

  test('parses minimal success response (only token)', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return {'token': 'just_a_token'};
    });

    final result = await platform.signIn(clientId: 'cid');

    expect(result.token, 'just_a_token');
    expect(result.jwt, isNull);
    expect(result.expiresIn, isNull);
  });

  test('throws on empty token in response', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return {'token': ''};
    });

    expect(
      () => platform.signIn(clientId: 'cid'),
      throwsA(
        isA<YandexAuthException>().having(
          (e) => e.message,
          'message',
          contains('Empty token'),
        ),
      ),
    );
  });

  test('throws on null response', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    expect(
      () => platform.signIn(clientId: 'cid'),
      throwsA(isA<YandexAuthException>()),
    );
  });

  test('rejects empty clientId before calling channel', () async {
    var channelCalled = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      channelCalled = true;
      return null;
    });

    expect(
      () => platform.signIn(clientId: ''),
      throwsA(
        isA<YandexAuthException>().having((e) => e.code, 'code', 'BAD_ARGS'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(channelCalled, isFalse);
  });

  test(
    'maps CANCELLED platform error to YandexAuthCancelledException',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'CANCELLED', message: 'User cancelled');
      });

      expect(
        () => platform.signIn(clientId: 'cid'),
        throwsA(isA<YandexAuthCancelledException>()),
      );
    },
  );

  test('maps generic PlatformException to YandexAuthException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'SDK_ERROR',
        message: 'Yandex blew up',
        details: 'stack',
      );
    });

    expect(
      () => platform.signIn(clientId: 'cid'),
      throwsA(
        isA<YandexAuthException>()
            .having((e) => e.code, 'code', 'SDK_ERROR')
            .having((e) => e.message, 'message', 'Yandex blew up')
            .having((e) => e.details, 'details', 'stack'),
      ),
    );
  });

  test('maps PlatformException with null message to fallback string', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'X');
    });

    expect(
      () => platform.signIn(clientId: 'cid'),
      throwsA(
        isA<YandexAuthException>().having(
          (e) => e.message,
          'message',
          'Yandex SDK error',
        ),
      ),
    );
  });

  test(
    'maps MissingPluginException to YandexAuthUnsupportedException',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('No implementation');
      });

      expect(
        () => platform.signIn(clientId: 'cid'),
        throwsA(isA<YandexAuthUnsupportedException>()),
      );
    },
  );
}
