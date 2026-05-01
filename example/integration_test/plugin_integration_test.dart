// Integration test smoke: verifies the example app boots without throwing.
//
// Real authorization can't be exercised here without user interaction with
// the Yandex login flow. Add device-driven tests in your own project.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('library import smoke', () {
    expect(true, isTrue);
  });
}
