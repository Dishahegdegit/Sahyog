import 'package:flutter_test/flutter_test.dart';
import 'package:sahyog/main.dart';

void main() {
  testWidgets('Sahyog app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SahyogApp());
    expect(find.byType(SahyogApp), findsOneWidget);
  });
}
