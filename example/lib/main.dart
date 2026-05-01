import 'package:flutter/material.dart';
import 'package:yandex_login_sdk/yandex_login_sdk.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  /// Provide your Yandex OAuth client ID via:
  /// `flutter run --dart-define=YANDEX_CLIENT_ID=<your_id>`
  static const _clientId = String.fromEnvironment(
    'YANDEX_CLIENT_ID',
    defaultValue: '',
  );

  String _status = 'Tap "Sign in with Yandex" to start.';
  bool _busy = false;

  Future<void> _signIn() async {
    if (_clientId.isEmpty) {
      setState(
        () => _status =
            'Pass --dart-define=YANDEX_CLIENT_ID=<id> when running this example.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Signing in…';
    });
    try {
      final result = await YandexLoginSdk.signIn(clientId: _clientId);
      setState(
        () => _status =
            'Signed in!\nToken: ${result.token}\nJWT: ${result.jwt ?? '—'}\nExpires in: ${result.expiresIn ?? '—'} s',
      );
    } on YandexAuthCancelledException {
      setState(() => _status = 'Cancelled.');
    } on YandexAuthUnsupportedException {
      setState(
        () => _status = 'Yandex Login SDK is unavailable on this platform.',
      );
    } on YandexAuthException catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('yandex_login_sdk example')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Yandex'),
              ),
              const SizedBox(height: 24),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
