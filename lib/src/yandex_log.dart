/// Severity of a log event emitted by the plugin.
enum YandexLogLevel { debug, info, warning, error }

/// Signature for a log event listener installed via [YandexLog.handler].
typedef YandexLogHandler = void Function(
  YandexLogLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// Internal log dispatcher.
///
/// Set [handler] to receive diagnostic events from the plugin (entry/exit of
/// `signIn`, fallback paths, error mappings). Defaults to `null` — nothing
/// is printed unless the host app explicitly opts in.
abstract final class YandexLog {
  static YandexLogHandler? handler;

  static void emit(
    YandexLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final h = handler;
    if (h == null) return;
    h(level, message, error: error, stackTrace: stackTrace);
  }

  static void debug(String message) => emit(YandexLogLevel.debug, message);
  static void info(String message) => emit(YandexLogLevel.info, message);
  static void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      emit(
        YandexLogLevel.warning,
        message,
        error: error,
        stackTrace: stackTrace,
      );
  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      emit(YandexLogLevel.error, message, error: error, stackTrace: stackTrace);
}
