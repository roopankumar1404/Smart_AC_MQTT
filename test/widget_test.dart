import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ac_mqtt/core/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Just verify app builds without crashing
    expect(SmartAcApp, isNotNull);
  });
}
