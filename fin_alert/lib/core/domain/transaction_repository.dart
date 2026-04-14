import '../models/transaction_record.dart';

/// Persistence for transactions and Gmail sync cursor state.
abstract class TransactionRepository {
  Future<void> close();

  Future<List<TransactionRecord>> all({int? limit});

  Future<List<TransactionRecord>> needingReview({int limit = 50});

  Future<TransactionRecord?> byId(String id);

  /// Upsert by [TransactionRecord.dedupKey] when set; else by transaction_id.
  Future<UpsertResult> upsert(TransactionRecord r);

  Future<void> updateTag({
    required String transactionId,
    String? userCategory,
    String? iconId,
    int? needsReview,
    bool clearNeedsReview = true,
  });

  Future<SyncStateRow> getSyncState();

  Future<void> saveSyncState({
    String? lastHistoryId,
    String? lastSyncAt,
    int? syncWindowMonths,
  });

  Future<void> clearAllData();

  Future<void> enqueuePendingTag({
    required String transactionId,
    String? userCategory,
    String? iconId,
  });
}

class UpsertResult {
  const UpsertResult({required this.updated, required this.transactionId});

  final bool updated;
  final String transactionId;
}

class SyncStateRow {
  const SyncStateRow({
    this.lastHistoryId,
    this.lastSyncAt,
    this.syncWindowMonths = 12,
  });

  final String? lastHistoryId;
  final String? lastSyncAt;
  final int syncWindowMonths;
}
