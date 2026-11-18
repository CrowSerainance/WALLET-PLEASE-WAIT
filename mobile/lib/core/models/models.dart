// ignore_for_file: constant_identifier_names
enum CurrencyCode { PHP, SGD, MYR, IDR, USD, EUR }

enum RequestVisibility { public, circle }

enum RequestStatus { open, locked }

enum VoteDecision { approve, reject }

enum ModerationStatus { pending, approved, rejected }

enum FinalVerdict { approve, reject, tie }

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.region,
    required this.currency,
    this.blockedIds = const [],
    this.voiceOfReason = false,
  });

  final String id;
  final String displayName;
  final String region;
  final CurrencyCode currency;
  final List<String> blockedIds;
  final bool voiceOfReason;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Anonymous',
      region: json['region'] as String? ?? 'US',
      currency: CurrencyCode.values.byName(json['currency'] as String? ?? 'USD'),
      blockedIds: (json['blocked_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      voiceOfReason: json['voice_of_reason'] as bool? ?? false,
    );
  }
}

class PurchaseRequest {
  const PurchaseRequest({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.priceCents,
    required this.currency,
    required this.whyWant,
    required this.visibility,
    required this.shareToken,
    required this.durationHours,
    required this.endsAt,
    required this.status,
    required this.approveCount,
    required this.rejectCount,
    required this.moderationStatus,
    this.imageUrl,
    this.productUrl,
    this.cheaperAlt,
    this.finalVerdict,
  });

  final String id;
  final String ownerId;
  final String title;
  final int priceCents;
  final CurrencyCode currency;
  final String? imageUrl;
  final String? productUrl;
  final String whyWant;
  final String? cheaperAlt;
  final RequestVisibility visibility;
  final String shareToken;
  final int durationHours;
  final DateTime endsAt;
  final RequestStatus status;
  final int approveCount;
  final int rejectCount;
  final FinalVerdict? finalVerdict;
  final ModerationStatus moderationStatus;

  int get totalVotes => approveCount + rejectCount;

  double get approveRatio =>
      totalVotes == 0 ? 0.5 : approveCount / totalVotes;

  bool get isOpen =>
      status == RequestStatus.open && endsAt.isAfter(DateTime.now());

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    return PurchaseRequest(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      priceCents: json['price_cents'] as int,
      currency: CurrencyCode.values.byName(json['currency'] as String),
      imageUrl: json['image_url'] as String?,
      productUrl: json['product_url'] as String?,
      whyWant: json['why_want'] as String,
      cheaperAlt: json['cheaper_alt'] as String?,
      visibility: RequestVisibility.values.byName(json['visibility'] as String),
      shareToken: json['share_token'] as String,
      durationHours: json['duration_hours'] as int,
      endsAt: DateTime.parse(json['ends_at'] as String),
      status: RequestStatus.values.byName(json['status'] as String),
      approveCount: json['approve_count'] as int? ?? 0,
      rejectCount: json['reject_count'] as int? ?? 0,
      finalVerdict: json['final_verdict'] == null
          ? null
          : FinalVerdict.values.byName(json['final_verdict'] as String),
      moderationStatus: ModerationStatus.values
          .byName(json['moderation_status'] as String? ?? 'approved'),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'owner_id': ownerId,
        'title': title,
        'price_cents': priceCents,
        'currency': currency.name,
        'image_url': imageUrl,
        'product_url': productUrl,
        'why_want': whyWant,
        'cheaper_alt': cheaperAlt,
        'visibility': visibility.name,
        'duration_hours': durationHours,
        'ends_at': endsAt.toUtc().toIso8601String(),
        'moderation_status': moderationStatus.name,
      };
}

class SavingsSummary {
  const SavingsSummary({
    required this.requestsSubmitted,
    required this.approvedCount,
    required this.rejectedCount,
    required this.estimatedSavedCents,
    required this.currency,
  });

  final int requestsSubmitted;
  final int approvedCount;
  final int rejectedCount;
  final int estimatedSavedCents;
  final CurrencyCode currency;

  double get rejectRatio {
    final locked = approvedCount + rejectedCount;
    if (locked == 0) return 0;
    return rejectedCount / locked;
  }
}
