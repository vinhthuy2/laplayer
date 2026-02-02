import 'package:flutter_test/flutter_test.dart';
import 'package:laplayer/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const LaPlayerApp());
    expect(find.text('LaPlayer'), findsOneWidget);
  });
}
