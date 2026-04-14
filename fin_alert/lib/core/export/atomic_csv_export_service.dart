import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../domain/transaction_csv_exporter.dart';
import '../domain/transaction_repository.dart';
import '../models/transaction_record.dart';

/// Writes all rows to [exportDir]/[TransactionCsvExporter.fileName] (atomic rename).
class AtomicCsvExportService implements TransactionCsvExporter {
  AtomicCsvExportService(this._repo, {required this.exportDir});

  final TransactionRepository _repo;
  final String exportDir;

  @override
  Future<String> exportAllAtomic() async {
    final dir = Directory(exportDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final rows = await _repo.all();
    final converter = const ListToCsvConverter(fieldDelimiter: ';');
    final lines = <List<String>>[
      TransactionRecord.csvHeader.split(';'),
      ...rows.map((r) => r.toCsvFields()),
    ];
    final csv = converter.convert(lines);
    final name = TransactionCsvExporter.fileName;
    final tmpPath = p.join(exportDir, '$name.tmp');
    final finalPath = p.join(exportDir, name);
    final tmp = File(tmpPath);
    final out = File(finalPath);
    await tmp.writeAsString(csv, flush: true);
    if (await out.exists()) {
      await out.delete();
    }
    await tmp.rename(finalPath);
    return finalPath;
  }
}
