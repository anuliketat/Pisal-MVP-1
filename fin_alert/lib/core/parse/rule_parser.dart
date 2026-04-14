import 'dart:math';

import 'package:intl/intl.dart';

import '../models/transaction_record.dart';
import 'models/rule_parse_input.dart';

/// Heuristic extraction from email subject + snippet. No network.
/// India-first: INR/UPI/NEFT/IMPS, bank senders, DD/MM/YYYY preference.
class RuleParser {
  /// INR-focused first; USD kept for edge cases (international cards).
  static final _amountPatterns = <RegExp>[
    RegExp(
      r'(?:Rs\.?|INR|₹|Rupee?s?)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:debited|credited|paid|spent|received|txn|transfer|amount|paid)\s*[:\s]+(?:of\s+)?(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:debited|credited|paid|spent)?',
      caseSensitive: false,
    ),
    RegExp(r'\$\s*([\d,]+(?:\.\d{1,2})?)'),
    RegExp(r'USD\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
  ];

  /// UPI VPAs and wallet handles common in India.
  static final _upi = RegExp(
    r'UPI|UPI[- ]?ID|VPA|@\s*(?:ybl|oksbi|okhdfcbank|okicici|okaxis|okbizaxis|axl|ibl|paytm|ptyes|abfspay|fbl|idfcbank|okidfc|icici|hdfcbank|axisbank|okbarodaaxis|yapl|axispay)',
    caseSensitive: false,
  );

  static final _card = RegExp(
    r'\b(?:card|visa|mastercard|amex|rupay|credit\s*card|debit\s*card)\b',
    caseSensitive: false,
  );

  static final _bankTransfer = RegExp(
    r'\b(?:NEFT|RTGS|IMPS|account\s*transfer|A/c\s*transfer|fund\s*transfer)\b',
    caseSensitive: false,
  );

  /// Returns null if no amount heuristic matches.
  TransactionRecord? parse(RuleParseInput input) {
    final text = '${input.subject}\n${input.snippet}';
    double? amount;
    for (final p in _amountPatterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final g = m.group(1);
        if (g != null) {
          amount = double.tryParse(g.replaceAll(',', ''));
          if (amount != null) break;
        }
      }
    }
    if (amount == null) return null;

    final currency = _inferCurrency(text);
    final type = _inferType(text);
    final paymentMode = _inferPaymentMode(text);
    final merchant = _inferMerchantIndia(input.subject, text, input.fromHeader);
    final dt = _inferDateTimeIndia(text, input.dateHeader);
    final inferredCategory = _inferCategoryIndia(text);
    final confidence = _scoreConfidence(
      hasMerchant: merchant != null,
      hasDateFromHeader: input.dateHeader != null,
      textLength: text.length,
    );

    final raw = text.length > 4000 ? text.substring(0, 4000) : text;

    return TransactionRecord(
      transactionId: 'gmail_${input.messageId}',
      dateTime: dt,
      merchant: merchant,
      amount: amount,
      currency: currency,
      type: type,
      paymentMode: paymentMode,
      inferredCategory: inferredCategory,
      source: 'gmail',
      rawText: raw,
      parsedAt: DateTime.now().toUtc(),
      confidenceScore: confidence,
      gmailMessageId: input.messageId,
      needsReview: confidence < 0.62 ? 1 : 0,
    );
  }

  static String _inferCurrency(String text) {
    if (RegExp(r'INR|Rs\.?|₹|Rupee', caseSensitive: false).hasMatch(text)) {
      return 'INR';
    }
    if (RegExp(r'USD|\$', caseSensitive: false).hasMatch(text)) return 'USD';
    return 'INR';
  }

  static String _inferType(String text) {
    final t = text.toLowerCase();
    // Hindi tokens sometimes seen in SMS/email forwards
    if (t.contains('credited') ||
        t.contains('received') ||
        t.contains('जमा') ||
        t.contains('deposit')) {
      return 'credit';
    }
    if (t.contains('refund')) return 'refund';
    if (t.contains('fee') ||
        t.contains('charges') ||
        t.contains('मासिक शुल्क')) {
      return 'fee';
    }
    if (t.contains('invest') ||
        t.contains('sip') ||
        t.contains('mutual fund') ||
        t.contains('demat')) {
      return 'investment';
    }
    return 'debit';
  }

