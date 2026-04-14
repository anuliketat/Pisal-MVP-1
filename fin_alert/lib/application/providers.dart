import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';
import '../core/domain/mail_sync_service.dart';
import '../core/domain/transaction_csv_exporter.dart';
import '../core/domain/transaction_parse_pipeline.dart';
import '../core/domain/transaction_repository.dart';
import '../core/export/atomic_csv_export_service.dart';
import '../core/models/transaction_record.dart';
import '../core/parse/parse_orchestrator.dart';
import '../core/sync/gmail_mail_sync_service.dart';

// --- Composition root overrides (see [bootstrap]) ---------------------------

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('Override appConfigProvider in bootstrap'),
);

final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => throw UnimplementedError('Override googleSignInProvider in bootstrap'),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => throw UnimplementedError(
    'Override transactionRepositoryProvider in bootstrap',
  ),
);

final transactionCsvExporterProvider = Provider<TransactionCsvExporter>(
  (ref) => throw UnimplementedError(
    'Override transactionCsvExporterProvider in bootstrap',
  ),
);

// --- Owned resources (Riverpod lifecycle) ------------------------------------

final _parseHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final transactionParsePipelineProvider =
    Provider<TransactionParsePipeline>((ref) {
  return ParseOrchestrator(
    config: ref.watch(appConfigProvider),
    httpClient: ref.watch(_parseHttpClientProvider),
  );
});

final mailSyncServiceProvider = Provider<MailSyncService>((ref) {
  return GmailMailSyncService(
    googleSignIn: ref.watch(googleSignInProvider),
    repo: ref.watch(transactionRepositoryProvider),
    csvExporter: ref.watch(transactionCsvExporterProvider),
    config: ref.watch(appConfigProvider),
    pipeline: ref.watch(transactionParsePipelineProvider),
  );
});

// --- UI-facing async queries -------------------------------------------------

final transactionsProvider =
    FutureProvider<List<TransactionRecord>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.all(limit: 500);
});

final reviewQueueProvider =
    FutureProvider<List<TransactionRecord>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.needingReview(limit: 100);
});

final exportPathProvider = FutureProvider<String>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'exports', TransactionCsvExporter.fileName);
});
