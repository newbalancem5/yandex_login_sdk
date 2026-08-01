/// How the SDK should present the Yandex authorization UI.
///
/// Both native SDKs pick the concrete surface themselves; this only selects
/// the *starting point* of their fallback chains:
///
/// | Value | Android (`authsdk`) | iOS (`YandexLoginSDK`) |
/// |---|---|---|
/// | [auto] | `NATIVE → CHROME_TAB → WEBVIEW` | Yandex apps → web session |
/// | [webOnly] | `CHROME_TAB → WEBVIEW` | `ASWebAuthenticationSession` only |
///
/// [webOnly] skips the installed Yandex apps entirely — useful when you want
/// a predictable browser-based flow (e.g. for testing, or to avoid the
/// app-switch UX).
enum YandexLoginStrategy {
  /// Default: try installed Yandex apps first, fall back to a browser flow.
  auto,

  /// Skip native apps and go straight to the browser-based flow.
  webOnly,
}
