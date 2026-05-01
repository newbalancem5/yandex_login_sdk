import 'package:flutter_test/flutter_test.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';

void main() {
  group('YandexLoginResult', () {
    test('keeps all provided fields', () {
      const r = YandexLoginResult(
        token: 'access_token_value',
        jwt: 'jwt_value',
        expiresIn: 3600,
      );
      expect(r.token, 'access_token_value');
      expect(r.jwt, 'jwt_value');
      expect(r.expiresIn, 3600);
    });

    test('jwt and expiresIn default to null', () {
      const r = YandexLoginResult(token: 'tok');
      expect(r.jwt, isNull);
      expect(r.expiresIn, isNull);
    });

    test('toString redacts long token and jwt', () {
      const r = YandexLoginResult(
        token: 'abcdefghijklmnop',
        jwt: 'qrstuvwxyz12345',
        expiresIn: 60,
      );
      final s = r.toString();
      expect(s, contains('abcd…op'));
      expect(s, contains('qrst…45'));
      expect(s, contains('60'));
      expect(s, isNot(contains('abcdefghijklmnop')));
    });

    test('toString masks short tokens entirely', () {
      const r = YandexLoginResult(token: 'short', jwt: 'tiny');
      final s = r.toString();
      expect(s, contains('***'));
      expect(s, isNot(contains('short')));
      expect(s, isNot(contains('tiny')));
    });

    test('toString prints null jwt as null literal', () {
      const r = YandexLoginResult(token: 'access_token_value');
      expect(r.toString(), contains('jwt: null'));
    });
  });
}
