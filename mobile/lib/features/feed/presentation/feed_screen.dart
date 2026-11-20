import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ad_banner.dart';
import '../../../core/widgets/money_text.dart';
import 'request_safety_menu.dart';
import '../feed_repository.dart';
import 'vote_sheet.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _interstitial = InterstitialAdHelper();

  @override
  void initState() {
    super.initState();
    _interstitial.preload();
  }

  @override
  void dispose() {
    _interstitial.dispose();
    super.dispose();
  }

  Future<void> _vote(PurchaseRequest request, VoteDecision decision) async {
    final reason = await showVoteReasonSheet(context, decision: decision);
    if (reason == null || !mounted) return;

    try {
      await ref.read(feedRepositoryProvider).castVote(
            requestId: request.id,
            decision: decision,
            reason: reason,
          );
      ref.invalidate(feedProvider);
      await _interstitial.showIfReady();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == VoteDecision.approve
                ? 'Approve counted. Thanks for the reason.'
                : 'Reject counted. Wallet breathes easier.',
          ),
          backgroundColor: decision == VoteDecision.approve
              ? AppColors.approve
              : AppColors.reject,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HoldMyWallet'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Wallet, Please Wait',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Feed error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Public Square is quiet. Be the first ask.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(feedProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _RequestCard(
                        request: item,
                        onApprove: () => _vote(item, VoteDecision.approve),
                        onReject: () => _vote(item, VoteDecision.reject),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final PurchaseRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final remaining = request.endsAt.difference(DateTime.now());
    final hours = remaining.inHours;
    final mins = remaining.inMinutes.remainder(60);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: request.imageUrl == null
                  ? Container(
                      color: AppColors.mintSoft,
                      alignment: Alignment.center,
                      child: const Icon(Icons.shopping_bag_outlined, size: 48),
                    )
                  : CachedNetworkImage(
                      imageUrl: request.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.mintSoft),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.mintSoft,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    RequestSafetyMenu(request: request),
                  ],
                ),
                const SizedBox(height: 4),
                MoneyText(
                  priceCents: request.priceCents,
                  currency: request.currency,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '“${request.whyWant}”',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
                if (request.cheaperAlt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Cheaper alt: ${request.cheaperAlt}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 14),
                _VoteBar(request: request),
                const SizedBox(height: 8),
                Text(
                  request.isOpen
                      ? 'Closes in ${hours}h ${mins}m · ${request.totalVotes} votes'
                      : 'Voting locked',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: request.isOpen ? onApprove : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.approve,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: request.isOpen ? onReject : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.reject,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar({required this.request});

  final PurchaseRequest request;

  @override
  Widget build(BuildContext context) {
    final ratio = request.approveRatio;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (ratio * 1000).round().clamp(1, 999),
                  child: Container(color: AppColors.approve),
                ),
                Expanded(
                  flex: ((1 - ratio) * 1000).round().clamp(1, 999),
                  child: Container(color: AppColors.reject),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${request.approveCount} approve',
              style: const TextStyle(
                color: AppColors.approve,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${request.rejectCount} reject',
              style: const TextStyle(
                color: AppColors.reject,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
