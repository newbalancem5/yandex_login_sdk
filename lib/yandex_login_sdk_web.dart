import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/yandex_auth_exception.dart';
import 'src/yandex_log.dart';
import 'src/yandex_login_result.dart';
import 'src/yandex_login_strategy.dart';
import 'src/yandex_web_oauth.dart';
import 'yandex_login_sdk_platform_interface.dart';

/// Web implementation of the plugin: OAuth 2.0 Authorization Code + PKCE in
/// a popup against `oauth.yandex.ru` — no client secret, the access token
/// never appears in a URL.
///
/// Requires a `yandex_auth_callback.html` page in the app's `web/` folder and
/// a matching Redirect URI in the OAuth app settings — see the README's Web
/// setup section.
class YandexLoginSdkWeb extends YandexLoginSdkPlatform {
  /// Marker prepended by the callback page to its `postMessage` payload.
  static const String _messagePrefix = 'yandex_login_sdk:';

  /// Overrides the redirect URI sent to Yandex. Defaults to
  /// `<origin>/yandex_auth_callback.html`; set this before calling `signIn`
  /// when the app is deployed under a sub-path.
  static String? redirectUriOverride;

  bool _inProgress = false;

  static void registerWith(Registrar registrar) {
    YandexLoginSdkPlatform.instance = YandexLoginSdkWeb();
  }

  @override
  Future<YandexLoginResult> signIn({
    required String clientId,
    YandexLoginStrategy strategy = YandexLoginStrategy.auto,
  }) async {
    if (clientId.isEmpty) {
      YandexLog.error('signIn() called with empty clientId');
      throw const YandexAuthException(
        'clientId must not be empty',
        code: 'BAD_ARGS',
      );
    }
    if (_inProgress) throw const YandexAuthInProgressException();
    _inProgress = true;
    YandexLog.debug(
      'Starting web OAuth flow (strategy=${strategy.name} is ignored on web)',
    );
    try {
      return await _authorize(clientId);
    } finally {
      _inProgress = false;
    }
  }

  /// Local-only no-op on web: the plugin holds no session state. The Yandex
  /// cookie session in the browser is not touched.
  @override
  Future<void> signOut() async {
    YandexLog.debug('signOut(): no-op on web (no local session state)');
  }

  Future<YandexLoginResult> _authorize(String clientId) async {
    final redirectUri = redirectUriOverride ??
        '${web.window.location.origin}/yandex_auth_callback.html';
    final state = YandexWebOAuth.generateRandomToken();
    final pkce = YandexWebOAuth.createPkcePair();
    final url = YandexWebOAuth.buildAuthorizeUrl(
      clientId: clientId,
      redirectUri: redirectUri,
      state: state,
      codeChallenge: pkce.challenge,
    );

    final popup = web.window.open(
      url.toString(),
      'yandex_login_sdk_auth',
      'popup=yes,width=600,height=720',
    );
    if (popup == null) {
      YandexLog.error('signIn() popup was blocked by the browser');
      throw const YandexAuthException(
        'Authorization popup was blocked — call signIn() from a user '
        'gesture (e.g. a button tap)',
        code: 'POPUP_BLOCKED',
      );
    }

    final payloadCompleter = Completer<String>();

    void onMessage(web.MessageEvent event) {
      if (event.origin != web.window.location.origin) return;
      final data = event.data?.dartify();
      if (data is! String || !data.startsWith(_messagePrefix)) return;
      if (!payloadCompleter.isCompleted) {
        payloadCompleter.complete(data.substring(_messagePrefix.length));
      }
    }

    final jsListener = onMessage.toJS;
    web.window.addEventListener('message', jsListener);

    // The user can simply close the popup; poll for that and give any
    // in-flight message a short grace period before reporting cancellation.
    final closePoll = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (popup.closed) {
        t.cancel();
        Timer(const Duration(milliseconds: 300), () {
          if (!payloadCompleter.isCompleted) {
            YandexLog.info('signIn() popup closed by user');
            payloadCompleter
                .completeError(const YandexAuthCancelledException());
          }
        });
      }
    });

    try {
      final payload = await payloadCompleter.future;
      // The callback page closes itself, but not every browser allows it.
      if (!popup.closed) popup.close();
      final code = YandexWebOAuth.parseCallback(payload, expectedState: state);
      return await YandexWebOAuth.exchangeCode(
        code: code,
        clientId: clientId,
        codeVerifier: pkce.verifier,
      );
    } finally {
      closePoll.cancel();
      web.window.removeEventListener('message', jsListener);
    }
  }
}
