import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/transaction_record.dart';
import 'models/rule_parse_input.dart';

/// Calls optional backend `POST /parse/batch`. Server must hold HF credentials.
class BackendParseClient {
  BackendParseClient({required this.baseUrl, required this.httpClient});

  final String baseUrl;
  final http.Client httpClient;

  Uri get _uri => Uri.parse('$baseUrl/parse/batch');

  Future<Map<String, TransactionRecord>> parseBatch(
    List<RuleParseInput> items,
  ) async {
    if (items.isEmpty) return {};
    final body = jsonEncode({
      'items': items
          .map(
            (e) => {
              'id': e.messageId,
              'snippet': e.snippet,
              'subject': e.subject,
              'from': e.fromHeader,
              'date_header': e.dateHeader,
            },
          )
          .toList(),
    });
    final res = await httpClient.post(
      _uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw BackendParseException(res.statusCode, res.body);
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>? ?? [];
    final out = <String, TransactionRecord>{};
    for (final r in results) {
      final m = r as Map<String, dynamic>;
      final id = m['id'] as String? ?? '';
      if (id.isEmpty) continue;
      final tr = TransactionRecord(
        transactionId: m['transaction_id'] as String? ?? 'gmail_$id',
        dateTime: DateTime.parse(m['date_time'] as String).toUtc(),
        merchant: m['merchant'] as String?,
        amount: (m['amount'] as num).toDouble(),
        currency: m['currency'] as String? ?? 'INR',
        type: m['type'] as String? ?? 'debit',
        paymentMode: m['payment_mode'] as String? ?? 'other',
        inferredCategory: m['inferred_category'] as String?,
        source: 'gmail',
        rawText: (m['raw_text'] as String?) ?? '',
        parsedAt: DateTime.now().toUtc(),
        confidenceScore: (m['confidence_score'] as num?)?.toDouble() ?? 0.8,
        gmailMessageId: id,
        needsReview:
            ((m['confidence_score'] as num?)?.toDouble() ?? 0.8) < 0.62
                ? 1
                : 0,
      );
      out[id] = tr;
    }
    return out;
  }
}

class BackendParseException implements Exception {
  BackendParseException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'BackendParseException($statusCode): $body';
}
