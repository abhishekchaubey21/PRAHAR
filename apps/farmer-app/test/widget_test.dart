import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_app/main.dart';

void main() {
  testWidgets('PRAHAR Farmer App - renders, toggles Hindi, and approves remediation', (WidgetTester tester) async {
    await tester.pumpWidget(const PraharFarmerApp());

    // Verify initial English render
    expect(find.text('PRAHAR'), findsOneWidget);
    expect(find.text('Demo Farm Alpha'), findsOneWidget);
    expect(find.text('Approve Micro-Irrigation (30s)'), findsOneWidget);

    // Test Language Toggle to Hindi (Requirement 9)
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('डेमो खेत अल्फा'), findsOneWidget);
    expect(find.text('सिंचाई स्वीकृत करें (30 सेकंड)'), findsOneWidget);

    // Test Safety Gate Approval & Remediation (Requirement 1 & 9)
    await tester.tap(find.text('सिंचाई स्वीकृत करें (30 सेकंड)'));
    await tester.pumpAndSettle();

    // Verify verification card appears
    expect(find.text('उपचार सत्यापन सफल'), findsOneWidget);
    expect(find.text('स्वीकृत - रोवर द्वारा उपचार पूरा'), findsOneWidget);
  });
}
