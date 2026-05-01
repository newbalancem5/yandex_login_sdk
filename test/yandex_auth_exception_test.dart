import 'package:flutter_test/flutter_test.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';

void main() {
  group('YandexAuthException', () {
    test('renders message with code and details', () {
      const e = YandexAuthException(
        'Bad thing',
        code: 'OOPS',
        details: 'extra',
      );
      expect(e.toString(), 'YandexAuthException(OOPS): Bad thing [extra]');
    });

    test('renders message without code or details', () {
      const e = YandexAuthException('Plain');
      expect(e.toString(), 'YandexAuthException(-): Plain');
    });

    test('renders message with code but no details', () {
      const e = YandexAuthException('msg', code: 'CODE');
      expect(e.toString(), 'YandexAuthException(CODE): msg');
    });
  });

  test('YandexAuthCancelledException has CANCELLED code', () {
    const e = YandexAuthCancelledException();
    expect(e.code, 'CANCELLED');
    expect(e.message, contains('cancel'));
    expect(e, isA<YandexAuthException>());
  });

  test('YandexAuthUnsupportedException has UNSUPPORTED code', () {
    const e = YandexAuthUnsupportedException();
    expect(e.code, 'UNSUPPORTED');
    expect(e.message, contains('not available'));
    expect(e, isA<YandexAuthException>());
  });
}
