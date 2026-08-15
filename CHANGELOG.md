## 1.0.1

* **Flutter 3.47 compatibility** — the example's Android toolchain is aligned
  with the current Flutter template: Kotlin Gradle plugin **2.4.0** is now
  pinned explicitly in `settings.gradle.kts` (Flutter 3.47 requires
  KGP ≥ 2.2.20 and no longer wires a usable fallback), AGP **9.1.0**,
  Gradle **9.3.1**. `analysis_options.yaml` picked up the new
  build/platform-directory excludes that `flutter pub get` migrates in
  automatically.
* No changes to the plugin code or the Dart API.

## 1.0.0

* **Web support** 🎉 — `signIn` now works on Flutter Web via OAuth 2.0
  **Authorization Code + PKCE** in a popup against `oauth.yandex.ru`. No
  client secret is involved and the access token never appears in a URL
  (safer than the classic implicit flow). Setup: enable the web platform for
  your OAuth app, register the redirect URI and drop a tiny
  `yandex_auth_callback.html` into `web/` — see the README's Web setup
  section.
  - `getUserInfo` / `getJwt` work in the browser unchanged —
    `login.yandex.ru` serves CORS headers (verified).
  - `expiresIn` / `expiresAt` are populated on web (the token endpoint
    returns the TTL); `YandexLoginResult.jwt` stays `null` — use `getJwt`.
  - User closing the popup / denying consent → `YandexAuthCancelledException`;
    blocked popup → code `POPUP_BLOCKED` (call `signIn` from a user gesture);
    CSRF-mismatched callbacks are discarded with code `STATE_MISMATCH`.
  - `strategy` is ignored on web (there is only the web flow);
    `signOut()` is a documented no-op (the plugin holds no session state).
  - `YandexAuthUnsupportedException` now only applies to desktop platforms.
* First stable release: the Dart API of 0.3.0 is carried over unchanged and
  is now covered by semantic-versioning guarantees.
* 113 Dart tests, coverage stays at 100%.

## 0.3.0

* **`clientId` is now real on Android** — the Android dependency is bumped to
  `com.yandex.android:authsdk:3.2.1`, whose login options accept a runtime
  `clientId` that overrides the manifest value. The `clientId` you pass to
  `signIn` is now used on **both** platforms (the
  `YANDEX_CLIENT_ID` / `YANDEX_OAUTH_HOST` manifest placeholders are still
  required for SDK initialization). This also enables switching between
  multiple OAuth clients at runtime.
* **`strategy` argument for `signIn`** — new `YandexLoginStrategy` enum:
  `auto` (default; installed Yandex apps first, then browser fallback) or
  `webOnly` (skip the apps and go straight to the browser flow —
  `CHROME_TAB → WEBVIEW` on Android, `ASWebAuthenticationSession` on iOS).
  Closes the "authorizationStrategy not exposed" limitation. A `nativeOnly`
  value is deliberately absent: neither native SDK can require the app-only
  flow — both fall back to web when no Yandex app is installed.
* **Native logs flow into `onLog`** — while a `YandexLoginSdk.onLog` handler
  is installed, the Kotlin/Swift plugin layers mirror their diagnostics
  (launch, success, cancellation, failures) into the same hook, prefixed with
  `[native]`. On Android this also enables the `authsdk`'s own logcat output.
  No handler — no traffic, exactly as before.
* **`YandexAuthInProgressException`** — calling `signIn` while another
  sign-in is running now throws a typed exception (code `BUSY`) instead of a
  generic `YandexAuthException`.
* **`YandexLoginResult.issuedAt` / `expiresAt`** — the plugin stamps the
  moment the native response arrives and derives the absolute expiry
  (`issuedAt + expiresIn`); both are `null` on iOS, which reports no TTL.
* **`timeout` parameter for `getUserInfo` / `getJwt`** — bounds the whole
  HTTP request; on expiry throws `YandexAuthException` with code `TIMEOUT`.
* **Rotation no longer kills an in-flight sign-in (Android)** — on a
  configuration change the plugin now keeps the pending Dart result and
  re-registers its `ActivityResultLauncher`, so the auth result started before
  the rotation is delivered instead of erroring with `DETACHED`.
* **Locale-safe cancellation detection (iOS)** — user cancellation is now
  recognized by error domain + code (`ASWebAuthenticationSessionError`,
  `SFAuthenticationError`, `NSUserCancelledError`) and by the SDK's own
  web-view-closed error, instead of matching the word "cancel" inside
  `localizedDescription` (which the system localizes — cancels on non-English
  devices used to surface as `SDK_ERROR`).
* **Privacy manifest actually ships (iOS)** — `PrivacyInfo.xcprivacy` was in
  the repo but referenced by neither CocoaPods nor SwiftPM; it is now bundled
  via `s.resource_bundles` and SwiftPM `resources`.
* **Re-activation on clientId change (iOS)** — calling `signIn` with a
  different `clientId` re-activates the native SDK instead of silently reusing
  the first one.
* Removed the deprecated `package` attribute from the plugin's
  `AndroidManifest.xml` (breaks builds with newer AGP).
* Replaced the stale template Kotlin unit test with real dispatch tests; CI
  now also runs them and validates packaging with `flutter pub publish
  --dry-run`.
* 95 Dart tests, coverage stays at 100%.

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
