import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/l10n/app_localizations.dart';
import 'package:where_money/l10n/app_localizations_en.dart';
import 'package:where_money/l10n/app_localizations_zh.dart';
import 'package:where_money/on_screen.dart';
import 'package:where_money_core/where_money_core.dart';

/// Upper case in this app is typography, and typography is the language's
/// business. `cased` decides it once; this file is what stops the decision
/// being made again at a call site.
///
/// It went wrong the obvious way. `toUpperCase()` on a Chinese label reads as
/// a no-op, and the comments beside four call sites said so, until "锁定 Where
/// Money" was drawn on a phone as "锁定 WHERE MONEY" — the characters left
/// alone and the app's own name shouted, beside three marks that read as
/// written.
void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();

  test('a language with an upper case gets one', () {
    expect(cased(en, 'Home Currency'), 'HOME CURRENCY');
    expect(cased(en, 'Lock Where Money'), 'LOCK WHERE MONEY');
  });

  test('a language without one is drawn as it is written', () {
    expect(cased(zh, '主货币'), '主货币');
    expect(
      cased(zh, '锁定 Where Money'),
      '锁定 Where Money',
      reason: 'the Latin the label carries is not the place to start shouting',
    );
  });

  test('every language the app can be read in has an answer', () {
    for (final language in languages) {
      final words = lookupAppLocalizations(Locale(language));

      expect(
        cased(words, 'Sign out'),
        anyOf('Sign out', 'SIGN OUT'),
        reason:
            '$language is cased into something that is neither the words as '
            'written nor the words upper — which means the set of languages '
            'without a letter case has stopped matching the set of languages',
      );
    }
  });

  // The class of bug rather than the label that caught it. A new mark drawn
  // with `toUpperCase()` beside it is a Chinese screen with one word shouting
  // on it, and nothing else in the suite would say so.
  test('nothing outside on_screen.dart cases a mark itself', () {
    const allowed = {
      // Where `cased` lives and is the only legitimate caller.
      'lib/on_screen.dart',
      // A currency code is upper case in every language, on the receipt and in
      // the ISO list. Normalising what was typed is data, not typography.
      'lib/choosing_a_currency.dart',
      'lib/review/review_bloc.dart',
      // Initials off a name. Upper in every language that has a case and
      // untouched in the ones that do not, which is the same argument: the
      // letter is data, not typography. The file holds nothing else, so the
      // screen that draws the initials stays covered.
      'lib/settings/initials.dart',
    };

    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains('toUpperCase()'))
        .map((file) => file.path.replaceAll(r'\', '/'))
        .where((path) => !allowed.contains(path))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'these case text themselves; call cased(words, text) instead',
    );
  });
}
