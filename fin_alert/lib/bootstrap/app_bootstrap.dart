import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/providers.dart';
import '../core/config/app_config.dart';
import '../core/db/sqflite_transaction_repository.dart';
import '../core/export/atomic_csv_export_service.dart';
import '../core/sync/gmail_mail_sync_service.dart';

/// Wires platform services and [ProviderScope] overrides (modular composition root).
class AppBootstrap {
  const AppBootstrap._();

  static Future<List<Override>> buildOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final config = AppConfig(prefs);
    final dir = await getApplicationDocumentsDirectory();
    final repo = SqfliteTransactionRepository(dir.path);
    final exportDir = p.join(dir.path, 'exports');
    final csvExporter = AtomicCsvExportService(repo, exportDir: exportDir);
    final googleSignIn = GmailMailSyncService.createPlatformGoogleSignIn();

    return [
      appConfigProvider.overrideWithValue(config),
      googleSignInProvider.overrideWithValue(googleSignIn),
      transactionRepositoryProvider.overrideWithValue(repo),
      transactionCsvExporterProvider.overrideWithValue(csvExporter),
    ];
  }
}
