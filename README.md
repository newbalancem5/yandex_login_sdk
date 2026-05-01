# yandex_login_sdk

[![pub package](https://img.shields.io/pub/v/yandex_login_sdk.svg)](https://pub.dev/packages/yandex_login_sdk)
[![CI](https://github.com/newbalancem5/yandex_login_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/newbalancem5/yandex_login_sdk/actions/workflows/ci.yml)
[![Coverage](assets/coverage_badge.svg)](assets/coverage_badge.svg)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](LICENSE)

A Flutter plugin that wraps the official **Yandex LoginSDK** for **iOS** and
**Android**, giving you native single sign-on through installed Yandex apps
(Browser, Mail, Старт, …) with automatic fallback to a Chrome Custom Tab,
WebView, or `ASWebAuthenticationSession`.

- ✅ Native SSO via installed Yandex apps
- ✅ Automatic browser fallback when no Yandex app is present
- ✅ Cancellation surfaced as a typed exception
- ✅ Returns the OAuth `access_token` (and JWT on iOS, `expires_in` on Android)
- ✅ **100% Dart test coverage**, every commit verified by CI

> **Status:** v0.1.0. Android tested in production; iOS code complete but not
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
  yandex_login_sdk: ^0.1.0
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
| `jwt`        | `String?` | Yandex JWT — iOS only                  |
| `expiresIn`  | `int?`    | Token lifetime in seconds — Android only |

### `YandexLoginSdk.onLog`

| Type | Notes |
|---|---|
| `YandexLogHandler?` | Optional callback `(level, message, {error, stackTrace})`. `null` = silent. See [Logging](#logging) above. |

### Exceptions

| Exception                          | When                                              |
|-----------------------------------|---------------------------------------------------|
| `YandexAuthCancelledException`     | User dismissed the auth sheet                     |
| `YandexAuthUnsupportedException`   | Plugin not available on this platform             |
| `YandexAuthException`              | Any other SDK / configuration / network error     |

## Testing

The Dart layer is covered by **26 unit tests** with **100 %** line coverage —
every error branch in the method-channel implementation, every exception type,
every code path in `YandexLoginResult` is exercised. The badge in the header
([`assets/coverage_badge.svg`](assets/coverage_badge.svg)) is regenerated by
CI on every push.

### Running tests locally

```bash
flutter test                            # 26 tests, ~1 s
flutter test --coverage                 # writes coverage/lcov.info
dart run tool/generate_coverage.dart    # refreshes assets/coverage_*.svg
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

### CI

Every push and every pull request runs:

1. `dart format --set-exit-if-changed .` — code style gate
2. `flutter analyze` — static analysis must pass
3. `flutter test --coverage` — all tests must pass
4. Upload `coverage/lcov.info` to Codecov
5. Build the example app for Android and iOS to catch native regressions

The Codecov check is configured to **require 100 % coverage** on new patches
(see [`codecov.yml`](codecov.yml)) — adding code without tests will fail CI.

### What's not covered

The native Kotlin and Swift layers are intentionally not measured — they do
little more than forward calls to the official Yandex SDKs and require a real
device + Yandex account to test meaningfully. Treat the example app as the
manual smoke test for the native side.

## Limitations / known issues

- **JWT only on iOS, `expiresIn` only on Android** — these come from
  different SDK paths. v0.2 will harmonise them via the Android SDK's
  `getJwt()` method.
- **`customValues` and `authorizationStrategy` not exposed** — coming in
  v0.2.
- **No `signOut()`** — call your backend's logout endpoint and discard the
  token in app state.

## Coverage

<p align="center"><img src="assets/coverage_donut.svg" alt="Coverage donut" width="220"></p>

Both [`assets/coverage_badge.svg`](assets/coverage_badge.svg) and
[`assets/coverage_donut.svg`](assets/coverage_donut.svg) are generated locally
from `coverage/lcov.info` by [`tool/generate_coverage.dart`](tool/generate_coverage.dart),
no external service involved. CI re-runs the generator after every test pass
and commits the updated artefacts back to `main`.

## License

BSD-3-Clause. See [LICENSE](LICENSE).

This plugin is a community wrapper. The bundled native code (Android and
iOS) ships under Yandex's own license terms — see the
[Yandex LoginSDK iOS](https://github.com/yandexmobile/yandex-login-sdk-ios)
and [Yandex LoginSDK Android](https://github.com/yandexmobile/yandex-login-sdk-android)
repositories.
