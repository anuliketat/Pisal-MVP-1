/// Email slice passed into the parse pipeline (rules + optional remote).
class RuleParseInput {
  const RuleParseInput({
    required this.messageId,
    required this.subject,
    required this.snippet,
    this.fromHeader,
    this.dateHeader,
  });

  final String messageId;
  final String subject;
  final String snippet;
  final String? fromHeader;
  final String? dateHeader;
}
