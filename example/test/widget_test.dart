import 'package:flutter_test/flutter_test.dart';
import 'package:yandex_login_sdk_example/main.dart';

void main() {
  testWidgets('example app boots and shows the sign-in button', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Sign in with Yandex'), findsOneWidget);
  });
}