  static String _inferPaymentMode(String text) {
    if (_upi.hasMatch(text)) return 'upi';
    if (_card.hasMatch(text)) return 'card';
    if (_bankTransfer.hasMatch(text)) return 'bank_transfer';
    final tl = text.toLowerCase();
    if (tl.contains('wallet') ||
        tl.contains('paytm wallet') ||
        tl.contains('phonepe wallet')) {
      return 'wallet';
    }
    return 'other';
  }

  static String? _inferMerchantIndia(
    String subject,
    String text,
    String? fromHeader,
  ) {
    // UPI: paid to NAME or to VPA
    final paidTo = RegExp(
      r"(?:paid to|payment to|credited to|debited for|to)\s+([A-Za-z0-9\u0900-\u097F][A-Za-z0-9\u0900-\u097F .,&\-/]{2,79})",
      caseSensitive: false,
    ).firstMatch(text);
    if (paidTo != null) {
      final name = paidTo.group(1)!.trim();
      if (!_isNoiseMerchant(name)) return name;
    }

    final at = RegExp(
      r'at\s+([A-Za-z0-9\u0900-\u097F][A-Za-z0-9\u0900-\u097F &\-\.]{2,59})',
      caseSensitive: false,
    ).firstMatch(text);
    if (at != null && !_isNoiseMerchant(at.group(1)!)) {
      return at.group(1)!.trim();
    }

    // Bank email: sometimes merchant in subject after colon
    var sub = subject.trim();
    if (sub.length > 3 && sub.length < 100) {
      sub = sub.replaceAll(
        RegExp(
          r'^(alert|transaction|payment|e-?mail|sms)\s*[:\-]\s*',
          caseSensitive: true,
        ),
        '',
      );
      if (sub.length > 3 && !_isNoiseMerchant(sub)) return sub;
    }

    // From: "MERCHANT <noreply@...>" — light heuristic
    if (fromHeader != null) {
      final fm = RegExp(r'^([^<]+)<').firstMatch(fromHeader);
      if (fm != null) {
        final n = fm.group(1)!.trim();
        if (n.length > 2 &&
            n.length < 60 &&
            !RegExp(r'bank|alert|noreply|notification', caseSensitive: false)
                .hasMatch(n)) {
          return n;
        }
      }
    }

    return null;
  }

  static bool _isNoiseMerchant(String s) {
    final t = s.toLowerCase();
    return t.contains('a/c') ||
        t.contains('account') ||
        t.contains('xx') ||
        t.contains('xxx') ||
        t.contains('upi') ||
        t.contains('ref no') ||
        t.length < 3;
  }

  static DateTime _inferDateTimeIndia(String text, String? dateHeader) {
    if (dateHeader != null) {
      try {
        return DateTime.parse(dateHeader).toUtc();
      } catch (_) {}
    }

    final iso = RegExp(r'20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')
        .firstMatch(text);
    if (iso != null) {
      try {
        return DateTime.parse(iso.group(0)!).toUtc();
      } catch (_) {}
    }

    // DD-MMM-YYYY / DD/MM/YYYY (India-first)
    for (final pattern in [
      'dd-MMM-yyyy',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'dd.MM.yyyy',
    ]) {
      final re = _dateRegexForPattern(pattern);
      final m = re.firstMatch(text);
      if (m != null) {
        final parsed = _tryParseDateToken(m.group(0)!, pattern);
        if (parsed != null) return parsed.toUtc();
      }
    }

    final slash = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](20\d{2})\b')
        .firstMatch(text);
    if (slash != null) {
      final a = int.tryParse(slash.group(1)!);
      final b = int.tryParse(slash.group(2)!);
      final y = int.tryParse(slash.group(3)!);
      if (a != null && b != null && y != null) {
        try {
          if (a > 12) {
            return DateTime.utc(y, b, a);
          }
          if (b > 12) {
            return DateTime.utc(y, a, b);
          }
          // Ambiguous: assume **DMY** (India)
          return DateTime.utc(y, b, a);
        } catch (_) {}
      }
    }

