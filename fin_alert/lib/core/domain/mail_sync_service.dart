typedef SyncProgressCallback = void Function(String status, int processed);

/// Coordinates remote mail fetch, parse, persistence, and CSV export.
abstract class MailSyncService {
  Future<bool> signInSilently();

  Future<void> signOut();

  Future<SyncSummary> syncFull({SyncProgressCallback? progress});

  Future<SyncSummary> syncIncremental({SyncProgressCallback? progress});
}

class SyncSummary {
  const SyncSummary({
    required this.success,
    this.messagesListed = 0,
    this.parsed = 0,
    this.inserted = 0,
    this.csvPath,
    this.historyId,
    this.error,
  });

  final bool success;
  final int messagesListed;
  final int parsed;
  final int inserted;
  final String? csvPath;
  final String? historyId;
  final String? error;
}
