import 'dart:convert';

import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

Map<String, dynamic> reasoningItem() => {
  'type': 'reasoning',
  'id': 'rs_1',
  'summary': const [],
};

Map<String, dynamic> messageItem(List<Map<String, dynamic>> content) => {
  'type': 'message',
  'id': 'msg_1',
  'role': 'assistant',
  'content': content,
};

Map<String, dynamic> body({
  required List<Map<String, dynamic>> output,
  String status = 'completed',
  Map<String, dynamic>? incompleteDetails,
}) => {
  'id': 'resp_1',
  'model': 'gpt-5-nano',
  'status': status,
  'incomplete_details': ?incompleteDetails,
  'output': output,
  'usage': {
    'input_tokens': 3800,
    'input_tokens_details': {'cached_tokens': 1024},
    'output_tokens': 900,
    'output_tokens_details': {'reasoning_tokens': 640},
  },
};

Map<String, dynamic> textBlock(String text) => {
  'type': 'output_text',
  'text': text,
};

final cleanJson = jsonEncode(cleanExtraction.toJson());

void main() {
  test('the receipt is found behind the reasoning that precedes it', () {
    final outcome = parseExtraction(
      body(
        output: [
          reasoningItem(),
          reasoningItem(),
          messageItem([textBlock(cleanJson)]),
        ],
      ),
    );

    expect(outcome, isA<ExtractionRead>());
    final extraction = (outcome as ExtractionRead).extraction;
    expect(extraction.merchant, cleanExtraction.merchant);
    expect(extraction.total, cleanExtraction.total);
    expect(extraction.lineItems, hasLength(cleanExtraction.lineItems.length));
  });

  test('a refusal is a refusal even though the call succeeded', () {
    final outcome = parseExtraction(
      body(
        output: [
          reasoningItem(),
          messageItem([
            {'type': 'refusal', 'refusal': 'I cannot read identity cards.'},
          ]),
        ],
      ),
    );

    expect(outcome, isA<ExtractionRefused>());
    expect(
      (outcome as ExtractionRefused).message,
      'I cannot read identity cards.',
    );
  });

  test('a refusal is not overtaken by text sitting beside it', () {
    final outcome = parseExtraction(
      body(
        output: [
          messageItem([
            {'type': 'refusal', 'refusal': 'No.'},
            textBlock(cleanJson),
          ]),
        ],
      ),
    );

    expect(outcome, isA<ExtractionRefused>());
  });

  test('reasoning that ate the whole budget leaves no text at all', () {
    final outcome = parseExtraction(
      body(
        output: [reasoningItem()],
        status: 'incomplete',
        incompleteDetails: {'reason': 'max_output_tokens'},
      ),
    );

    expect(outcome, isA<ExtractionNoOutput>());
    expect((outcome as ExtractionNoOutput).ranOutOfOutputTokens, isTrue);
    expect(outcome.status, 'incomplete');
  });

  test('an empty output is silence rather than a spent budget', () {
    final outcome = parseExtraction(body(output: const []));

    expect(outcome, isA<ExtractionNoOutput>());
    expect((outcome as ExtractionNoOutput).ranOutOfOutputTokens, isFalse);
  });

  test('JSON cut off mid-write is malformed, not silence', () {
    final outcome = parseExtraction(
      body(
        output: [messageItem([textBlock('{"merchant": "Jaya Gro')])],
        status: 'incomplete',
        incompleteDetails: {'reason': 'max_output_tokens'},
      ),
    );

    expect(outcome, isA<ExtractionMalformed>());
    expect((outcome as ExtractionMalformed).text, startsWith('{"merchant"'));
    expect(outcome.truncated, isTrue);
  });

  test('prose where JSON was promised is malformed', () {
    final outcome = parseExtraction(
      body(output: [messageItem([textBlock('Sure! Here is the receipt.')])]),
    );

    expect(outcome, isA<ExtractionMalformed>());
    expect((outcome as ExtractionMalformed).truncated, isFalse);
  });

  test('what the call cost comes back whatever the outcome was', () {
    final read = parseExtraction(
      body(output: [messageItem([textBlock(cleanJson)])]),
    );
    final refused = parseExtraction(
      body(
        output: [
          messageItem([
            {'type': 'refusal', 'refusal': 'No.'},
          ]),
        ],
      ),
    );

    for (final outcome in [read, refused]) {
      expect(outcome.usage.inputTokens, 3800);
      expect(outcome.usage.outputTokens, 900);
      expect(outcome.usage.reasoningTokens, 640);
      expect(outcome.usage.cachedTokens, 1024);
      expect(outcome.servedByModel, 'gpt-5-nano');
    }
  });

  test('an Extraction round-trips through its own JSON', () {
    final again = Extraction.fromJson(
      jsonDecode(jsonEncode(flawedExtraction.toJson()))
          as Map<String, dynamic>,
    );

    expect(again.toJson(), flawedExtraction.toJson());
  });
}
