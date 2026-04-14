import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _dbName = 'fin_alert.db';
const _version = 1;

Future<Database> openFinDatabase(String basePath) async {
  final path = p.join(basePath, _dbName);
  return openDatabase(
    path,
    version: _version,
    onCreate: (db, version) async {
      await db.execute('''
CREATE TABLE transactions (
  transaction_id TEXT PRIMARY KEY,
  date_time TEXT NOT NULL,
  merchant TEXT,
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  type TEXT NOT NULL,
  payment_mode TEXT NOT NULL,
  inferred_category TEXT,
  user_category TEXT,
  icon_id TEXT,
  source TEXT NOT NULL,
  raw_text TEXT NOT NULL,
  parsed_at TEXT NOT NULL,
  confidence_score REAL NOT NULL,
  synced INTEGER NOT NULL DEFAULT 0,
  gmail_message_id TEXT,
  gmail_history_id TEXT,
  dedup_key TEXT UNIQUE,
  needs_review INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''');
      await db.execute(
        'CREATE INDEX idx_transactions_date ON transactions(date_time DESC);',
      );
      await db.execute(
        'CREATE INDEX idx_transactions_review ON transactions(needs_review);',
      );
      await db.execute('''
CREATE TABLE sync_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  last_history_id TEXT,
  last_sync_at TEXT,
  sync_window_months INTEGER NOT NULL DEFAULT 12
);
''');
      await db.execute('INSERT INTO sync_state (id) VALUES (1);');
      await db.execute('''
CREATE TABLE pending_tag_actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id TEXT NOT NULL,
  user_category TEXT,
  icon_id TEXT,
  created_at TEXT NOT NULL
);
''');
    },
  );
}
