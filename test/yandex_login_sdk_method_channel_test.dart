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
      expect(call.arguments, {
        'clientId': 'cid',
        'strategy': 'auto',
        'nativeLogging': false,
      });
      return {'token': 'access_token', 'jwt': 'jwt_value', 'expiresIn': 3600};
    });

    final before = DateTime.now();
    final result = await platform.signIn(clientId: 'cid');
    final after = DateTime.now();

    expect(result.token, 'access_token');
    expect(result.jwt, 'jwt_value');
    expect(result.expiresIn, 3600);
    expect(result.issuedAt, isNotNull);
    expect(result.issuedAt!.isBefore(before), isFalse);
    expect(result.issuedAt!.isAfter(after), isFalse);
    expect(
      result.expiresAt,
      result.issuedAt!.add(const Duration(seconds: 3600)),
    );
  });

  test('passes the webOnly strategy over the channel', () async {
    Object? sentArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sentArguments = call.arguments;
      return {'token': 'tok'};
    });

    await platform.signIn(
      clientId: 'cid',
      strategy: YandexLoginStrategy.webOnly,
    );

    expect(sentArguments, {
      'clientId': 'cid',
      'strategy': 'webOnly',
      'nativeLogging': false,
    });
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

  test('maps BUSY platform error to YandexAuthInProgressException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'BUSY', message: 'Another sign-in');
    });

    expect(
      () => platform.signIn(clientId: 'cid'),
      throwsA(
        isA<YandexAuthInProgressException>()
            .having((e) => e.code, 'code', 'BUSY'),
      ),
    );
  });

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

  group('signOut', () {
    test('invokes the native signOut method', () async {
      var invoked = '';
      messenger.setMockMethodCallHandler(channel, (call) async {
        invoked = call.method;
        return null;
      });

      await platform.signOut();

      expect(invoked, 'signOut');
    });

    test('maps MissingPluginException to YandexAuthUnsupportedException',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('No implementation');
      });

      expect(
        () => platform.signOut(),
        throwsA(isA<YandexAuthUnsupportedException>()),
      );
    });

    test('maps a PlatformException to YandexAuthException', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'SDK_ERROR', message: 'boom');
      });

      expect(
        () => platform.signOut(),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.code, 'code', 'SDK_ERROR')
              .having((e) => e.message, 'message', 'boom'),
        ),
      );
    });

    test('falls back to a default message on a null-message error', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'X');
      });

      expect(
        () => platform.signOut(),
        throwsA(
          isA<YandexAuthException>()
              .having((e) => e.message, 'message', 'Yandex SDK error'),
        ),
      );
    });
  });

  group('native log forwarding', () {
    const codec = StandardMethodCodec();

    Future<void> sendFromNative(MethodCall call) =>
        messenger.handlePlatformMessage(
          'yandex_login_sdk',
          codec.encodeMethodCall(call),
          (_) {},
        );

    late List<(YandexLogLevel, String)> events;

    setUp(() async {
      events = [];
      YandexLoginSdk.onLog =
          (level, message, {error, stackTrace}) => events.add((level, message));
      // signIn installs the channel handler and reports nativeLogging=true.
      Object? sentArguments;
      messenger.setMockMethodCallHandler(channel, (call) async {
        sentArguments = call.arguments;
        return {'token': 'tok'};
      });
      await platform.signIn(clientId: 'cid');
      expect(
        (sentArguments as Map?)?['nativeLogging'],
        isTrue,
        reason: 'nativeLogging must be true while a handler is installed',
      );
      events.clear();
    });

    tearDown(() => YandexLoginSdk.onLog = null);

    test('routes every level into YandexLoginSdk.onLog with a prefix',
        () async {
      await sendFromNative(
        const MethodCall('log', {'level': 'debug', 'message': 'd'}),
      );
      await sendFromNative(
        const MethodCall('log', {'level': 'info', 'message': 'i'}),
      );
      await sendFromNative(
        const MethodCall('log', {'level': 'warning', 'message': 'w'}),
      );
      await sendFromNative(
        const MethodCall('log', {'level': 'error', 'message': 'e'}),
      );

      expect(events, [
        (YandexLogLevel.debug, '[native] d'),
        (YandexLogLevel.info, '[native] i'),
        (YandexLogLevel.warning, '[native] w'),
        (YandexLogLevel.error, '[native] e'),
      ]);
    });

    test('treats an unknown level as debug', () async {
      await sendFromNative(
        const MethodCall('log', {'level': 'wat', 'message': 'm'}),
      );
      expect(events, [(YandexLogLevel.debug, '[native] m')]);
    });

    test('ignores malformed or unrelated native calls', () async {
      await sendFromNative(const MethodCall('log', 'not-a-map'));
      await sendFromNative(const MethodCall('log', {'level': 'info'}));
      await sendFromNative(const MethodCall('somethingElse'));
      expect(events, isEmpty);
    });
  });
}
