/// Avatar size presets accepted by [YandexUserInfo.avatarUrl].
///
/// Each value maps to the trailing path segment of a Yandex avatar URL
/// (`https://avatars.yandex.net/get-yapic/<id>/<key>`). The dimension in the
/// doc comment is the rendered square size in pixels.
enum YandexAvatarSize {
  /// 28×28.
  islandsSmall('islands-small'),

  /// 34×34.
  islands34('islands-34'),

  /// 42×42.
  islandsMiddle('islands-middle'),

  /// 50×50.
  islands50('islands-50'),

  /// 56×56.
  islandsRetinaSmall('islands-retina-small'),

  /// 68×68.
  islands68('islands-68'),

  /// 75×75.
  islands75('islands-75'),

  /// 84×84.
  islandsRetinaMiddle('islands-retina-middle'),

  /// 100×100.
  islandsRetina50('islands-retina-50'),

  /// 200×200.
  islands200('islands-200');

  const YandexAvatarSize(this.key);

  /// Path segment used to build the avatar URL.
  final String key;
}

/// A phone number attached to a Yandex account (`default_phone`).
class YandexPhone {
  const YandexPhone({this.id, this.number});

  /// Yandex-internal numeric identifier of the phone record.
  ///
  /// Returned as a JSON number — unlike the top-level string
  /// [YandexUserInfo.id].
  final int? id;

  /// The phone number in international format.
  final String? number;

  /// Parses a `default_phone` object. Tolerates a numeric or missing `id`.
  factory YandexPhone.fromJson(Map<String, dynamic> json) => YandexPhone(
        id: (json['id'] as num?)?.toInt(),
        number: json['number'] as String?,
      );

  @override
  String toString() => 'YandexPhone(id: $id, number: $number)';
}

/// Yandex account profile returned by `login.yandex.ru/info`.
///
/// Which fields are populated depends on the OAuth permissions granted to your
/// application (configured at <https://oauth.yandex.ru>). [id], [login] and
/// [clientId] are always present; the rest require the corresponding scope —
/// see `YandexScope`. Unknown/extra keys are preserved in [raw].
class YandexUserInfo {
  const YandexUserInfo({
    required this.id,
    required this.login,
    required this.clientId,
    this.psuid,
    this.displayName,
    this.realName,
    this.firstName,
    this.lastName,
    this.sex,
    this.defaultEmail,
    this.emails = const [],
    this.defaultAvatarId,
    this.isAvatarEmpty = false,
    this.birthday,
    this.defaultPhone,
    this.oldSocialLogin,
    this.raw = const {},
  });

  /// Unique Yandex user id (always present).
  final String id;

  /// Yandex username / login (always present).
  final String login;

  /// Id of the OAuth app the token was issued for (always present).
  final String clientId;

  /// Pseudonymous user id derived from the `client_id` + user id pair.
  final String? psuid;

  /// Name shown in the Yandex UI (`login:info`).
  final String? displayName;

  /// Full name — first + last (`login:info`).
  final String? realName;

  /// First name (`login:info`).
  final String? firstName;

  /// Last name (`login:info`).
  final String? lastName;

  /// `'male'`, `'female'`, or `null` (`login:info`).
  final String? sex;

  /// Default email address (`login:email`).
  final String? defaultEmail;

  /// Known email addresses (`login:email`).
  ///
  /// Yandex currently only returns the default address here. Defaults to an
  /// empty list when the scope is absent.
  final List<String> emails;

  /// Avatar picture id (`login:avatar`). Combine with [avatarUrl].
  final String? defaultAvatarId;

  /// `true` when the avatar is the auto-generated placeholder.
  final bool isAvatarEmpty;

  /// Date of birth as the raw `YYYY-MM-DD` string (`login:birthday`).
  ///
  /// Unknown components may be zero-filled (e.g. `0000-12-23`), so this is kept
  /// as a [String] rather than a [DateTime].
  final String? birthday;

  /// Default phone number (`login:default_phone`).
  final YandexPhone? defaultPhone;

  /// Legacy social-login identifier, if any.
  final String? oldSocialLogin;

  /// The entire decoded JSON body — a forward-compatibility escape hatch for
  /// fields not yet modelled here.
  final Map<String, dynamic> raw;

  /// Deserializes a `login.yandex.ru/info?format=json` response body.
  ///
  /// Robust to missing optional keys, a numeric `default_phone.id`, a
  /// zero-filled `birthday`, a `null` `sex`, and unknown extra keys.
  factory YandexUserInfo.fromJson(Map<String, dynamic> json) {
    final emailsRaw = json['emails'];
    final phoneRaw = json['default_phone'];
    return YandexUserInfo(
      id: json['id']?.toString() ?? '',
      login: json['login'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      psuid: json['psuid'] as String?,
      displayName: json['display_name'] as String?,
      realName: json['real_name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      sex: json['sex'] as String?,
      defaultEmail: json['default_email'] as String?,
      emails: emailsRaw is List
          ? emailsRaw.map((e) => e.toString()).toList(growable: false)
          : const [],
      defaultAvatarId: json['default_avatar_id']?.toString(),
      isAvatarEmpty: json['is_avatar_empty'] as bool? ?? false,
      birthday: json['birthday'] as String?,
      defaultPhone: phoneRaw is Map
          ? YandexPhone.fromJson(Map<String, dynamic>.from(phoneRaw))
          : null,
      oldSocialLogin: json['old_social_login'] as String?,
      raw: json,
    );
  }

  /// Builds the avatar image URL for [size], or `null` when there is no avatar
  /// ([defaultAvatarId] is `null`/empty, or [isAvatarEmpty] is `true`).
  String? avatarUrl([YandexAvatarSize size = YandexAvatarSize.islands200]) {
    final avatarId = defaultAvatarId;
    if (avatarId == null || avatarId.isEmpty || isAvatarEmpty) return null;
    return 'https://avatars.yandex.net/get-yapic/$avatarId/${size.key}';
  }

  @override
  String toString() =>
      'YandexUserInfo(id: $id, login: $login, displayName: $displayName, '
      'defaultEmail: $defaultEmail)';
}
