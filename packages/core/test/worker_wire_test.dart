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

  test('and the Check finds nothing to flag in it', () {
    final extraction = (parseExtraction(recorded) as ExtractionRead).extraction;

    expect(Check.of(extraction, now: fixtureNow).findings, isEmpty);
  });
}
