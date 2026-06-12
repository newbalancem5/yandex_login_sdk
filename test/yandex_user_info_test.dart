import 'package:flutter_test/flutter_test.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';

void main() {
  group('YandexUserInfo.fromJson', () {
    test('maps a full response including the nested phone', () {
      final info = YandexUserInfo.fromJson({
        'id': '1000034426',
        'login': 'vasya',
        'client_id': 'abc123',
        'psuid': '1.AAxx',
        'display_name': 'Vasya',
        'real_name': 'Vasya Pupkin',
        'first_name': 'Vasya',
        'last_name': 'Pupkin',
        'sex': 'male',
        'default_email': 'vasya@yandex.ru',
        'emails': ['vasya@yandex.ru'],
        'default_avatar_id': '131652443',
        'is_avatar_empty': false,
        'birthday': '1987-03-12',
        'default_phone': {'id': 12345678, 'number': '+79012345678'},
        'old_social_login': 'uid-xxx',
        'extra_unknown': 'kept',
      });

      expect(info.id, '1000034426');
      expect(info.login, 'vasya');
      expect(info.clientId, 'abc123');
      expect(info.psuid, '1.AAxx');
      expect(info.displayName, 'Vasya');
      expect(info.realName, 'Vasya Pupkin');
      expect(info.firstName, 'Vasya');
      expect(info.lastName, 'Pupkin');
      expect(info.sex, 'male');
      expect(info.defaultEmail, 'vasya@yandex.ru');
      expect(info.emails, ['vasya@yandex.ru']);
      expect(info.defaultAvatarId, '131652443');
      expect(info.isAvatarEmpty, isFalse);
      expect(info.birthday, '1987-03-12');
      expect(info.defaultPhone?.id, 12345678);
      expect(info.defaultPhone?.number, '+79012345678');
      expect(info.oldSocialLogin, 'uid-xxx');
      expect(info.raw['extra_unknown'], 'kept');
    });

    test('coerces a numeric id to String', () {
      final info = YandexUserInfo.fromJson({
        'id': 1000034426,
        'login': 'x',
        'client_id': 'c',
      });
      expect(info.id, '1000034426');
    });

    test('leaves optional fields null/default on a minimal response', () {
      final info = YandexUserInfo.fromJson({
        'id': '1',
        'login': 'l',
        'client_id': 'c',
      });
      expect(info.psuid, isNull);
      expect(info.displayName, isNull);
      expect(info.realName, isNull);
      expect(info.firstName, isNull);
      expect(info.lastName, isNull);
      expect(info.sex, isNull);
      expect(info.defaultEmail, isNull);
      expect(info.emails, isEmpty);
      expect(info.defaultAvatarId, isNull);
      expect(info.isAvatarEmpty, isFalse);
      expect(info.birthday, isNull);
      expect(info.defaultPhone, isNull);
      expect(info.oldSocialLogin, isNull);
    });

    test('falls back to empty strings when required keys are absent', () {
      final info = YandexUserInfo.fromJson(const {});
      expect(info.id, '');
      expect(info.login, '');
      expect(info.clientId, '');
    });

    test('preserves a zero-filled birthday verbatim (never parses it)', () {
      final info = YandexUserInfo.fromJson({
        'id': '1',
        'login': 'l',
        'client_id': 'c',
        'birthday': '0000-12-23',
      });
      expect(info.birthday, '0000-12-23');
    });

    test('tolerates a null sex and an empty-avatar flag', () {
      final info = YandexUserInfo.fromJson({
        'id': '1',
        'login': 'l',
        'client_id': 'c',
        'sex': null,
        'is_avatar_empty': true,
      });
      expect(info.sex, isNull);
      expect(info.isAvatarEmpty, isTrue);
    });

    test('parses a phone with a missing numeric id safely', () {
      final info = YandexUserInfo.fromJson({
        'id': '1',
        'login': 'l',
        'client_id': 'c',
        'default_phone': {'number': '+700'},
      });
      expect(info.defaultPhone?.id, isNull);
      expect(info.defaultPhone?.number, '+700');
    });

    test('toString summarises the key fields', () {
      final info = YandexUserInfo.fromJson({
        'id': '1',
        'login': 'l',
        'client_id': 'c',
        'display_name': 'D',
        'default_email': 'e@x',
      });
      expect(info.toString(), contains('id: 1'));
      expect(info.toString(), contains('login: l'));
      expect(info.toString(), contains('displayName: D'));
    });
  });

  group('avatarUrl', () {
    final base = {'id': '1', 'login': 'l', 'client_id': 'c'};

    test('builds a URL with the default islands-200 size', () {
      final info =
          YandexUserInfo.fromJson({...base, 'default_avatar_id': 'AV'});
      expect(
        info.avatarUrl(),
        'https://avatars.yandex.net/get-yapic/AV/islands-200',
      );
    });

    test('honours an explicit size', () {
      final info =
          YandexUserInfo.fromJson({...base, 'default_avatar_id': 'AV'});
      expect(
        info.avatarUrl(YandexAvatarSize.islands50),
        'https://avatars.yandex.net/get-yapic/AV/islands-50',
      );
    });

    test('returns null when the avatar id is absent', () {
      expect(YandexUserInfo.fromJson(base).avatarUrl(), isNull);
    });

    test('returns null when the avatar id is an empty string', () {
      final info = YandexUserInfo.fromJson({...base, 'default_avatar_id': ''});
      expect(info.avatarUrl(), isNull);
    });

    test('returns null when is_avatar_empty is true', () {
      final info = YandexUserInfo.fromJson({
        ...base,
        'default_avatar_id': 'AV',
        'is_avatar_empty': true,
      });
      expect(info.avatarUrl(), isNull);
    });

    test('every size maps to its documented path key', () {
      final info =
          YandexUserInfo.fromJson({...base, 'default_avatar_id': 'AV'});
      for (final size in YandexAvatarSize.values) {
        expect(info.avatarUrl(size), endsWith('/${size.key}'));
      }
      expect(YandexAvatarSize.islandsRetina50.key, 'islands-retina-50');
      expect(YandexAvatarSize.islandsSmall.key, 'islands-small');
    });
  });

  group('YandexPhone', () {
    test('toString renders id and number', () {
      const p = YandexPhone(id: 7, number: '+700');
      expect(p.toString(), 'YandexPhone(id: 7, number: +700)');
    });
  });

  group('YandexScope', () {
    test('exposes the documented permission identifiers', () {
      expect(YandexScope.loginInfo, 'login:info');
      expect(YandexScope.loginEmail, 'login:email');
      expect(YandexScope.loginAvatar, 'login:avatar');
      expect(YandexScope.loginBirthday, 'login:birthday');
      expect(YandexScope.loginDefaultPhone, 'login:default_phone');
      expect(YandexScope.all, const [
        'login:info',
        'login:email',
        'login:avatar',
        'login:birthday',
        'login:default_phone',
      ]);
    });
  });
}
