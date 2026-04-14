import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/transaction_parse_pipeline.dart';
import '../models/transaction_record.dart';
import 'backend_parse_client.dart';
import 'models/rule_parse_input.dart';
import 'rule_parser.dart';

class ParseOrchestrator implements TransactionParsePipeline {
  ParseOrchestrator({
    required AppConfig config,
    required http.Client httpClient,
  })  : _config = config,
        _http = httpClient;

  final AppConfig _config;
  final http.Client _http;
  final RuleParser _rules = RuleParser();

  @override
  Future<List<TransactionRecord>> parseMessages(
    List<RuleParseInput> inputs,
  ) async {
    final rules = <TransactionRecord>[];
    final forBackend = <RuleParseInput>[];
    for (final i in inputs) {
      final r = _rules.parse(i);
      if (r != null) {
        rules.add(_withDedup(r, i));
      } else {
        forBackend.add(i);
      }
    }

    if (_config.allowCloudParse &&
        _config.parseBackendUrl != null &&
        _config.parseBackendUrl!.isNotEmpty &&
        forBackend.isNotEmpty) {
      try {
        final client = BackendParseClient(
          baseUrl: _config.parseBackendUrl!.replaceAll(RegExp(r'/$'), ''),
          httpClient: _http,
        );
        final remote = await client.parseBatch(forBackend);
        for (final i in forBackend) {
          final tr = remote[i.messageId];
          if (tr != null) {
            final raw = tr.rawText.isNotEmpty
                ? tr.rawText
                : (i.snippet.length > 4000
                    ? i.snippet.substring(0, 4000)
                    : i.snippet);
            rules.add(_withDedup(tr.copyWith(rawText: raw), i));
          }
        }
      } catch (_) {
        // Fallback: skip unparseable without backend
      }
    }

    return rules;
  }

  TransactionRecord _withDedup(TransactionRecord r, RuleParseInput i) {
    final key = _dedupKey(i.messageId, r.amount, r.dateTime, r.merchant);
    return r.copyWith(dedupKey: key);
  }

  static String _dedupKey(
    String messageId,
    double amount,
    DateTime dt,
    String? merchant,
  ) {
    final raw =
        '$messageId|${amount.toStringAsFixed(2)}|${dt.toIso8601String()}|${merchant ?? ''}';
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
