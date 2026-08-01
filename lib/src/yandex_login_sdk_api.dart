import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../yandex_login_sdk_platform_interface.dart';
import 'yandex_auth_exception.dart';
import 'yandex_log.dart';
import 'yandex_login_result.dart';
import 'yandex_login_strategy.dart';
import 'yandex_user_info.dart';

/// Entry point for the Yandex Login SDK plugin.
abstract final class YandexLoginSdk {
  /// Host of the Yandex user-information REST API.
  static const String _infoHost = 'login.yandex.ru';
  static const String _infoPath = '/info';

  /// Factory for the default HTTP client used by [getUserInfo] and [getJwt]
  /// when no `httpClient` argument is supplied. Overridable in tests.
  @visibleForTesting
  static http.Client Function() httpClientFactory = http.Client.new;

  /// Optional log listener.
  ///
  /// Set this to receive diagnostic events from the plugin — start/finish of
  /// the sign-in flow, cancellation, fallback paths, mapped error codes.
  /// Defaults to `null`, which silences all output.
  ///
  /// ```dart
  /// YandexLoginSdk.onLog = (level, message, {error, stackTrace}) {
  ///   // forward to your logger of choice
  ///   print('[yandex_login_sdk:${level.name}] $message');
  /// };
  /// ```
  static set onLog(YandexLogHandler? handler) => YandexLog.handler = handler;

  /// Currently installed log handler.
  static YandexLogHandler? get onLog => YandexLog.handler;

