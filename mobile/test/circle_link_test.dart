import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holdmywallet/core/models/models.dart';
import 'package:holdmywallet/features/feed/feed_repository.dart';
import 'package:holdmywallet/main.dart';

void main() {
  testWidgets('a cold-start invitation survives first-run guidelines',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final request = await container.read(feedRepositoryProvider).createRequest(
          title: 'Desk lamp',
          priceCents: 3900,
          currency: CurrencyCode.USD,
          whyWant: 'For reading',
          durationHours: 1,
          visibility: RequestVisibility.circle,
        );
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        'walletwait://r/${request.shareToken}';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const HoldMyWalletApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept and continue'));
    await tester.pumpAndSettle();
    expect(find.text('Private Circle'), findsOneWidget);
    expect(find.text('Desk lamp'), findsOneWidget);
  });
}
