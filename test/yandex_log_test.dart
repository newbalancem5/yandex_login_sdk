import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:yandex_login_sdk/src/yandex_log.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';
import 'package:yandex_login_sdk/yandex_login_sdk_platform_interface.dart';

class _SuccessPlatform
    with MockPlatformInterfaceMixin
    implements YandexLoginSdkPlatform {
  @override
  Future<YandexLoginResult> signIn({required String clientId}) async =>
      const YandexLoginResult(token: 'tok');
}

class _ErrorPlatform
    with MockPlatformInterfaceMixin
    implements YandexLoginSdkPlatform {
  _ErrorPlatform(this.error);
  final Object error;
  @override
  Future<YandexLoginResult> signIn({required String clientId}) =>
      Future.error(error);
}

class _Captured {
  _Captured(this.level, this.message, {this.error, this.stackTrace});
  final YandexLogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}

void main() {
  late List<_Captured> events;

  setUp(() {
    events = [];
    YandexLoginSdk.onLog = (level, message, {error, stackTrace}) {
      events.add(
        _Captured(level, message, error: error, stackTrace: stackTrace),
      );
    };
  });

  tearDown(() => YandexLoginSdk.onLog = null);

  test('YandexLog.emit is a no-op when no handler is set', () {
    YandexLog.handler = null;
    expect(() => YandexLog.info('ignored'), returnsNormally);
  });

  test('YandexLoginSdk.onLog setter wires through to YandexLog.handler', () {
    YandexLog.info('hello');
    expect(events, hasLength(1));
    expect(events.single.level, YandexLogLevel.info);
    expect(events.single.message, 'hello');
  });

  test('onLog getter returns currently installed handler', () {
    expect(YandexLoginSdk.onLog, isNotNull);
    YandexLoginSdk.onLog = null;
    expect(YandexLoginSdk.onLog, isNull);
  });

  test('all severity helpers route through emit', () {
    YandexLog.debug('d');
    YandexLog.info('i');
    YandexLog.warn('w');
    YandexLog.error('e');

    expect(events.map((e) => e.level), [
      YandexLogLevel.debug,
      YandexLogLevel.info,
      YandexLogLevel.warning,
      YandexLogLevel.error,
    ]);
  });

  test('warn and error pass through error + stackTrace', () {
    final st = StackTrace.current;
    final err = Exception('boom');
    YandexLog.warn('warn-msg', error: err, stackTrace: st);
    YandexLog.error('err-msg', error: err, stackTrace: st);

    expect(events[0].error, err);
    expect(events[0].stackTrace, st);
    expect(events[1].error, err);
    expect(events[1].stackTrace, st);
  });

  test('signIn() emits info on success', () async {
    YandexLoginSdkPlatform.instance = _SuccessPlatform();
    await YandexLoginSdk.signIn(clientId: 'cid');

    final messages = events.map((e) => e.message).toList();
    expect(messages, contains('signIn() invoked'));
    expect(messages, contains('signIn() succeeded'));
  });

  test('signIn() emits info on cancellation', () async {
    YandexLoginSdkPlatform.instance = _ErrorPlatform(
      const YandexAuthCancelledException(),
    );
    await expectLater(
      YandexLoginSdk.signIn(clientId: 'cid'),
      throwsA(isA<YandexAuthCancelledException>()),
    );

    expect(
      events.map((e) => e.message),
      contains('signIn() cancelled by user'),
    );
  });

  test('signIn() emits warning on unsupported platform', () async {
    YandexLoginSdkPlatform.instance = _ErrorPlatform(
      const YandexAuthUnsupportedException(),
    );
    await expectLater(
      YandexLoginSdk.signIn(clientId: 'cid'),
      throwsA(isA<YandexAuthUnsupportedException>()),
    );

    expect(
      events.singleWhere((e) => e.level == YandexLogLevel.warning).message,
      contains('unsupported'),
    );
  });

  test('signIn() emits error on generic SDK failure', () async {
    YandexLoginSdkPlatform.instance = _ErrorPlatform(
      const YandexAuthException('boom', code: 'X'),
    );
    await expectLater(
      YandexLoginSdk.signIn(clientId: 'cid'),
      throwsA(isA<YandexAuthException>()),
    );

    final errEvents =
        events.where((e) => e.level == YandexLogLevel.error).toList();
    expect(errEvents, hasLength(1));
    expect(errEvents.single.message, contains('X boom'));
    expect(errEvents.single.error, isA<YandexAuthException>());
    expect(errEvents.single.stackTrace, isNotNull);
  });
}
