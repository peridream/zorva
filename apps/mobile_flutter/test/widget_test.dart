import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/main.dart';

void main() {
  testWidgets('Zorva App smoke test', (WidgetTester tester) async {
    expect(ZorvaApp(), isNotNull);
  });
}
