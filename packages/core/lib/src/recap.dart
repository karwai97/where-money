/// The Recap: a month's spending said in words, generated from a Rollup rather
/// than from the Ledger.
///
/// Two things live here. [rollupPrompt] is everything that is ever sent — the
/// Rollup and nothing under it, so a user with 500 receipts sends the same
/// prompt as one with 18. [rollupHash] is what the Recap is cached against: a
/// Recap is a pure function of a Rollup, so an unchanged hash is an unchanged
/// Recap, and staleness stops being something to remember.
library;

import 'dart:convert';

import 'model_response.dart';
import 'rollup.dart';

/// Below this, no Recap is asked for. Three receipts have no shape to find and
/// asking anyway is asking to be told something invented.
const int minimumExpensesForRecap = 5;

/// What the Model is given. Numbers and slugs only — the month is a year and a
/// month rather than a formatted label, and a Category is its slug. The Model
/// is the thing best placed to name a month or a Category in the language it is
/// writing in, and nothing English is left on this path for it to copy
/// (ADR-0007). The Worker's instructions describe this shape.
Map<String, dynamic> rollupPrompt(Rollup rollup) {
  final heaviest = rollup.heaviestDay;

  return {
    'year': rollup.year,
    'month': rollup.month,
    'currency': rollup.homeCurrency,
    'total': _money(rollup.total),
    'previous_year': rollup.previousYear,
    'previous_month': rollup.previousMonth,
    'previous_total': _money(rollup.previousTotal),
    'expenses': rollup.expenseCount,
    'daily_average': _money(rollup.dailyAverage),
    'by_category': [
      for (final category in rollup.byCategory)
        {
          'category': category.category,
          'amount': _money(category.amount),
          'previous': _money(category.previousAmount),
          'count': category.count,
        },
    ],
    'largest': [
      for (final expense in rollup.largest)
        {
          'merchant': expense.merchant,
          'amount': _money(expense.total),
          'category': expense.category,
          'day': expense.date.day,
        },
    ],
    if (heaviest != null)
      'heaviest_day': {'day': heaviest.day, 'amount': _money(heaviest.amount)},
    'excluded': {
      'count': rollup.excludedCount,
      'currencies': rollup.excludedCurrencies.toList()..sort(),
    },
  };
}

/// A hash of exactly what would be sent. Anything the prompt does not carry
/// cannot change the Recap, so it has no business changing the hash either.
///
/// The Language is the one exception, and it is not one yet: the Worker is told
/// which language to write in out of band, so a Recap is a function of this
/// hash *and* that. Nothing changes the language while the app is running, so
/// no cached Recap can be served in the wrong one — the ticket that lets a user
/// change it is the ticket that has to bring the Language in here.
String rollupHash(Rollup rollup) {
  final text = jsonEncode(rollupPrompt(rollup));

  // FNV-1a, 64-bit, because this package has no dependencies and a cache key
  // is not a security claim. Same input, same key, on every device.
  var hash = BigInt.parse('14695981039346656037');
  final prime = BigInt.parse('1099511628211');
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final byte in utf8.encode(text)) {
    hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

sealed class RecapOutcome {
  final Usage usage;
  final String servedByModel;

  const RecapOutcome({required this.usage, required this.servedByModel});
}

final class RecapWritten extends RecapOutcome {
  final String text;

  const RecapWritten({
    required this.text,
    required super.usage,
    required super.servedByModel,
  });
}

/// A 200 that declined, checked for before any text in the same message is
/// trusted.
final class RecapRefused extends RecapOutcome {
  final String message;

  const RecapRefused({
    required this.message,
    required super.usage,
    required super.servedByModel,
  });
}

/// The call succeeded and said nothing worth printing — usually reasoning ate
/// the whole output budget.
final class RecapNoOutput extends RecapOutcome {
  final String status;
  final String? reason;

  const RecapNoOutput({
    required this.status,
    required this.reason,
    required super.usage,
    required super.servedByModel,
  });
}

/// Prose, not JSON: there is no schema to hold the Model to, so the traps are
/// the same ones extraction has except for the parse — a refusal at 200, and
/// reasoning items ahead of the message.
RecapOutcome parseRecap(Map<String, dynamic> body) {
  final message = readMessage(body);

  if (message.refusal != null) {
    return RecapRefused(
      message: message.refusal!,
      usage: message.usage,
      servedByModel: message.servedByModel,
    );
  }

  final text = message.texts.join('\n').trim();
  if (text.isEmpty) {
    return RecapNoOutput(
      status: message.status,
      reason: message.incompleteReason,
      usage: message.usage,
      servedByModel: message.servedByModel,
    );
  }

  return RecapWritten(
    text: text,
    usage: message.usage,
    servedByModel: message.servedByModel,
  );
}

/// Two decimals, so a float's last bits cannot make two identical months hash
/// differently.
double _money(double amount) => double.parse(amount.toStringAsFixed(2));
