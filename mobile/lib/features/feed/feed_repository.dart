import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/models/models.dart';
import '../auth/auth_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  if (AppConfig.useMockData) {
    return MockFeedRepository(ref.watch(authRepositoryProvider));
  }
  return SupabaseFeedRepository(Supabase.instance.client);
});

final feedProvider = FutureProvider<List<PurchaseRequest>>((ref) async {
  return ref.watch(feedRepositoryProvider).fetchPublicFeed();
});

abstract class FeedRepository {
  Future<List<PurchaseRequest>> fetchPublicFeed();
  Future<PurchaseRequest?> fetchByShareToken(String token);
  Future<PurchaseRequest> castVote({
    required String requestId,
    required VoteDecision decision,
    required String reason,
  });
  Future<PurchaseRequest> createRequest({
    required String title,
    required int priceCents,
    required CurrencyCode currency,
    required String whyWant,
    String? cheaperAlt,
    String? imageUrl,
    String? productUrl,
    required int durationHours,
    required RequestVisibility visibility,
  });
  Future<SavingsSummary> fetchSavings();
  Future<void> markSkipped(String requestId);
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  });
}

class MockFeedRepository implements FeedRepository {
  MockFeedRepository(this._auth);

  final AuthRepository _auth;
  final _uuid = const Uuid();

  late final List<PurchaseRequest> _items = _seed();

  List<PurchaseRequest> _seed() {
    final now = DateTime.now();
    return [
      PurchaseRequest(
        id: '22222222-2222-2222-2222-222222222201',
        ownerId: '11111111-1111-1111-1111-111111111101',
        title: 'Shopee 11.11 Mechanical Keyboard',
        priceCents: 349900,
        currency: CurrencyCode.PHP,
        imageUrl: 'https://picsum.photos/seed/kb-ph/800/600',
        productUrl: 'https://shopee.ph/example-keyboard',
        whyWant: 'RGB switches will make me code faster. Probably.',
        cheaperAlt: 'Membrane office keyboard I already own',
        visibility: RequestVisibility.public,
        shareToken: 'seedtoken01',
        durationHours: 24,
        endsAt: now.add(const Duration(hours: 20)),
        status: RequestStatus.open,
        approveCount: 12,
        rejectCount: 19,
        moderationStatus: ModerationStatus.approved,
      ),
      PurchaseRequest(
        id: '22222222-2222-2222-2222-222222222216',
        ownerId: '11111111-1111-1111-1111-111111111103',
        title: '\$40 Stanley Cup Dupe',
        priceCents: 3999,
        currency: CurrencyCode.USD,
        imageUrl: 'https://picsum.photos/seed/stanley/800/600',
        whyWant: 'Hydration aesthetics are a personality now.',
        cheaperAlt: 'Any tumbler I own',
        visibility: RequestVisibility.public,
        shareToken: 'seedtoken16',
        durationHours: 6,
        endsAt: now.add(const Duration(hours: 4)),
        status: RequestStatus.open,
        approveCount: 9,
        rejectCount: 21,
        moderationStatus: ModerationStatus.approved,
      ),
      PurchaseRequest(
        id: '22222222-2222-2222-2222-222222222217',
        ownerId: '11111111-1111-1111-1111-111111111103',
        title: 'Late-Night DoorDash Spree',
        priceCents: 4200,
        currency: CurrencyCode.USD,
        imageUrl: 'https://picsum.photos/seed/doordash/800/600',
        whyWant: 'It is 12:40am and cooking is a myth.',
        cheaperAlt: 'Toast + dignity',
        visibility: RequestVisibility.public,
        shareToken: 'seedtoken17',
        durationHours: 1,
        endsAt: now.add(const Duration(minutes: 40)),
        status: RequestStatus.open,
        approveCount: 4,
        rejectCount: 25,
        moderationStatus: ModerationStatus.approved,
      ),
      PurchaseRequest(
        id: '22222222-2222-2222-2222-222222222203',
        ownerId: '11111111-1111-1111-1111-111111111102',
        title: 'Concert Floor Tickets',
        priceCents: 45000,
        currency: CurrencyCode.SGD,
        imageUrl: 'https://picsum.photos/seed/concert/800/600',
        whyWant: 'FOMO is undefeated and the setlist leaks look insane.',
        cheaperAlt: 'Streaming the livestream with friends',
        visibility: RequestVisibility.public,
        shareToken: 'seedtoken03',
        durationHours: 24,
        endsAt: now.add(const Duration(hours: 18)),
        status: RequestStatus.open,
        approveCount: 22,
        rejectCount: 31,
        moderationStatus: ModerationStatus.approved,
      ),
      PurchaseRequest(
        id: '22222222-2222-2222-2222-222222222218',
        ownerId: '11111111-1111-1111-1111-111111111104',
        title: 'Overpriced Vitamin C Serum',
        priceCents: 6800,
        currency: CurrencyCode.EUR,
        imageUrl: 'https://picsum.photos/seed/serum/800/600',
        whyWant: 'The influencer said glass skin in 7 days.',
        cheaperAlt: 'Pharmacy vitamin C',
        visibility: RequestVisibility.public,
        shareToken: 'seedtoken18',
        durationHours: 24,
        endsAt: now.add(const Duration(hours: 19)),
        status: RequestStatus.open,
        approveCount: 6,
        rejectCount: 18,
        moderationStatus: ModerationStatus.approved,
      ),
    ];
  }

