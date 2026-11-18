import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holdmywallet/main.dart';

void main() {
  testWidgets('HoldMyWallet boots to Public Square', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HoldMyWalletApp()));
    await tester.pumpAndSettle();

    expect(find.text('HoldMyWallet'), findsWidgets);
    expect(find.text('Square'), findsOneWidget);
  });
}
