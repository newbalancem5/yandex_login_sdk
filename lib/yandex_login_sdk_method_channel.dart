import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/yandex_auth_exception.dart';
import 'src/yandex_login_result.dart';
import 'yandex_login_sdk_platform_interface.dart';

class MethodChannelYandexLoginSdk extends YandexLoginSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('yandex_login_sdk');

  @override
  Future<YandexLoginResult> signIn({required String clientId}) async {
    if (clientId.isEmpty) {
      throw const YandexAuthException(
        'clientId must not be empty',
        code: 'BAD_ARGS',
      );
    }
    try {
      final raw = await methodChannel.invokeMapMethod<String, Object?>(
        'signIn',
        {'clientId': clientId},
      );
      final token = raw?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const YandexAuthException('Empty token in SDK response');
      }
      return YandexLoginResult(
        token: token,
        jwt: raw?['jwt'] as String?,
        expiresIn: (raw?['expiresIn'] as num?)?.toInt(),
      );
    } on MissingPluginException {
      throw const YandexAuthUnsupportedException();
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') throw const YandexAuthCancelledException();
      throw YandexAuthException(
        e.message ?? 'Yandex SDK error',
        code: e.code,
        details: e.details,
      );
    }
  }
}
