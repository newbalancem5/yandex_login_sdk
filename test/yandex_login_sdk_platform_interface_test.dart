import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';
import 'package:yandex_login_sdk/yandex_login_sdk_method_channel.dart';
import 'package:yandex_login_sdk/yandex_login_sdk_platform_interface.dart';

class _IncompletePlatform extends YandexLoginSdkPlatform {}

class _MockedPlatform
    with MockPlatformInterfaceMixin
    implements YandexLoginSdkPlatform {
  @override
  Future<YandexLoginResult> signIn({required String clientId}) async =>
      const YandexLoginResult(token: 'tok');
}

void main() {
  test('default instance is the method-channel implementation', () {
    expect(YandexLoginSdkPlatform.instance, isA<MethodChannelYandexLoginSdk>());
  });

  test('default signIn implementation throws UnimplementedError', () {
    final base = _IncompletePlatform();
    expect(
      () => base.signIn(clientId: 'x'),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test(
    'instance setter accepts platforms that mix in the verification token',
    () {
      final mock = _MockedPlatform();
      YandexLoginSdkPlatform.instance = mock;
      expect(YandexLoginSdkPlatform.instance, same(mock));
    },
  );
}
