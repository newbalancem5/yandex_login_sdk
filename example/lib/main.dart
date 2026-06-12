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
  YandexUserInfo? _user;
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
      _user = null;
      _status = 'Signing in…';
    });
    try {
      final result = await YandexLoginSdk.signIn(clientId: _clientId);
      // Pure-Dart profile fetch — works the same on Android and iOS.
      final user = await YandexLoginSdk.getUserInfo(token: result.token);
      setState(() {
        _user = user;
        _status = 'Signed in! Token: ${result.token}';
      });
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

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await YandexLoginSdk.signOut();
      setState(() {
        _user = null;
        _status = 'Signed out (local state cleared).';
      });
    } on YandexAuthException catch (e) {
      setState(() => _status = 'Sign-out error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('yandex_login_sdk example')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (user != null) ...[
                if (user.avatarUrl() case final avatar?)
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(avatar),
                  ),
                const SizedBox(height: 12),
                Text(
                  user.displayName ?? user.login,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (user.defaultEmail case final email?) Text(email),
                const SizedBox(height: 24),
              ],
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Yandex'),
              ),
              if (user != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
              const SizedBox(height: 24),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
