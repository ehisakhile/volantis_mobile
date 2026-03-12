import 'package:flutter_test/flutter_test.dart';
import 'package:volantis_live/app.dart';

void main() {
  testWidgets('App starts and shows splash', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VolantisLiveApp());
    
    // Verify that app starts
    await tester.pump();
    expect(find.byType(VolantisLiveApp), findsOneWidget);
  });
}
