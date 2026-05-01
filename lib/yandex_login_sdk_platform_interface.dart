import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/yandex_login_result.dart';
import 'yandex_login_sdk_method_channel.dart';

abstract class YandexLoginSdkPlatform extends PlatformInterface {
  YandexLoginSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static YandexLoginSdkPlatform _instance = MethodChannelYandexLoginSdk();

  static YandexLoginSdkPlatform get instance => _instance;

  static set instance(YandexLoginSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<YandexLoginResult> signIn({required String clientId}) {
    throw UnimplementedError('signIn() has not been implemented.');
  }
}
