import '../models/transaction_record.dart';
import '../parse/models/rule_parse_input.dart';

/// Turns raw email slices into [TransactionRecord]s (rules + optional backend).
abstract class TransactionParsePipeline {
  Future<List<TransactionRecord>> parseMessages(List<RuleParseInput> inputs);
}
