import 'package:sqflite/sqflite.dart';

import '../domain/transaction_repository.dart';
import '../models/transaction_record.dart';
import 'database.dart';

class SqfliteTransactionRepository implements TransactionRepository {
  SqfliteTransactionRepository(this._basePath);

  final String _basePath;
  Database? _db;

  Future<Database> get _database async {
    _db ??= await openFinDatabase(_basePath);
    return _db!;
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<List<TransactionRecord>> all({int? limit}) async {
    final d = await _database;
    final rows = await d.query(
      'transactions',
      orderBy: 'date_time DESC',
      limit: limit,
    );
    return rows.map(TransactionRecord.fromRow).toList();
  }

  @override
  Future<List<TransactionRecord>> needingReview({int limit = 50}) async {
    final d = await _database;
    final rows = await d.query(
      'transactions',
      where: 'needs_review = 1',
      orderBy: 'date_time DESC',
      limit: limit,
    );
    return rows.map(TransactionRecord.fromRow).toList();
  }

  @override
  Future<TransactionRecord?> byId(String id) async {
    final d = await _database;
    final rows = await d.query(
      'transactions',
      where: 'transaction_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TransactionRecord.fromRow(rows.first);
  }

  @override
  Future<UpsertResult> upsert(TransactionRecord r) async {
    final d = await _database;
    final row = r.toRow();
    final now = DateTime.now().toUtc().toIso8601String();
    row['updated_at'] = now;
    row['created_at'] = r.createdAt?.toUtc().toIso8601String() ?? now;

    if (r.dedupKey != null && r.dedupKey!.isNotEmpty) {
      final existing = await d.query(
        'transactions',
        columns: ['transaction_id'],
        where: 'dedup_key = ?',
        whereArgs: [r.dedupKey],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final id = existing.first['transaction_id'] as String;
        row['transaction_id'] = id;
        await d.update(
          'transactions',
          row,
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        return UpsertResult(updated: true, transactionId: id);
      }
    }

    try {
      await d.insert('transactions', row);
      return UpsertResult(updated: false, transactionId: r.transactionId);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        await d.update(
          'transactions',
          row,
          where: 'transaction_id = ?',
          whereArgs: [r.transactionId],
        );
        return UpsertResult(updated: true, transactionId: r.transactionId);
      }
      rethrow;
    }
  }

  @override
  Future<void> updateTag({
    required String transactionId,
    String? userCategory,
    String? iconId,
    int? needsReview,
    bool clearNeedsReview = true,
  }) async {
    final d = await _database;
    final now = DateTime.now().toUtc().toIso8601String();
    final review = needsReview ?? (clearNeedsReview ? 0 : 1);
    await d.update(
      'transactions',
      {
        'user_category': userCategory,
        'icon_id': iconId,
        'needs_review': review,
        'updated_at': now,
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  @override
  Future<SyncStateRow> getSyncState() async {
    final d = await _database;
    final rows = await d.query('sync_state', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      return const SyncStateRow();
    }
    final m = rows.first;
    return SyncStateRow(
      lastHistoryId: m['last_history_id'] as String?,
      lastSyncAt: m['last_sync_at'] as String?,
      syncWindowMonths: (m['sync_window_months'] as num?)?.toInt() ?? 12,
    );
  }

  @override
  Future<void> saveSyncState({
    String? lastHistoryId,
    String? lastSyncAt,
    int? syncWindowMonths,
  }) async {
    final d = await _database;
    final cur = await getSyncState();
    await d.update(
      'sync_state',
      {
        'last_history_id': lastHistoryId ?? cur.lastHistoryId,
        'last_sync_at': lastSyncAt ?? cur.lastSyncAt,
        'sync_window_months': syncWindowMonths ?? cur.syncWindowMonths,
      },
      where: 'id = 1',
    );
  }

  @override
  Future<void> clearAllData() async {
    final d = await _database;
    await d.delete('transactions');
    await d.delete('pending_tag_actions');
    await d.update(
      'sync_state',
      {
        'last_history_id': null,
        'last_sync_at': null,
      },
      where: 'id = 1',
    );
  }

  @override
  Future<void> enqueuePendingTag({
    required String transactionId,
    String? userCategory,
    String? iconId,
  }) async {
    final d = await _database;
    await d.insert('pending_tag_actions', {
      'transaction_id': transactionId,
      'user_category': userCategory,
      'icon_id': iconId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

extension on DatabaseException {
  bool isUniqueConstraintError() {
    return message.contains('UNIQUE') || message.contains('unique');
  }
}
