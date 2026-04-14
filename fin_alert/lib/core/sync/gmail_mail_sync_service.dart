import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import '../config/app_config.dart';
import '../domain/mail_sync_service.dart';
import '../domain/transaction_csv_exporter.dart';
import '../domain/transaction_parse_pipeline.dart';
import '../domain/transaction_repository.dart';
import '../parse/models/rule_parse_input.dart';
import '../parse/rule_parser.dart';

/// Gmail REST: list → metadata → [TransactionParsePipeline] → repo → CSV.
class GmailMailSyncService implements MailSyncService {
  GmailMailSyncService({
    required this.googleSignIn,
    required TransactionRepository repo,
    required TransactionCsvExporter csvExporter,
    required AppConfig config,
    required TransactionParsePipeline pipeline,
    this.onProgress,
  })  : _repo = repo,
        _csvExporter = csvExporter,
        _config = config,
        _pipeline = pipeline;

  final GoogleSignIn googleSignIn;
  final TransactionRepository _repo;
  final TransactionCsvExporter _csvExporter;
  final AppConfig _config;
  final TransactionParsePipeline _pipeline;
  final SyncProgressCallback? onProgress;

  static const _gmailReadonlyScope =
      'https://www.googleapis.com/auth/gmail.readonly';

  static GoogleSignIn createPlatformGoogleSignIn() {
    return GoogleSignIn(
      scopes: const [_gmailReadonlyScope],
    );
  }

  Future<gmail.GmailApi?> _api() async {
    final user = googleSignIn.currentUser ?? await googleSignIn.signIn();
    if (user == null) return null;
    final client = await googleSignIn.authenticatedClient();
    if (client == null) return null;
    return gmail.GmailApi(client);
  }

  @override
  Future<bool> signInSilently() async {
    await googleSignIn.signInSilently();
    return googleSignIn.currentUser != null;
  }

  @override
  Future<void> signOut() => googleSignIn.signOut();

  @override
  Future<SyncSummary> syncFull({SyncProgressCallback? progress}) async {
    final cb = progress ?? onProgress;
    final api = await _api();
    if (api == null) {
      return const SyncSummary(success: false, error: 'Not signed in');
    }

    final months = _config.syncWindowMonths;
    final newerThanDays = (months * 30).clamp(30, 36500);

    final profile = await api.users.getProfile('me');
    final historyId = profile.historyId;

    cb?.call('Listing messages…', 0);
    final inputs = <RuleParseInput>[];
    String? pageToken;
    var listed = 0;
    final q = RuleParser.transactionSearchQuery(newerThanDays: newerThanDays);

    do {
      final list = await api.users.messages.list(
        'me',
        q: q,
        maxResults: 100,
        pageToken: pageToken,
      );
      final ids = list.messages ?? [];
      for (final m in ids) {
        if (m.id == null) continue;
        final full = await api.users.messages.get(
          'me',
          m.id!,
          format: 'metadata',
          metadataHeaders: ['Subject', 'From', 'Date'],
        );
        listed++;
        final input = _messageToInput(full);
        if (input != null) inputs.add(input);
        if (listed % 25 == 0) {
          cb?.call('Fetching…', listed);
        }
      }
      pageToken = list.nextPageToken;
    } while (pageToken != null);

    cb?.call('Parsing…', listed);
    final parsed = await _pipeline.parseMessages(inputs);
    var inserted = 0;
    for (final row in parsed) {
      final res = await _repo.upsert(row);
      if (!res.updated) inserted++;
    }

    await _repo.saveSyncState(
      lastHistoryId: historyId,
      lastSyncAt: DateTime.now().toUtc().toIso8601String(),
      syncWindowMonths: months,
    );

    cb?.call('Exporting CSV…', listed);
    final path = await _csvExporter.exportAllAtomic();

    return SyncSummary(
      success: true,
      messagesListed: listed,
      parsed: parsed.length,
      inserted: inserted,
      csvPath: path,
      historyId: historyId,
    );
  }

  @override
  Future<SyncSummary> syncIncremental({SyncProgressCallback? progress}) async {
    final cb = progress ?? onProgress;
    final api = await _api();
    if (api == null) {
      return const SyncSummary(success: false, error: 'Not signed in');
    }

    final state = await _repo.getSyncState();
    final start = state.lastHistoryId;
    if (start == null || start.isEmpty) {
      return syncFull(progress: progress);
    }

    cb?.call('Incremental sync…', 0);
    final inputs = <RuleParseInput>[];
    String? pageToken;
    var count = 0;

    try {
      do {
        final hist = await api.users.history.list(
          'me',
          startHistoryId: start,
          pageToken: pageToken,
        );
        final history = hist.history ?? [];
        for (final h in history) {
          final added = h.messagesAdded ?? [];
          for (final ma in added) {
            final id = ma.message?.id;
            if (id == null) continue;
            final full = await api.users.messages.get(
              'me',
              id,
              format: 'metadata',
              metadataHeaders: ['Subject', 'From', 'Date'],
            );
            count++;
            final input = _messageToInput(full);
            if (input != null) inputs.add(input);
          }
        }
        pageToken = hist.nextPageToken;
      } while (pageToken != null);
    } catch (_) {
      return syncFull(progress: progress);
    }

    if (inputs.isEmpty) {
      final profile = await api.users.getProfile('me');
      await _repo.saveSyncState(
        lastHistoryId: profile.historyId,
        lastSyncAt: DateTime.now().toUtc().toIso8601String(),
      );
      return SyncSummary(
        success: true,
        messagesListed: 0,
        parsed: 0,
        inserted: 0,
        csvPath: await _csvExporter.exportAllAtomic(),
        historyId: profile.historyId,
      );
    }

    cb?.call('Parsing…', count);
    final parsed = await _pipeline.parseMessages(inputs);
    var inserted = 0;
    for (final row in parsed) {
      final res = await _repo.upsert(row);
      if (!res.updated) inserted++;
    }

    final profile = await api.users.getProfile('me');
    await _repo.saveSyncState(
      lastHistoryId: profile.historyId,
      lastSyncAt: DateTime.now().toUtc().toIso8601String(),
    );

    final path = await _csvExporter.exportAllAtomic();
    return SyncSummary(
      success: true,
      messagesListed: count,
      parsed: parsed.length,
      inserted: inserted,
      csvPath: path,
      historyId: profile.historyId,
    );
  }

  RuleParseInput? _messageToInput(gmail.Message msg) {
    final id = msg.id;
    if (id == null) return null;
    final headers = msg.payload?.headers ?? [];
    String? subject;
    String? from;
    String? date;
    for (final h in headers) {
      final name = h.name?.toLowerCase();
      if (name == 'subject') subject = h.value;
      if (name == 'from') from = h.value;
      if (name == 'date') date = h.value;
    }
    final snippet = msg.snippet ?? '';
    return RuleParseInput(
      messageId: id,
      subject: subject ?? '',
      snippet: snippet,
      fromHeader: from,
      dateHeader: date,
    );
  }
}
