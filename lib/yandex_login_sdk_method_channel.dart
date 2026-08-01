import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/yandex_auth_exception.dart';
import 'src/yandex_log.dart';
import 'src/yandex_login_result.dart';
import 'src/yandex_login_strategy.dart';
import 'yandex_login_sdk_platform_interface.dart';

class MethodChannelYandexLoginSdk extends YandexLoginSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('yandex_login_sdk');

  bool _nativeLogForwardingInstalled = false;

  /// Routes `log` calls emitted by the native plugin layers into [YandexLog],
  /// prefixed with `[native]`. Installed lazily on first use so that merely
  /// constructing the platform instance needs no initialized binding.
  void _ensureNativeLogForwarding() {
    if (_nativeLogForwardingInstalled) return;
    _nativeLogForwardingInstalled = true;
    methodChannel.setMethodCallHandler((call) async {
      if (call.method != 'log') return null;
      final args = call.arguments;
      if (args is! Map) return null;
      final message = args['message'];
      if (message is! String) return null;
      final level = switch (args['level']) {
        'info' => YandexLogLevel.info,
        'warning' => YandexLogLevel.warning,
        'error' => YandexLogLevel.error,
        _ => YandexLogLevel.debug,
      };
      YandexLog.emit(level, '[native] $message');
      return null;
    });
  }

  @override
  Future<YandexLoginResult> signIn({
    required String clientId,
    YandexLoginStrategy strategy = YandexLoginStrategy.auto,
  }) async {
    if (clientId.isEmpty) {
      YandexLog.error('signIn() called with empty clientId');
      throw const YandexAuthException(
        'clientId must not be empty',
        code: 'BAD_ARGS',
      );
    }
    _ensureNativeLogForwarding();
    YandexLog.debug(
      'Invoking native signIn '
      '(clientId length=${clientId.length}, strategy=${strategy.name})',
    );
    try {
      final raw = await methodChannel.invokeMapMethod<String, Object?>(
        'signIn',
        {
          'clientId': clientId,
          'strategy': strategy.name,
          // The native side mirrors its diagnostics through the `log`
          // callback only while a Dart listener is actually installed.
          'nativeLogging': YandexLog.handler != null,
        },
      );
      final token = raw?['token'] as String?;
      if (token == null || token.isEmpty) {
        YandexLog.error('Native signIn returned empty token');
        throw const YandexAuthException('Empty token in SDK response');
      }
      YandexLog.debug('Native signIn returned token (length=${token.length})');
      return YandexLoginResult(
        token: token,
        jwt: raw?['jwt'] as String?,
        expiresIn: (raw?['expiresIn'] as num?)?.toInt(),
        issuedAt: DateTime.now(),
      );
    } on MissingPluginException {
      YandexLog.warn('No native plugin registered for the current platform');
      throw const YandexAuthUnsupportedException();
    } on PlatformException catch (e) {
      YandexLog.warn('Native signIn returned PlatformException(${e.code})');
      if (e.code == 'CANCELLED') throw const YandexAuthCancelledException();
      if (e.code == 'BUSY') throw const YandexAuthInProgressException();
      throw YandexAuthException(
        e.message ?? 'Yandex SDK error',
        code: e.code,
        details: e.details,
      );
    }
  }

  @override
  Future<void> signOut() async {
    _ensureNativeLogForwarding();
    YandexLog.debug('Invoking native signOut');
    try {
      await methodChannel.invokeMethod<void>('signOut');
      YandexLog.debug('Native signOut completed');
    } on MissingPluginException {
      YandexLog.warn('No native plugin registered for the current platform');
      throw const YandexAuthUnsupportedException();
    } on PlatformException catch (e) {
      YandexLog.warn('Native signOut returned PlatformException(${e.code})');
      throw YandexAuthException(
        e.message ?? 'Yandex SDK error',
        code: e.code,
        details: e.details,
      );
    }
  }
}
