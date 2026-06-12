# yandex_login_sdk

[![pub package](https://img.shields.io/pub/v/yandex_login_sdk.svg)](https://pub.dev/packages/yandex_login_sdk)
[![CI](https://github.com/newbalancem5/yandex_login_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/newbalancem5/yandex_login_sdk/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/newbalancem5/yandex_login_sdk/badge.svg?branch=main)](https://coveralls.io/github/newbalancem5/yandex_login_sdk?branch=main)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](LICENSE)

A Flutter plugin that wraps the official **Yandex LoginSDK** for **iOS** and
**Android**, giving you native single sign-on through installed Yandex apps
(Browser, Mail, Старт, …) with automatic fallback to a Chrome Custom Tab,
WebView, or `ASWebAuthenticationSession`.

- ✅ Native SSO via installed Yandex apps
- ✅ Automatic browser fallback when no Yandex app is present
- ✅ Cancellation surfaced as a typed exception
- ✅ Returns the OAuth `access_token` (and JWT on iOS, `expires_in` on Android)
- ✅ Fetch the user profile (`getUserInfo`) and a cross-platform JWT (`getJwt`) — pure Dart
- ✅ `signOut()` to clear local sign-in state
- ✅ **100% Dart test coverage**, every commit verified by CI

> **Status:** v0.2.0. Android tested in production; iOS code complete but not
> yet field-tested by the maintainer (no Apple Developer account at the time
> of release). Reports/PRs welcome.

## Setup

### 1. Register an OAuth app in Yandex

Create or open your app at [oauth.yandex.ru](https://oauth.yandex.ru), enable
the **mobile platform**, and provide both bundle identifiers:

- iOS Bundle ID
- Android Package name

You'll get a `client_id` (32-char hex string) — used in every step below.

### 2. Add the dependency

```yaml
dependencies:
  yandex_login_sdk: ^0.2.0
```

### 3. Android setup

**`android/app/build.gradle.kts`** — add manifest placeholders (the SDK reads
the client ID from the merged manifest, not at runtime):

```kotlin
android {
    defaultConfig {
        manifestPlaceholders["YANDEX_CLIENT_ID"] = "<your_client_id>"
        manifestPlaceholders["YANDEX_OAUTH_HOST"] = "oauth.yandex.ru"
    }
}
```

**`android/app/src/main/kotlin/.../MainActivity.kt`** — switch to
`FlutterFragmentActivity` (required for `ActivityResultLauncher`):

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

That's it on Android — the plugin's manifest contributes the package
visibility queries for known Yandex apps.

### 4. iOS setup

**`ios/Runner/Info.plist`** — add the URL scheme returned by the SDK and
declare the schemes it queries:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key><string>Editor</string>
        <key>CFBundleURLName</key><string>YandexLoginSDK</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yx&lt;your_client_id&gt;</string>
        </array>
    </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>primaryyandexloginsdk</string>
    <string>secondaryyandexloginsdk</string>
</array>
```

**`ios/Runner/SceneDelegate.swift`** — forward URL callbacks (only required
for projects using the modern scene-based lifecycle, which is the default
for Flutter 3+):

```swift
import Flutter
import UIKit
import yandex_login_sdk

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    var handled = false
    for ctx in URLContexts {
      if YandexLoginSdkPlugin.handle(openURL: ctx.url) { handled = true }
    }
    if !handled {
      super.scene(scene, openURLContexts: URLContexts)
    }
  }
}
```

`AppDelegate.swift` needs no changes — the plugin registers itself as a
`FlutterApplicationLifeCycleDelegate` and intercepts AppDelegate callbacks
automatically (used as a backup for non-scene-based apps).

Minimum iOS deployment target: **13.0**.

## Usage

```dart
import 'package:yandex_login_sdk/yandex_login_sdk.dart';

Future<void> signIn() async {
  try {
    final result = await YandexLoginSdk.signIn(
      clientId: 'your_yandex_oauth_client_id',
    );
    print('Access token: ${result.token}');
    print('JWT (iOS only): ${result.jwt}');
    print('Expires in (Android only): ${result.expiresIn}s');
  } on YandexAuthCancelledException {
    // User dismissed the sheet — no need to show an error.
  } on YandexAuthUnsupportedException {
    // Web/desktop or unsupported — fall back to your own WebView.
  } on YandexAuthException catch (e) {
    print('Yandex SDK error: $e');
  }
}
```

### Fetching the user profile

`getUserInfo` is a pure-Dart call to `login.yandex.ru/info` — it behaves the
same on every platform and needs no native support. Which fields are populated
depends on the permissions your OAuth app was granted (see
[Scopes](#scopes-permissions)).

```dart
final result = await YandexLoginSdk.signIn(clientId: clientId);
final user = await YandexLoginSdk.getUserInfo(token: result.token);

print(user.displayName);   // e.g. "Vasya"
print(user.defaultEmail);  // requires login:email
print(user.avatarUrl());   // requires login:avatar; null when no avatar
```

### Cross-platform JWT

`YandexLoginResult.jwt` is only populated natively on iOS. For a JWT that is
identical on both platforms, call `getJwt` — it fetches the signed JWT from
`login.yandex.ru/info?format=jwt` (the same endpoint the Android SDK uses
internally):

```dart
final jwt = await YandexLoginSdk.getJwt(token: result.token);
```

Both `getUserInfo` and `getJwt` throw `YandexAuthInvalidTokenException` on an
expired or revoked token (HTTP 401).

### Signing out

```dart
await YandexLoginSdk.signOut();
```

- **iOS** — calls the native `YandexLoginSDK.logout()`, clearing the cached
  token/JWT, PKCE verifier and CSRF state from the Keychain. This forces the
  next `signIn` to present interactive UI (and lets the user switch accounts).
- **Android** — the `authsdk` is stateless and has no logout, so this is a
  **documented no-op**.

On **both** platforms it is *local only*: it does **not** revoke the token on
Yandex's servers, nor clear the Yandex-app / browser cookie session. Drop your
own copy of the token afterwards.

### Scopes (permissions)

Yandex fixes OAuth permissions when you **register your app** at
[oauth.yandex.ru](https://oauth.yandex.ru). The native Yandex SDKs (3.x) do
**not** support requesting scopes at runtime, so this plugin has no `scopes`
argument. The `YandexScope` constants are provided for reference — they
document which `YandexUserInfo` fields each permission unlocks:

| Constant | Scope | Unlocks |
|---|---|---|
| `YandexScope.loginInfo` | `login:info` | `displayName`, `realName`, `firstName`, `lastName`, `sex` |
| `YandexScope.loginEmail` | `login:email` | `defaultEmail`, `emails` |
| `YandexScope.loginAvatar` | `login:avatar` | `defaultAvatarId` / `avatarUrl()` |
| `YandexScope.loginBirthday` | `login:birthday` | `birthday` |
| `YandexScope.loginDefaultPhone` | `login:default_phone` | `defaultPhone` |

## Logging

The plugin emits diagnostic events through an opt-in callback — disabled by
default, no `print` calls in release builds. Wire it up to your logger of
choice:

```dart
import 'package:yandex_login_sdk/yandex_login_sdk.dart';

YandexLoginSdk.onLog = (level, message, {error, stackTrace}) {
  switch (level) {
    case YandexLogLevel.error:
      // forward to Sentry, Crashlytics, etc.
      mySentry.captureException(error, stackTrace: stackTrace, hint: message);
    case YandexLogLevel.warning:
    case YandexLogLevel.info:
    case YandexLogLevel.debug:
      myLogger.log(level.name, message);
  }
};
```

What you'll see during a normal flow:

| Level | Message |
|---|---|
| `info` | `signIn() invoked` |
| `debug` | `Invoking native signIn (clientId length=N)` |
| `debug` | `Native signIn returned token (length=N)` |
| `info` | `signIn() succeeded` |

On cancel: `info: signIn() cancelled by user`. On unsupported platform:
`warning: signIn() unsupported on this platform`. On any other error:
`error: signIn() failed: <code> <message>` with `error` and `stackTrace`
populated.

## API

### `YandexLoginSdk.signIn({required String clientId}) → Future<YandexLoginResult>`

Triggers the authorization flow. On Android, `clientId` is informational; the
build-time `manifestPlaceholders` value is what the SDK uses. On iOS, the
value is used to activate the SDK at runtime on first call.

### `YandexLoginResult`

| Field        | Type      | Notes                                  |
|--------------|-----------|----------------------------------------|
| `token`      | `String`  | OAuth 2.0 access token                 |
| `jwt`        | `String?` | Native JWT — iOS only. For both platforms use `getJwt`. |
| `expiresIn`  | `int?`    | Relative TTL in **seconds** from issuance — Android only (`null` on iOS) |

### `YandexLoginSdk.getUserInfo({required String token, http.Client? httpClient}) → Future<YandexUserInfo>`

Pure-Dart `GET login.yandex.ru/info`. Throws `YandexAuthInvalidTokenException`
on HTTP 401 and `YandexAuthException` (codes `HTTP_<status>`, `BAD_RESPONSE`,
`CONNECTION_ERROR`, `BAD_ARGS`) otherwise.

### `YandexLoginSdk.getJwt({required String token, String? jwtSecret, http.Client? httpClient}) → Future<String>`

Pure-Dart `GET login.yandex.ru/info?format=jwt`. Returns the raw signed JWT.
`jwtSecret` only changes the HMAC signing key — avoid shipping a real
`client_secret` in the app.

### `YandexLoginSdk.signOut() → Future<void>`

Clears local sign-in state. Real `logout()` on iOS; documented no-op on
Android. Local-only — no server-side revocation. See
[Signing out](#signing-out).

### `YandexUserInfo`

| Field | Type | Notes |
|---|---|---|
| `id` / `login` / `clientId` | `String` | always present |
| `displayName` / `realName` / `firstName` / `lastName` / `sex` | `String?` | `login:info` |
| `defaultEmail` | `String?` | `login:email` |
| `emails` | `List<String>` | `login:email` |
| `defaultAvatarId` + `avatarUrl([size])` | `String?` | `login:avatar` |
| `birthday` | `String?` | `login:birthday`, raw `YYYY-MM-DD` |
| `defaultPhone` | `YandexPhone?` | `login:default_phone` |
| `psuid` / `oldSocialLogin` | `String?` | |
| `raw` | `Map<String, dynamic>` | full decoded body (forward-compat) |

### `YandexLoginSdk.onLog`

| Type | Notes |
|---|---|
| `YandexLogHandler?` | Optional callback `(level, message, {error, stackTrace})`. `null` = silent. See [Logging](#logging) above. |

### Exceptions

| Exception                          | When                                              |
|-----------------------------------|---------------------------------------------------|
| `YandexAuthCancelledException`     | User dismissed the auth sheet                     |
| `YandexAuthUnsupportedException`   | Plugin not available on this platform             |
| `YandexAuthInvalidTokenException`  | `getUserInfo` / `getJwt` got HTTP 401 (expired/revoked token) |
| `YandexAuthException`              | Any other SDK / configuration / network error     |

## Testing

The Dart layer is covered by **78 unit tests** with **100 %** line coverage —
every error branch in the method-channel implementation, the `getUserInfo` /
`getJwt` HTTP paths (success, 401, server error, transport failure, malformed
body), every exception type and `YandexUserInfo.fromJson` edge case is
exercised. Coverage is reported to
[Coveralls](https://coveralls.io/github/newbalancem5/yandex_login_sdk) on every
push and pull request.

### Running tests locally

```bash
flutter test                            # 78 tests, ~1 s
flutter test --coverage                 # writes coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

### CI

Every push and every pull request runs:

1. `dart format --set-exit-if-changed .` — code style gate
2. `flutter analyze` — static analysis must pass
3. `flutter test --coverage` — all tests must pass
5. Build the example app for Android and iOS to catch native regressions

### What's not covered

The native Kotlin and Swift layers are intentionally not measured — they do
little more than forward calls to the official Yandex SDKs and require a real
device + Yandex account to test meaningfully. Treat the example app as the
manual smoke test for the native side.

## Limitations / known issues

- **`expiresIn` is Android-only.** The iOS `YandexLoginSDK` discards the OAuth
  `expires_in`, so `YandexLoginResult.expiresIn` is always `null` on iOS. (JWT
  parity is solved — use `getJwt` for an identical JWT on both platforms.)
- **No runtime scopes.** The native Yandex SDKs 3.x fix permissions at
  OAuth-app registration time; there is no per-login scope selection. See
  [Scopes](#scopes-permissions).
- **`signOut()` is local-only.** It clears on-device state (iOS) or is a no-op
  (Android); it never revokes the token server-side or clears the cookie
  session.
- **`authorizationStrategy` not exposed.** The plugin always uses the SDK's
  default strategy.

## License

BSD-3-Clause. See [LICENSE](LICENSE).

This plugin is a community wrapper. The bundled native code (Android and
iOS) ships under Yandex's own license terms — see the
[Yandex LoginSDK iOS](https://github.com/yandexmobile/yandex-login-sdk-ios)
and [Yandex LoginSDK Android](https://github.com/yandexmobile/yandex-login-sdk-android)
repositories.
