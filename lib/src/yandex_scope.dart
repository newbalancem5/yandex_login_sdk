/// Yandex OAuth permission identifiers.
///
/// Yandex grants permissions at the **OAuth application level** (configured at
/// <https://oauth.yandex.ru>) — they are *not* requested at runtime by this
/// SDK. The underlying native Yandex SDKs (Android `authsdk` 3.x, iOS
/// `YandexLoginSDK` 3.x) provide no per-login scope selection, so these
/// constants are offered for reference: to document which [YandexUserInfo]
/// fields each permission unlocks and to keep scope strings in one place.
abstract final class YandexScope {
  /// Login, first/last name and gender.
  ///
  /// Unlocks `displayName`, `realName`, `firstName`, `lastName`, `sex`.
  static const String loginInfo = 'login:info';

  /// Email address. Unlocks `defaultEmail` and `emails`.
  static const String loginEmail = 'login:email';

  /// Profile picture. Unlocks `defaultAvatarId` / `avatarUrl()`.
  static const String loginAvatar = 'login:avatar';

  /// Date of birth. Unlocks `birthday`.
  static const String loginBirthday = 'login:birthday';

  /// Phone number. Unlocks `defaultPhone`.
  static const String loginDefaultPhone = 'login:default_phone';

  /// All known permission identifiers, as a convenience list.
  static const List<String> all = [
    loginInfo,
    loginEmail,
    loginAvatar,
    loginBirthday,
    loginDefaultPhone,
  ];
}
