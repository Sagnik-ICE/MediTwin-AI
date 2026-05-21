import 'package:flutter_test/flutter_test.dart';

import 'package:meditwin_ai/main.dart';

void main() {
  testWidgets('App boots to MediTwin shell flow', (WidgetTester tester) async {
    await tester.pumpWidget(const MediTwinApp());
    expect(find.textContaining('MediTwin AI'), findsWidgets);
  });
}
