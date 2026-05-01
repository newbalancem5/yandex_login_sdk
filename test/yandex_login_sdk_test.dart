import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';
import 'package:yandex_login_sdk/yandex_login_sdk_platform_interface.dart';

class _FakePlatform
    with MockPlatformInterfaceMixin
    implements YandexLoginSdkPlatform {
  YandexLoginResult? response;
  Object? error;
  String? lastClientId;

  @override
  Future<YandexLoginResult> signIn({required String clientId}) {
    lastClientId = clientId;
    if (error != null) return Future.error(error!);
    return Future.value(
      response ?? const YandexLoginResult(token: 'fake_token'),
    );
  }
}

void main() {
  late _FakePlatform fake;

  setUp(() {
    fake = _FakePlatform();
    YandexLoginSdkPlatform.instance = fake;
  });

  test('signIn forwards clientId to the platform implementation', () async {
    fake.response = const YandexLoginResult(token: 'tok');
    await YandexLoginSdk.signIn(clientId: 'my_client_id');
    expect(fake.lastClientId, 'my_client_id');
  });

  test('signIn returns the value from the platform', () async {
    fake.response = const YandexLoginResult(
      token: 'tok',
      jwt: 'jwt',
      expiresIn: 3600,
    );
    final r = await YandexLoginSdk.signIn(clientId: 'cid');
    expect(r.token, 'tok');
    expect(r.jwt, 'jwt');
    expect(r.expiresIn, 3600);
  });

  test('signIn propagates the cancelled exception', () async {
    fake.error = const YandexAuthCancelledException();
    expect(
      () => YandexLoginSdk.signIn(clientId: 'cid'),
      throwsA(isA<YandexAuthCancelledException>()),
    );
  });

  test('signIn propagates the unsupported exception', () async {
    fake.error = const YandexAuthUnsupportedException();
    expect(
      () => YandexLoginSdk.signIn(clientId: 'cid'),
      throwsA(isA<YandexAuthUnsupportedException>()),
    );
  });
}
