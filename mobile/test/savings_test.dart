import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holdmywallet/main.dart';

void main() {
  testWidgets('marking a rejected purchase skipped records its currency',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HoldMyWalletApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept and continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    final skip = find.text('Mark skipped');
    expect(find.text('Money saved'), findsOneWidget);
    await tester.scrollUntilVisible(skip, 220);
    await tester.tap(skip);
    await tester.pumpAndSettle();
    expect(find.text('₱899.00'), findsOneWidget);
    expect(skip, findsNothing);
  });
}
