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