    return DateTime.now().toUtc();
  }

  static RegExp _dateRegexForPattern(String pattern) {
    switch (pattern) {
      case 'dd-MMM-yyyy':
        return RegExp(
          r'\b(\d{1,2})[\s\-/](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s\-/](20\d{2})\b',
          caseSensitive: false,
        );
      case 'dd/MM/yyyy':
        return RegExp(r'\b(\d{1,2})/(\d{1,2})/(20\d{2})\b');
      case 'dd-MM-yyyy':
        return RegExp(r'\b(\d{1,2})-(\d{1,2})-(20\d{2})\b');
      case 'dd.MM.yyyy':
        return RegExp(r'\b(\d{1,2})\.(\d{1,2})\.(20\d{2})\b');
      default:
        return RegExp('');
    }
  }

  static DateTime? _tryParseDateToken(String token, String pattern) {
    try {
      if (pattern == 'dd-MMM-yyyy') {
        final norm = token.replaceAll('/', '-');
        return DateFormat('dd-MMM-yyyy', 'en_IN').parse(norm);
      }
      return DateFormat(pattern, 'en_IN').parse(token);
    } catch (_) {
      return null;
    }
  }

  static String? _inferCategoryIndia(String text) {
    final t = text.toLowerCase();
    if (t.contains('swiggy') ||
        t.contains('zomato') ||
        t.contains('blinkit') ||
        t.contains('food')) {
      return 'food';
    }
    if (t.contains('bigbasket') ||
        t.contains('grofers') ||
        t.contains('jiomart') ||
        t.contains('dunzo')) {
      return 'groceries';
    }
    if (t.contains('irctc') ||
        t.contains('uber') ||
        t.contains('ola') ||
        t.contains('rapido') ||
        t.contains('fuel') ||
        t.contains('petrol') ||
        t.contains('indian oil') ||
        t.contains('hpcl') ||
        t.contains('bharat petroleum')) {
      return 'transport';
    }
    if (t.contains('amazon.in') ||
        t.contains('amazon pay') ||
        t.contains('flipkart') ||
        t.contains('myntra') ||
        t.contains('nykaa') ||
        t.contains('meesho')) {
      return 'shopping';
    }
    if (t.contains('recharge') ||
        t.contains('jio') ||
        t.contains('airtel') ||
        t.contains('vi ') ||
        t.contains('bsnl') ||
        t.contains('electricity') ||
        t.contains('bescom') ||
        t.contains('mseb')) {
      return 'bills';
    }
    if (t.contains('bookmyshow') ||
        t.contains('hotstar') ||
        t.contains('netflix') ||
        t.contains('spotify') ||
        t.contains('sonyliv')) {
      return 'entertainment';
    }
    if (t.contains('pharmacy') ||
        t.contains('apollo') ||
        t.contains('1mg') ||
        t.contains('practo')) {
      return 'health';
    }
    if (t.contains('cred') ||
        t.contains('groww') ||
        t.contains('zerodha') ||
        t.contains('kuvera')) {
      return 'investment';
    }
    return null;
  }

  static double _scoreConfidence({
    required bool hasMerchant,
    required bool hasDateFromHeader,
    required int textLength,
  }) {
    double s = 0.48;
    if (hasMerchant) s += 0.12;
    if (hasDateFromHeader) s += 0.15;
    s += min(0.2, textLength / 5000.0);
    return min(0.95, s);
  }

  /// Gmail query tuned for **Indian** bank / UPI / wallet senders + txn subjects.
  static String transactionSearchQuery({required int newerThanDays}) {
    final days = newerThanDays.clamp(1, 3650);
    // OR of from: tokens (substring match on From address / name)
    const bankSenders = [
      'hdfcbank',
      'icicibank',
      'icici',
      'axisbank',
      'kotak',
      'yesbank',
      'idfcfirstbank',
      'idfcbank',
      'sbicard',
      'sbi.co.in',
      'pnb',
      'unionbank',
      'canarabank',
      'bankofbaroda',
      'indusind',
      'federalbank',
      'rblbank',
      'paytm',
      'phonepe',
      'google.com',
      'amazon.in',
      'razorpay',
      'cashfree',
    ];
    final fromClause = bankSenders.map((s) => 'from:$s').join(' OR ');
    return '('
        'subject:(UPI OR IMPS OR NEFT OR RTGS OR debited OR credited OR txn OR transaction OR spent OR paid OR alert OR "has been debited" OR "has been credited") '
        'OR ($fromClause)'
        ') newer_than:${days}d';
  }
}
