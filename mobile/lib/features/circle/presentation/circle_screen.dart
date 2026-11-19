import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/money_text.dart';
import '../../feed/feed_repository.dart';
import '../../feed/presentation/vote_sheet.dart';

class CircleScreen extends ConsumerStatefulWidget {
  const CircleScreen({super.key, required this.shareToken});

  final String shareToken;

  @override
  ConsumerState<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends ConsumerState<CircleScreen> {
  PurchaseRequest? _request;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref
          .read(feedRepositoryProvider)
          .fetchByShareToken(widget.shareToken);
      setState(() {
        _request = r;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _vote(VoteDecision decision) async {
    final request = _request;
    if (request == null) return;
    final reason = await showVoteReasonSheet(context, decision: decision);
    if (reason == null) return;
    try {
      final updated = await ref.read(feedRepositoryProvider).castVote(
            requestId: request.id,
            decision: decision,
            reason: reason,
          );
      setState(() => _request = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your circle vote counted.')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Private Circle')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _request == null
                  ? const Center(child: Text('Link not found or expired.'))
                  : _buildBody(_request!),
    );
  }

  Widget _buildBody(PurchaseRequest request) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Someone trusts your veto power',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        if (request.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: request.imageUrl!,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 12),
        Text(request.title, style: Theme.of(context).textTheme.titleLarge),
        MoneyText(
          priceCents: request.priceCents,
          currency: request.currency,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text('“${request.whyWant}”'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: request.isOpen
                    ? () => _vote(VoteDecision.approve)
                    : null,
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
                onPressed:
                    request.isOpen ? () => _vote(VoteDecision.reject) : null,
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
    );
  }
}
