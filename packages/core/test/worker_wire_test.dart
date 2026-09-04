// The Worker returns the model's response untouched and the app parses it here,
// so the two halves have to agree about one wire shape. Both read the same
// recorded file: worker/test/extract.test.ts asserts the Worker hands it back
// byte for byte, and this asserts the parser turns it into the Extraction the
// receipt actually describes. Neither can drift alone.
//
// Paths are relative to the package root, which is where `dart test` runs.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  final recorded =
      jsonDecode(
            File(
              '../../worker/test/fixtures/model-response.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('the response the Worker returns reads as the receipt it came from', () {
    final outcome = parseExtraction(recorded);

    expect(outcome, isA<ExtractionRead>());
    final extraction = (outcome as ExtractionRead).extraction;
    expect(extraction.merchant, 'Village Grocer Bangsar');
    expect(extraction.total, 44.10);
    expect(extraction.currency, 'MYR');
    expect(extraction.purchasedAt, '2026-08-21');
    expect(extraction.lineItems, hasLength(4));
    expect(outcome.servedByModel, startsWith('gpt-5-nano'));
    expect(outcome.usage.reasoningTokens, 640);
  });

  // The schema pins currency to the ISO codes and one member that is not a
  // code: the empty string, which is what the Model returns for a symbol that
  // means more than one currency. Those two are the whole of what the Worker
  // can now send, so the parser has to make an Extraction of the empty one
  // rather than refuse it, and the Check has to be the thing that speaks up.
  test('a receipt the Model would not name a currency for still reads', () {
    final outcome = parseExtraction(withCurrency(recorded, ''));

    expect(outcome, isA<ExtractionRead>());
    final extraction = (outcome as ExtractionRead).extraction;
    expect(extraction.currency, isEmpty);
    expect(extraction.total, 44.10, reason: 'the rest of the receipt survives');
    expect(
      Check.of(extraction, now: fixtureNow).findings,
      contains(isA<NoCurrency>()),
    );
  });

  test('and the Check finds nothing to flag in it', () {
    final extraction = (parseExtraction(recorded) as ExtractionRead).extraction;

    expect(Check.of(extraction, now: fixtureNow).findings, isEmpty);
  });
}

/// [recorded] with the receipt's currency read as [read] instead. The
/// recording stays the one wire shape both halves agree on; this only swaps
/// the one field whose set of legal values is what changed.
Map<String, dynamic> withCurrency(Map<String, dynamic> recorded, String read) {
  final response = jsonDecode(jsonEncode(recorded)) as Map<String, dynamic>;
  final message = (response['output'] as List).firstWhere(
    (item) => (item as Map<String, dynamic>)['type'] == 'message',
  );
  final content =
      ((message as Map<String, dynamic>)['content'] as List).first
          as Map<String, dynamic>;
  final receipt = jsonDecode(content['text'] as String) as Map<String, dynamic>;

  receipt['currency'] = read;
  content['text'] = jsonEncode(receipt);
  return response;
}