  /// Triggers Yandex authorization.
  ///
  /// On **Android** the SDK chains `NATIVE → CHROME_TAB → WEBVIEW`
  /// automatically: it tries an installed Yandex app first and falls back to a
  /// Chrome Custom Tab / WebView when none is available. [clientId] overrides
  /// the manifest value at runtime (authsdk 3.2+); the
  /// `YANDEX_CLIENT_ID` / `YANDEX_OAUTH_HOST` manifest placeholders are still
  /// required for the SDK to initialize (see README setup).
  ///
  /// On **iOS** the SDK tries the installed Yandex apps first and falls back
  /// to `ASWebAuthenticationSession`. [clientId] is used to activate the SDK
  /// at runtime; passing a different value re-activates it.
  ///
  /// [strategy] selects where the fallback chain starts: [YandexLoginStrategy.auto]
  /// (default, native apps first) or [YandexLoginStrategy.webOnly] (skip the
  /// installed apps and go straight to the browser-based flow).
  ///
  /// OAuth permissions (scopes) are **not** requested here — Yandex fixes them
  /// at OAuth-app registration time (<https://oauth.yandex.ru>). See
  /// `YandexScope` for the identifiers and which [YandexUserInfo] fields they
  /// unlock.
  ///
  /// Throws:
  /// - [YandexAuthCancelledException] when the user cancels.
  /// - [YandexAuthInProgressException] when another sign-in is already
  ///   running.
  /// - [YandexAuthUnsupportedException] on unsupported platforms.
  /// - [YandexAuthException] for any other SDK failure.
  static Future<YandexLoginResult> signIn({
    required String clientId,
    YandexLoginStrategy strategy = YandexLoginStrategy.auto,
  }) async {
    YandexLog.info('signIn() invoked');
    try {
      final result = await YandexLoginSdkPlatform.instance.signIn(
        clientId: clientId,
        strategy: strategy,
      );
      YandexLog.info('signIn() succeeded');
      return result;
    } on YandexAuthCancelledException {
      YandexLog.info('signIn() cancelled by user');
      rethrow;
    } on YandexAuthUnsupportedException {
      YandexLog.warn('signIn() unsupported on this platform');
      rethrow;
    } on YandexAuthException catch (e, st) {
      YandexLog.error(
        'signIn() failed: ${e.code ?? '-'} ${e.message}',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Clears the local sign-in state.
  ///
  /// On **iOS** this calls the native `YandexLoginSDK.logout()`, which removes
  /// the cached token/JWT, the PKCE verifier and CSRF state from the Keychain —
  /// forcing the next [signIn] to present interactive UI (and allowing an
  /// account switch).
  ///
  /// On **Android** the underlying `authsdk` is stateless and exposes no
  /// logout, so this resolves successfully as a **documented no-op**.
  ///
  /// On **both** platforms it is *local only*: it does **not** revoke the
  /// access token on Yandex's servers, nor clear the Yandex-app / browser
  /// cookie session. Drop your own copy of the token after calling this.
  ///
  /// Throws:
  /// - [YandexAuthUnsupportedException] on unsupported platforms.
  /// - [YandexAuthException] for any other SDK failure.
  static Future<void> signOut() async {
    YandexLog.info('signOut() invoked');
    try {
      await YandexLoginSdkPlatform.instance.signOut();
      YandexLog.info('signOut() completed');
    } on YandexAuthUnsupportedException {
      YandexLog.warn('signOut() unsupported on this platform');
      rethrow;
    } on YandexAuthException catch (e, st) {
      YandexLog.error(
        'signOut() failed: ${e.code ?? '-'} ${e.message}',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Fetches the signed-in user's Yandex profile.
  ///
  /// Calls `GET https://login.yandex.ru/info?format=json` with the
  /// `Authorization: OAuth <token>` header and maps the response to a
  /// [YandexUserInfo]. This is a pure-Dart HTTP call — it works identically on
  /// every platform and needs no native support.
  ///
  /// Which fields come back depends on the OAuth permissions granted to your
  /// app (see `YandexScope`).
  ///
  /// Pass [httpClient] to supply your own client (proxy, retries, tests); when
  /// omitted a one-shot client is created and closed internally. [timeout]
  /// bounds the whole request — when it elapses a [YandexAuthException] with
  /// code `TIMEOUT` is thrown.
  ///
  /// Throws:
  /// - [YandexAuthInvalidTokenException] on HTTP 401 (expired/revoked token).
  /// - [YandexAuthException] (code `HTTP_<status>`) on other non-200 responses,
  ///   (code `BAD_RESPONSE`) on a malformed body, (code `TIMEOUT`) when
  ///   [timeout] elapses, (code `CONNECTION_ERROR`) on a transport failure, or
  ///   (code `BAD_ARGS`) when [token] is empty.
  static Future<YandexUserInfo> getUserInfo({
    required String token,
    http.Client? httpClient,
    Duration? timeout,
  }) async {
    YandexLog.info('getUserInfo() invoked');
    final body = await _getInfo(
      token: token,
      query: const {'format': 'json'},
      what: 'getUserInfo',
      httpClient: httpClient,
      timeout: timeout,
    );
    Never badResponse(Object cause, StackTrace st) {
      YandexLog.error(
        'getUserInfo() got a malformed body',
        error: cause,
        stackTrace: st,
      );
      throw YandexAuthException(
        'Malformed JSON from Yandex /info',
        code: 'BAD_RESPONSE',
        details: cause,
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object from /info');
      }
      YandexLog.debug('getUserInfo() parsed profile');
      return YandexUserInfo.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException catch (e, st) {
      // Body was not valid JSON or not a JSON object.
      badResponse(e, st);
    } on TypeError catch (e, st) {
      // Valid JSON object, but a field had an unexpected type — keep the
      // documented BAD_RESPONSE contract instead of leaking a raw TypeError.
      badResponse(e, st);
    }
  }

  /// Fetches the signed-in user's profile as a signed JWT.
  ///
  /// Calls `GET https://login.yandex.ru/info?format=jwt` with the
  /// `Authorization: OAuth <token>` header and returns the raw HS256-signed
  /// JWT body verbatim. This is the canonical, **cross-platform** way to obtain
  /// the JWT (the same endpoint Android's native `getJwt` uses internally), so
  /// it yields an identical result on Android and iOS.
  ///
  /// [jwtSecret] only changes the HMAC signing key (so your backend can verify
  /// the token with a known secret); it does not change the returned claims.
  /// Avoid shipping a real `client_secret` inside the app — prefer verifying
  /// server-side or trusting HTTPS transport for client-only flows.
  ///
  /// Pass [httpClient] to supply your own client; when omitted a one-shot
  /// client is created and closed internally. [timeout] bounds the whole
  /// request — when it elapses a [YandexAuthException] with code `TIMEOUT` is
  /// thrown.
  ///
  /// Throws:
  /// - [YandexAuthInvalidTokenException] on HTTP 401 (expired/revoked token).
  /// - [YandexAuthException] (code `HTTP_<status>` / `TIMEOUT` /
  ///   `CONNECTION_ERROR` / `BAD_ARGS`) otherwise.
  static Future<String> getJwt({
    required String token,
    String? jwtSecret,
    http.Client? httpClient,
    Duration? timeout,
  }) async {
    YandexLog.info('getJwt() invoked');
    final query = <String, String>{'format': 'jwt'};
    if (jwtSecret != null) query['jwt_secret'] = jwtSecret;
    final jwt = await _getInfo(
      token: token,
      query: query,
      what: 'getJwt',
      httpClient: httpClient,
      timeout: timeout,
    );
    YandexLog.debug('getJwt() received JWT (length=${jwt.length})');
    return jwt;
  }

  /// Performs `GET login.yandex.ru/info` with the given [query] and returns the
  /// 200 response body, mapping HTTP/transport failures to typed exceptions.
  ///
  /// Closes the client only when it created one (a caller-supplied [httpClient]
  /// is left open for reuse).
  static Future<String> _getInfo({
    required String token,
    required Map<String, String> query,
    required String what,
    http.Client? httpClient,
    Duration? timeout,
  }) async {
    if (token.isEmpty) {
      YandexLog.error('$what() called with empty token');
      throw const YandexAuthException(
        'token must not be empty',
        code: 'BAD_ARGS',
      );
    }
    final client = httpClient ?? httpClientFactory();
    final uri = Uri.https(_infoHost, _infoPath, query);
    try {
      var request = client.get(uri, headers: {'Authorization': 'OAuth $token'});
      if (timeout != null) request = request.timeout(timeout);
      final response = await request;
      final status = response.statusCode;
      if (status == 200) {
        return response.body;
      }
      if (status == 401) {
        YandexLog.warn('$what() unauthorized (HTTP 401)');
        throw const YandexAuthInvalidTokenException();
      }
      YandexLog.error('$what() failed with HTTP $status');
      throw YandexAuthException(
        'Yandex /info returned HTTP $status',
        code: 'HTTP_$status',
      );
    } on YandexAuthException {
      rethrow;
    } on TimeoutException catch (e, st) {
      YandexLog.error('$what() timed out', error: e, stackTrace: st);
      throw YandexAuthException(
        'Yandex /info request timed out after ${timeout!.inMilliseconds} ms',
        code: 'TIMEOUT',
        details: e,
      );
    } catch (e, st) {
      YandexLog.error('$what() transport failure', error: e, stackTrace: st);
      throw YandexAuthException(
        'Network error calling Yandex /info: $e',
        code: 'CONNECTION_ERROR',
        details: e,
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
