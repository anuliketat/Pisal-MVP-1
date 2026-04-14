/// Primary user-visible export (semicolon CSV, atomic write).
abstract class TransactionCsvExporter {
  static const fileName = 'transactions.csv';

  Future<String> exportAllAtomic();
}
