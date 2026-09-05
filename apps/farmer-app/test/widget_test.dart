import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_app/main.dart';

void main() {
  testWidgets('PRAHAR Farmer App smoke test - renders farm status and rover card', (WidgetTester tester) async {
    await tester.pumpWidget(const PraharFarmerApp());

    // Verify app bar title
    expect(find.text('PRAHAR'), findsOneWidget);

    // Verify farm card
    expect(find.text('Demo Farm Alpha'), findsOneWidget);

    // Verify rover status
    expect(find.textContaining('ROVER-DEMO-01'), findsOneWidget);

    // Verify scan button
    expect(find.text('Scan Now'), findsOneWidget);
  });
}
