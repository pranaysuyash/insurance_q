/// Pay-per-Q&A packs for occasional users who don't need a full subscription.
///
/// Packs are consumable — once purchased, questions are deducted one at a time.
/// Packs expire after [validityDays] from purchase. Multiple packs can stack:
/// questions are consumed from the earliest-expiring pack first (FIFO).
enum QaPackType {
  starter('Starter', 5, '₹49', 90, 'Try CoverWise'),
  value('Value', 15, '₹119', 90, 'Best for quick lookups'),
  pro('Pro', 30, '₹199', 90, 'Heavy questioner');

  final String displayName;
  final int questionCount;
  final String price;
  final int validityDays;
  final String tagline;

  const QaPackType(
    this.displayName,
    this.questionCount,
    this.price,
    this.validityDays,
    this.tagline,
  );
}

/// A single purchased pack instance, tracking remaining questions and expiry.
class QaPack {
  final QaPackType type;
  final int questionsRemaining;
  final DateTime purchasedAt;
  final DateTime expiresAt;

  const QaPack({
    required this.type,
    required this.questionsRemaining,
    required this.purchasedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get totalQuestions => type.questionCount;

  double get usagePercent =>
      totalQuestions > 0 ? (totalQuestions - questionsRemaining) / totalQuestions : 0.0;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'questions_remaining': questionsRemaining,
        'purchased_at': purchasedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

  factory QaPack.fromJson(Map<String, dynamic> json) => QaPack(
        type: QaPackType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => QaPackType.starter,
        ),
        questionsRemaining: json['questions_remaining'] ?? 0,
        purchasedAt: DateTime.parse(json['purchased_at']),
        expiresAt: DateTime.parse(json['expires_at']),
      );

  QaPack copyWith({
    QaPackType? type,
    int? questionsRemaining,
    DateTime? purchasedAt,
    DateTime? expiresAt,
  }) =>
      QaPack(
        type: type ?? this.type,
        questionsRemaining: questionsRemaining ?? this.questionsRemaining,
        purchasedAt: purchasedAt ?? this.purchasedAt,
        expiresAt: expiresAt ?? this.expiresAt,
      );
}
