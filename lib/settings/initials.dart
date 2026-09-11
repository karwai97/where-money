/// What the disc over the two buttons on Settings holds when there is an
/// account behind the Ledger.
///
/// Its own file for one reason: it upper-cases, and
/// `a_mark_is_cased_by_its_language_test.dart` allows that a file at a time.
/// An initial is a letter off a name rather than a mark the design shouts —
/// upper in every language that has a case, and untouched in the ones that do
/// not — so it is data like a normalised currency code, and it does not go
/// through `cased`. Keeping it out of `settings_screen.dart` leaves that
/// screen still covered by the guard.
library;

import 'package:characters/characters.dart';

/// The two letters in the disc beside the name: the first letter of the first
/// and the last of the whitespace-separated words, upper-cased. A one-word
/// name gives one letter, and a name that is only whitespace is no name.
///
/// With no name, the address's first letter. Google can return an account
/// with no display name, and a made-up one would be worse than an initial off
/// the address the line beside it already shows.
///
/// Counted in grapheme clusters rather than code units, so a Chinese name
/// gives its first character instead of half of one.
String initialsOf({required String? name, required String? email}) {
  final words = (name ?? '')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);

  if (words.isEmpty) {
    return (email ?? '').characters.take(1).toString().toUpperCase();
  }

  final first = words.first.characters.first;
  final last = words.length == 1 ? '' : words.last.characters.first;
  return '$first$last'.toUpperCase();
}
