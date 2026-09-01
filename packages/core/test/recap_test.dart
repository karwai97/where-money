import 'dart:convert';

import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  final august = DateTime(2026, 8, 23);
  final ledger = seedLedger(around: august);

  Rollup august2026(List<Expense> of) =>
      Rollup.forMonth(of, year: 2026, month: 8, homeCurrency: 'MYR');

  group('the Rollup as a prompt', () {
    test('carries the month as numbers, its total and the month before it', () {
      final prompt = rollupPrompt(august2026(ledger));

      expect(prompt['year'], 2026);
      expect(prompt['month'], 8);
      expect(prompt['currency'], 'MYR');
      expect(prompt['total'], closeTo(1806.75, 0.01));
      expect(prompt['previous_year'], 2026);
      expect(prompt['previous_month'], 7);
      expect(prompt['previous_total'], greaterThan(0));
    });

    test('sends Categories as slugs, leaving the naming to whoever writes', () {
      final prompt = rollupPrompt(august2026(ledger));
      final named = [
        ...(prompt['by_category'] as List).map((c) => (c as Map)['category']),
        ...(prompt['largest'] as List).map((e) => (e as Map)['category']),
      ];

      expect(named, contains('dining'));
      expect(named, isNot(contains('Dining out')));
      for (final category in named) {
        expect(categories, contains(category));
      }
    });

    test('spells out no month for a translator to work around', () {
      final text = jsonEncode(rollupPrompt(august2026(ledger)));

      for (final month in const ['Jan', 'Aug', 'Sep', 'Dec']) {
        expect(text, isNot(contains(month)));
      }
    });

    test('points at the biggest purchases and the heaviest day', () {
      final prompt = rollupPrompt(august2026(ledger));
      final largest = (prompt['largest'] as List).first as Map;

      expect(largest['merchant'], 'Ikea Damansara');
      expect(largest['amount'], closeTo(289.90, 0.01));
      expect((prompt['heaviest_day'] as Map)['day'], isA<int>());
    });

    test('says how much was left out for being in another currency', () {
      final prompt = rollupPrompt(august2026(ledger));

      expect((prompt['excluded'] as Map)['count'], 1);
      expect((prompt['excluded'] as Map)['currencies'], ['USD']);
    });

    test('sends no Expense the Rollup does not already single out', () {
      final sent = jsonEncode(rollupPrompt(august2026(ledger)));

      expect(sent, isNot(contains('Guardian Pharmacy')));
      expect(sent, isNot(contains('line_items')));
      expect(sent.length, lessThan(2000));
    });

    test('stays about the same size however long the Ledger is', () {
      final one = jsonEncode(rollupPrompt(august2026(ledger))).length;
      final many = jsonEncode(
        rollupPrompt(august2026([...ledger, ...ledger, ...ledger])),
      ).length;

      expect(many, lessThan(one + 200));
    });
  });

  group('the hash a Recap is cached against', () {
    test('is the same for a month nobody has touched', () {
      expect(rollupHash(august2026(ledger)), rollupHash(august2026(ledger)));
    });

    test('changes when an Expense is added', () {
      final before = rollupHash(august2026(ledger));
      final after = rollupHash(
        august2026([
          ...ledger,
          Expense(
            id: 'new',
            merchant: 'Family Mart',
            date: DateTime(2026, 8, 24),
            currency: 'MYR',
            total: 12.30,
            category: 'groceries',
            lineItems: const [],
            source: ExpenseSource.manual,
            needsReview: false,
          ),
        ]),
      );

      expect(after, isNot(before));
    });

    test('changes when an Expense is corrected', () {
      final corrected = [
        for (final e in ledger)
          if (e.merchant == 'Ikea Damansara')
            Expense(
              id: e.id,
              merchant: e.merchant,
              date: e.date,
              currency: e.currency,
              total: 389.90,
              category: e.category,
              lineItems: e.lineItems,
              source: e.source,
              needsReview: e.needsReview,
            )
          else
            e,
      ];

      expect(
        rollupHash(august2026(corrected)),
        isNot(rollupHash(august2026(ledger))),
      );
    });

    test('changes when an Expense is deleted', () {
      final without = ledger.where((e) => e.merchant != 'Netflix').toList();

      expect(
        rollupHash(august2026(without)),
        isNot(rollupHash(august2026(ledger))),
      );
    });

    test('tells two months apart', () {
      final july = Rollup.forMonth(
        ledger,
        year: 2026,
        month: 7,
        homeCurrency: 'MYR',
      );

      expect(rollupHash(july), isNot(rollupHash(august2026(ledger))));
    });
  });

  group('reading what the Model wrote', () {
    Map<String, dynamic> response(
      List<Object> output, {
      String status = 'completed',
    }) => {
      'model': 'gpt-5-nano-2025-08-07',
      'status': status,
      'output': output,
      'usage': {'input_tokens': 400, 'output_tokens': 120},
    };

    Map<String, Object> message(List<Object> content) => {
      'type': 'message',
      'content': content,
    };

    test('walks past the reasoning to the prose', () {
      final outcome = parseRecap(
        response([
          {'type': 'reasoning', 'summary': []},
          message([
            {'type': 'output_text', 'text': 'Groceries took the most.'},
          ]),
        ]),
      );

      expect(outcome, isA<RecapWritten>());
      expect((outcome as RecapWritten).text, 'Groceries took the most.');
      expect(outcome.usage.outputTokens, 120);
    });

    test('a refusal is not prose', () {
      final outcome = parseRecap(
        response([
          message([
            {'type': 'refusal', 'refusal': 'I cannot help with that.'},
          ]),
        ]),
      );

      expect(outcome, isA<RecapRefused>());
    });

    test('reasoning eating the whole budget leaves nothing to read', () {
      final outcome = parseRecap(
        response([
          {'type': 'reasoning', 'summary': []},
        ], status: 'incomplete'),
      );

      expect(outcome, isA<RecapNoOutput>());
    });

    test('whitespace is nothing to read either', () {
      final outcome = parseRecap(
        response([
          message([
            {'type': 'output_text', 'text': '   \n '},
          ]),
        ]),
      );

      expect(outcome, isA<RecapNoOutput>());
    });
  });
}
