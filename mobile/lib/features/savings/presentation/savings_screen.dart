import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ad_banner.dart';
import '../../../core/widgets/money_text.dart';
import '../../feed/feed_repository.dart';

final savingsProvider = FutureProvider((ref) {
  return ref.watch(feedRepositoryProvider).fetchSavings();
});

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Money saved'), actions: [
        IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh savings',
            onPressed: () => ref.invalidate(savingsProvider)),
      ]),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (s) {
                final locked = s.approvedCount + s.rejectedCount;
                final rejectPct =
                    locked == 0 ? 0 : (s.rejectRatio * 100).round();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Your pause power',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track asks, verdicts, and cash you kept by skipping rejects.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    _StatTile(
                      label: 'Requests submitted',
                      value: '${s.requestsSubmitted}',
                      tint: AppColors.mintSoft,
                    ),
                    const SizedBox(height: 12),
                    _StatTile(
                      label: 'Approved vs rejected',
                      value: locked == 0
                          ? 'No locked verdicts yet'
                          : '${s.approvedCount} / ${s.rejectedCount} ($rejectPct% rejected)',
                      tint: AppColors.coralSoft,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.slate,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated money saved',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (s.savedByCurrency.isEmpty)
                            const Text('No savings recorded yet',
                                style: TextStyle(color: Colors.white)),
                          for (final amount in s.savedByCurrency.entries)
                            MoneyText(
                              priceCents: amount.value,
                              currency: amount.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'Counted when you mark a rejected item as Skipped.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    for (final request in s.eligible)
                      ListTile(
                        title: Text(request.title),
                        subtitle: MoneyText(
                            priceCents: request.priceCents,
                            currency: request.currency),
                        trailing: TextButton(
                          child: const Text('Mark skipped'),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(feedRepositoryProvider)
                                  .markSkipped(request.id);
                              if (context.mounted) {
                                ref.invalidate(savingsProvider);
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not record savings. Try again.')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
