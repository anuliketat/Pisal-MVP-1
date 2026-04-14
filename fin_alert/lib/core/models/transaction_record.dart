/// Mirrors CSV + local-only columns. Enums stored as lowercase strings in DB/CSV.
class TransactionRecord {
  const TransactionRecord({
    required this.transactionId,
    required this.dateTime,
    this.merchant,
    required this.amount,
    required this.currency,
    required this.type,
    required this.paymentMode,
    this.inferredCategory,
    this.userCategory,
    this.iconId,
    required this.source,
    required this.rawText,
    required this.parsedAt,
    required this.confidenceScore,
    this.synced = 0,
    this.gmailMessageId,
    this.gmailHistoryId,
    this.dedupKey,
    this.needsReview = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String transactionId;
  final DateTime dateTime;
  final String? merchant;
  final double amount;
  final String currency;
  final String type;
  final String paymentMode;
  final String? inferredCategory;
  final String? userCategory;
  final String? iconId;
  final String source;
  final String rawText;
  final DateTime parsedAt;
  final double confidenceScore;
  final int synced;
  final String? gmailMessageId;
  final String? gmailHistoryId;
  final String? dedupKey;
  final int needsReview;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const csvHeader =
      'transaction_id;date_time;merchant;amount;currency;type;payment_mode;inferred_category;user_category;icon_id;source;raw_text;parsed_at;confidence_score';

  TransactionRecord copyWith({
    String? transactionId,
    DateTime? dateTime,
    String? merchant,
    double? amount,
    String? currency,
    String? type,
    String? paymentMode,
    String? inferredCategory,
    String? userCategory,
    String? iconId,
    String? source,
    String? rawText,
    DateTime? parsedAt,
    double? confidenceScore,
    int? synced,
    String? gmailMessageId,
    String? gmailHistoryId,
    String? dedupKey,
    int? needsReview,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionRecord(
      transactionId: transactionId ?? this.transactionId,
      dateTime: dateTime ?? this.dateTime,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      paymentMode: paymentMode ?? this.paymentMode,
      inferredCategory: inferredCategory ?? this.inferredCategory,
      userCategory: userCategory ?? this.userCategory,
      iconId: iconId ?? this.iconId,
      source: source ?? this.source,
      rawText: rawText ?? this.rawText,
      parsedAt: parsedAt ?? this.parsedAt,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      synced: synced ?? this.synced,
      gmailMessageId: gmailMessageId ?? this.gmailMessageId,
      gmailHistoryId: gmailHistoryId ?? this.gmailHistoryId,
      dedupKey: dedupKey ?? this.dedupKey,
      needsReview: needsReview ?? this.needsReview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'transaction_id': transactionId,
      'date_time': dateTime.toUtc().toIso8601String(),
      'merchant': merchant,
      'amount': amount,
      'currency': currency,
      'type': type,
      'payment_mode': paymentMode,
      'inferred_category': inferredCategory,
      'user_category': userCategory,
      'icon_id': iconId,
      'source': source,
      'raw_text': rawText,
      'parsed_at': parsedAt.toUtc().toIso8601String(),
      'confidence_score': confidenceScore,
      'synced': synced,
      'gmail_message_id': gmailMessageId,
      'gmail_history_id': gmailHistoryId,
      'dedup_key': dedupKey,
      'needs_review': needsReview,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  static TransactionRecord fromRow(Map<String, Object?> m) {
    double toDouble(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    DateTime parseDt(Object? v) {
      if (v is String) return DateTime.parse(v);
      return DateTime.now().toUtc();
    }

    return TransactionRecord(
      transactionId: m['transaction_id']! as String,
      dateTime: parseDt(m['date_time']),
      merchant: m['merchant'] as String?,
      amount: toDouble(m['amount']),
      currency: m['currency'] as String? ?? 'USD',
      type: m['type'] as String? ?? 'debit',
      paymentMode: m['payment_mode'] as String? ?? 'other',
      inferredCategory: m['inferred_category'] as String?,
      userCategory: m['user_category'] as String?,
      iconId: m['icon_id'] as String?,
      source: m['source'] as String? ?? 'gmail',
      rawText: m['raw_text'] as String? ?? '',
      parsedAt: parseDt(m['parsed_at']),
      confidenceScore: toDouble(m['confidence_score']),
      synced: (m['synced'] as num?)?.toInt() ?? 0,
      gmailMessageId: m['gmail_message_id'] as String?,
      gmailHistoryId: m['gmail_history_id'] as String?,
      dedupKey: m['dedup_key'] as String?,
      needsReview: (m['needs_review'] as num?)?.toInt() ?? 0,
      createdAt: m['created_at'] != null ? parseDt(m['created_at']) : null,
      updatedAt: m['updated_at'] != null ? parseDt(m['updated_at']) : null,
    );
  }

  List<String> toCsvFields() {
    String esc(String? s) {
      if (s == null) return '';
      if (s.contains(';') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    return [
      transactionId,
      dateTime.toUtc().toIso8601String(),
      esc(merchant),
      amount.toStringAsFixed(2),
      currency,
      type,
      paymentMode,
      esc(inferredCategory),
      esc(userCategory),
      esc(iconId),
      source,
      esc(rawText),
      parsedAt.toUtc().toIso8601String(),
      confidenceScore.toStringAsFixed(3),
    ];
  }
}
