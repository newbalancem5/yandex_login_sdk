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
