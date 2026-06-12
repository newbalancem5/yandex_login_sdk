## 0.2.0

* **User profile fetch (pure Dart)** — new `YandexLoginSdk.getUserInfo(token:)`
  calls `login.yandex.ru/info` and returns a typed `YandexUserInfo`
  (`id`, `login`, `displayName`, `defaultEmail`, `defaultPhone`, `birthday`,
  avatar via `avatarUrl()`, …). Works identically on every platform — no native
  code involved. Adds `YandexPhone`, the `YandexAvatarSize` enum, and a
  `YandexAuthInvalidTokenException` thrown on HTTP 401.
* **Cross-platform JWT** — new `YandexLoginSdk.getJwt(token:)` fetches the
  signed JWT from `login.yandex.ru/info?format=jwt`, giving an identical result
  on Android and iOS (the native iOS `YandexLoginResult.jwt` stays best-effort).
* **`YandexLoginSdk.signOut()`** — clears local sign-in state. On iOS it calls
  the native `YandexLoginSDK.logout()` (clears the cached token/JWT, PKCE
  verifier and CSRF state from the Keychain). On Android the `authsdk` is
  stateless and exposes no logout, so it is a **documented no-op**. Local-only
  on both platforms: it does **not** revoke the token server-side or clear the
  Yandex-app / browser cookie session.
* **`YandexScope` constants** (`login:info`, `login:email`, …) for reference.
  The native Yandex SDKs 3.x do **not** support per-login scope selection —
  permissions are fixed when you register the app at oauth.yandex.ru — so this
  release deliberately does **not** add a runtime `scopes` argument.
* **Honest `expiresIn` docs** — `YandexLoginResult.expiresIn` is a *relative*
  TTL in seconds (Android) and is always `null` on iOS (the iOS SDK discards
  the OAuth `expires_in`).
* Adds an `http` dependency. Dart test coverage remains 100% (78 tests).

## 0.1.6

* **Built-in Kotlin migration** — the Android plugin no longer applies the
  Kotlin Gradle Plugin (KGP) itself. Flutter 3.44+ wires KGP in via its
  Built-in Kotlin support; on older Flutter / AGP < 9 setups the plugin
  conditionally applies `org.jetbrains.kotlin.android` for you. This silences
  the "applies the Kotlin Gradle Plugin, which will cause build failures in
  future versions of Flutter" warning emitted by Flutter 3.44.
* `kotlinOptions` replaced by the top-level `kotlin.compilerOptions` block,
  still pinned to JVM target 17.

## 0.1.5

* **Coverage reporting moved to Coveralls** — CI now uploads
  `coverage/lcov.info` to [coveralls.io](https://coveralls.io/github/newbalancem5/yandex_login_sdk)
  via `coverallsapp/github-action@v2`. The README badge points there.
* Removed the self-hosted SVG coverage badge/donut and the
  `tool/generate_coverage.dart` generator — Coveralls owns those artefacts now.
  No more auto-commits of `assets/coverage_*.svg` to `main` on every push.

## 0.1.4
*  FIX Lowered minimum Dart SDK constraint from `^3.11.5` to `>=3.5.0 <4.0.0` —
  the plugin doesn't rely on any Dart 3.11-specific features, so apps on
  older Flutter/Dart toolchains can now consume it.

## 0.1.3

* Lowered minimum Dart SDK constraint from `^3.11.5` to `>=3.5.0 <4.0.0` —
  the plugin doesn't rely on any Dart 3.11-specific features, so apps on
  older Flutter/Dart toolchains can now consume it.
* Relaxed `flutter_lints` dev dependency from `^6.0.0` to `^4.0.0` to match
  the lowered SDK floor.

## 0.1.2

* **Logging hook** — new `YandexLoginSdk.onLog` callback emits `info` /
  `debug` / `warning` / `error` events for sign-in start, fallbacks,
  cancellation, and mapped error codes. Defaults to `null` (silent), opt-in
  via setter.
* **Swift Package Manager support** — iOS plugin now ships a `Package.swift`
  alongside the existing `.podspec`, so apps using SwiftPM can consume the
  plugin without CocoaPods.
* CHANGELOG and README updated; raised pub.dev "Follow Dart file conventions"
  score to 30/30.

## 0.1.1

* Re-publish to refresh package metadata; no behavioural changes.

## 0.1.0

Initial release.

* Native Yandex SSO on Android (`com.yandex.android:authsdk:3.1.0`) with
  automatic `NATIVE → CHROME_TAB → WEBVIEW` fallback chain handled by the SDK.
* Native Yandex SSO on iOS (`YandexLoginSDK ~> 3.1`) with installed-app
  detection and `ASWebAuthenticationSession` / `SFSafariViewController`
  fallback.
* `YandexLoginSdk.signIn(clientId:)` returns a `YandexLoginResult` with
  `token`, optional `jwt`, optional `expiresIn`.
* Typed exceptions: `YandexAuthCancelledException`,
  `YandexAuthUnsupportedException`, `YandexAuthException`.