  @override
  Future<List<PurchaseRequest>> fetchPublicFeed() async {
    final user = await _auth.currentUser();
    final blocked = user?.blockedIds ?? const [];
    return _items
        .where((r) =>
            r.visibility == RequestVisibility.public &&
            r.moderationStatus == ModerationStatus.approved &&
            !blocked.contains(r.ownerId))
        .toList();
  }

  @override
  Future<PurchaseRequest?> fetchByShareToken(String token) async {
    try {
      return _items.firstWhere((r) => r.shareToken == token);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PurchaseRequest> castVote({
    required String requestId,
    required VoteDecision decision,
    required String reason,
  }) async {
    if (reason.trim().length < 8 || reason.length > 140) {
      throw Exception('Reason must be 8–140 characters');
    }
    final idx = _items.indexWhere((r) => r.id == requestId);
    if (idx < 0) throw Exception('Request not found');
    final r = _items[idx];
    if (!r.isOpen) throw Exception('Voting is locked');
    final updated = PurchaseRequest(
      id: r.id,
      ownerId: r.ownerId,
      title: r.title,
      priceCents: r.priceCents,
      currency: r.currency,
      imageUrl: r.imageUrl,
      productUrl: r.productUrl,
      whyWant: r.whyWant,
      cheaperAlt: r.cheaperAlt,
      visibility: r.visibility,
      shareToken: r.shareToken,
      durationHours: r.durationHours,
      endsAt: r.endsAt,
      status: r.status,
      approveCount: r.approveCount + (decision == VoteDecision.approve ? 1 : 0),
      rejectCount: r.rejectCount + (decision == VoteDecision.reject ? 1 : 0),
      finalVerdict: r.finalVerdict,
      moderationStatus: r.moderationStatus,
    );
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<PurchaseRequest> createRequest({
    required String title,
    required int priceCents,
    required CurrencyCode currency,
    required String whyWant,
    String? cheaperAlt,
    String? imageUrl,
    String? productUrl,
    required int durationHours,
    required RequestVisibility visibility,
  }) async {
    final user = await _auth.ensureSession();
    final created = PurchaseRequest(
      id: _uuid.v4(),
      ownerId: user.id,
      title: title,
      priceCents: priceCents,
      currency: currency,
      imageUrl: imageUrl,
      productUrl: productUrl,
      whyWant: whyWant,
      cheaperAlt: cheaperAlt,
      visibility: visibility,
      shareToken: _uuid.v4().replaceAll('-', '').substring(0, 16),
      durationHours: durationHours,
      endsAt: DateTime.now().add(Duration(hours: durationHours)),
      status: RequestStatus.open,
      approveCount: 0,
      rejectCount: 0,
      moderationStatus: ModerationStatus.approved,
    );
    _items.insert(0, created);
    return created;
  }

  @override
  Future<SavingsSummary> fetchSavings() async {
    final user = await _auth.ensureSession();
    final mine = _items.where((r) => r.ownerId == user.id).toList();
    return SavingsSummary(
      requestsSubmitted: mine.length,
      approvedCount: mine.where((r) => r.finalVerdict == FinalVerdict.approve).length,
      rejectedCount: mine.where((r) => r.finalVerdict == FinalVerdict.reject).length,
      estimatedSavedCents: 89900,
      currency: user.currency,
    );
  }

  @override
  Future<void> markSkipped(String requestId) async {}

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {}
}

class SupabaseFeedRepository implements FeedRepository {
  SupabaseFeedRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PurchaseRequest>> fetchPublicFeed() async {
    final rows = await _client
        .from('purchase_requests')
        .select()
        .eq('visibility', 'public')
        .eq('moderation_status', 'approved')
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => PurchaseRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<PurchaseRequest?> fetchByShareToken(String token) async {
    final row = await _client
        .from('purchase_requests')
        .select()
        .eq('share_token', token)
        .maybeSingle();
    if (row == null) return null;
    return PurchaseRequest.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<PurchaseRequest> castVote({
    required String requestId,
    required VoteDecision decision,
    required String reason,
  }) async {
    // Prefer edge function; fall back to RPC for local simplicity.
    try {
      final res = await _client.functions.invoke(
        'cast-vote',
        body: {
          'request_id': requestId,
          'decision': decision.name,
          'reason': reason,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['request'] != null) {
        return PurchaseRequest.fromJson(
          Map<String, dynamic>.from(data['request'] as Map),
        );
      }
    } catch (_) {
      // fall through to RPC
    }

    final row = await _client.rpc('cast_vote', params: {
      'p_request_id': requestId,
      'p_decision': decision.name,
      'p_reason': reason,
    });
    return PurchaseRequest.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<PurchaseRequest> createRequest({
    required String title,
    required int priceCents,
    required CurrencyCode currency,
    required String whyWant,
    String? cheaperAlt,
    String? imageUrl,
    String? productUrl,
    required int durationHours,
    required RequestVisibility visibility,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final endsAt = DateTime.now().toUtc().add(Duration(hours: durationHours));
    final row = await _client
        .from('purchase_requests')
        .insert({
          'owner_id': uid,
          'title': title,
          'price_cents': priceCents,
          'currency': currency.name,
          'image_url': imageUrl,
          'product_url': productUrl,
          'why_want': whyWant,
          'cheaper_alt': cheaperAlt,
          'visibility': visibility.name,
          'duration_hours': durationHours,
          'ends_at': endsAt.toIso8601String(),
          'moderation_status': 'approved',
        })
        .select()
        .single();
    return PurchaseRequest.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<SavingsSummary> fetchSavings() async {
    final uid = _client.auth.currentUser!.id;
    final mine = await _client
        .from('purchase_requests')
        .select()
        .eq('owner_id', uid);
    final savings = await _client
        .from('savings_events')
        .select()
        .eq('user_id', uid);

    final list = (mine as List)
        .map((e) => PurchaseRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final savedCents = (savings as List).fold<int>(
      0,
      (sum, e) => sum + (e['amount_cents'] as int? ?? 0),
    );
    final currency = list.isNotEmpty
        ? list.first.currency
        : CurrencyCode.USD;

    return SavingsSummary(
      requestsSubmitted: list.length,
      approvedCount:
          list.where((r) => r.finalVerdict == FinalVerdict.approve).length,
      rejectedCount:
          list.where((r) => r.finalVerdict == FinalVerdict.reject).length,
      estimatedSavedCents: savedCents,
      currency: currency,
    );
  }

  @override
  Future<void> markSkipped(String requestId) async {
    await _client.rpc('mark_skipped', params: {'p_request_id': requestId});
  }

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('reports').insert({
      'reporter_id': uid,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    });
  }
}
