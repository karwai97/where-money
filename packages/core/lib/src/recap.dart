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
          // Omitted rather than named: the Model is writing in the user's
          // language and has no use for this app's word for an absence.
          if (expense.merchant != null) 'merchant': expense.merchant,
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

/// A hash of everything the answer depends on. Anything that cannot change the
/// Recap has no business changing the hash either.
///
/// That is the Rollup and the [language]. The prompt carries slugs and numbers
/// and never a label (ADR-0007), so the Language does not appear in it — the
/// Worker is told out of band which language to write in, and the same numbers
/// come back as two different Recaps. So it is hashed alongside the prompt
/// rather than read out of it, and a user switching language misses the cache,
/// pays for one Recap, and switching back is free because the first one is
/// still held under its own key.
///
/// An unrecognised code hashes as itself rather than as [defaultLanguage],
/// which the Worker will answer in. Two keys for one answer costs one Recap
/// nobody asked for; one key for two answers would serve a Recap in the wrong
/// language, and that is the failure worth avoiding.
String rollupHash(Rollup rollup, {required String language}) {
  final text = '$language ${jsonEncode(rollupPrompt(rollup))}';

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
