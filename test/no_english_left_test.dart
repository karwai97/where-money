import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The sixth of the structural tests, and the one that keeps nine tickets of
/// translation from unwinding. `no_words_in_the_domain_test.dart` polices the
/// bottom of ADR-0007 — the domain holds slugs, not labels. This polices the
/// top: the app holds the words, and it holds them in the ARB files rather
/// than in a widget.
///
/// It has to say how it tells a sentence a user reads from a sentence a user
/// never sees, because a list of exceptions is a list nobody maintains. The
/// rule is two clauses and each one is a shape in the source:
///
/// 1. **It reads as prose.** Two or more words of two letters or more, once
///    interpolation and escapes are dropped. A key, a slug, a model id, a MIME
///    type, an HTTP header name and a currency code are one word or none.
/// 2. **It is not one of the three things the app writes for itself.** A
///    thrown message, a widget key, or the detail on a failure. Each is
///    recognisable where it is written, and none of the three can reach a
///    screen.
///
/// What it cannot see, said out loud so nobody trusts it further than it goes:
///
/// - **One word.** `Text('Unlock')` reads as an identifier to clause one and
///   goes through. Every message on every screen today is a phrase, and the
///   alternative — flagging any capitalised word — flags `'Bearer'`, every
///   MIME type and every model id, which is the maintained list this test
///   exists to avoid.
/// - **A word that reaches a screen from somewhere else.** A literal stored,
///   sent, or handed to a bloc and rendered later is prose here and a value
///   there. `no_words_in_the_domain_test.dart` covers the domain half of that
///   and `'Unknown merchant'` was the last of it.
/// - **Whether the ARB files say anything sensible.** That is
///   `every_language_says_everything_test.dart` and a pair of eyes.
void main() {
  test('no screen says anything in English of its own', () {
    final offenders = <String>[];
    final sources = {
      for (final file in _sources())
        file: _withoutCommentsAndDirectives(file.readAsStringSync()),
    };
    final failures = _answerTaxonomyIn(sources.values);

    for (final file in sources.keys) {
      final source = sources[file]!;

      for (final found in _stringLiterals(source)) {
        if (!_readsAsProse(found.literal)) continue;
        if (_theAppWroteItForItself(source, found.at, failures)) continue;
        offenders.add('${file.path}: "${found.literal}"');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these are sentences a user would read, written in the app rather '
          'than in lib/l10n. A screen with a string of its own is a screen '
          'that stays English in every other language; see ADR-0007 and '
          'lib/l10n/README.md.',
    );
  });
}

/// The message files are where the words are supposed to be, and
/// `app_localizations*.dart` is generated from them by every build.
Iterable<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where((file) => !file.path.replaceAll(r'\', '/').contains('lib/l10n/'));

/// Clause one. Whitespace is what separates words: `personal_care`,
/// `image/png`, `content-type` and `https://…` are single tokens however many
/// letter runs they contain, and `'Bearer $token'` reads as `Bearer` once the
/// token is dropped.
bool _readsAsProse(String literal) {
  final text = literal
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '')
      .replaceAll(RegExp(r'\\.', dotAll: true), '');

  return RegExp(r'[A-Za-z]{2,}\s+[A-Za-z]{2,}').hasMatch(text);
}

/// Clause two. Three shapes, in the order they cost to check:
///
/// - **A widget key.** `ValueKey('category bar: …')` is how a test finds a bar
///   whose only other content is its length. Never drawn.
/// - **A thrown message.** An exception in this app is a bug report. Nothing
///   catches one to print it — a failure the user is meant to see is a member
///   of a taxonomy, not an exception.
/// - **The detail on a failure.** Every member of the answer taxonomy carries
///   a line saying what went wrong underneath, and none of it reaches a
///   screen: `_failed` in `inbox_bloc.dart` keeps the `ScanFailure` member and
///   drops the detail, and the Inbox and the Rollup word the failure
///   themselves out of the ARB files.
bool _theAppWroteItForItself(String source, int at, Set<String> failures) {
  final before = source.substring(0, at).trimRight();

  if (before.endsWith('Key(')) return true;
  if (failures.any((failure) => before.endsWith('$failure('))) return true;

  return _isThrown(source, at);
}

/// Whether the literal is still inside the argument list a `throw` opened.
/// Being anywhere after a `throw` is not enough: `expenseFromDocument` throws
/// from the middle of one long `return Expense(…)`, and half its fields are
/// written after that point.
bool _isThrown(String source, int at) {
  final thrown = source.substring(0, at).lastIndexOf('throw ');
  if (thrown == -1) return false;

  var depth = 0;
  var i = thrown + 'throw '.length;
  while (i < at) {
    switch (source[i]) {
      case '(':
        depth++;
      case ')':
        depth--;
      case ';':
        return false;
      case "'" || '"':
        i = _afterLiteral(source, i);
        continue;
    }
    if (depth < 0) return false;
    i++;
  }

  // `throw '…'` is a thrown string rather than a thrown exception; nothing
  // here does it, and it costs one comparison to keep honest.
  return depth > 0 || source.substring(thrown, at).trim() == 'throw';
}

/// The members of the taxonomy are read out of the source rather than listed,
/// so a new failure is covered the day it is declared and a renamed one stops
/// being exempt the day it is renamed.
Set<String> _answerTaxonomyIn(Iterable<String> sources) => {
  for (final source in sources)
    for (final match in RegExp(
      r'class\s+(\w+)\s+(?:extends|implements)\s+'
      r'(?:ModelFailure|ScanAnswer|RecapAnswer)\b',
    ).allMatches(source))
      match.group(1)!,
};

/// Blanked rather than removed, so that a literal's offset in the result is
/// still its offset in the file and the clause-two shapes can be read from the
/// text in front of it.
String _withoutCommentsAndDirectives(String source) {
  final text = source
      .split('\n')
      .map(
        (line) =>
            RegExp(r'^\s*(import|export|part)\b').hasMatch(line) ? '' : line,
      )
      .join('\n');
  final src = text.split('');

  var i = 0;
  void blank(int until) {
    for (; i < until && i < src.length; i++) {
      if (src[i] != '\n') src[i] = ' ';
    }
  }

  while (i < src.length) {
    if (text.startsWith('//', i)) {
      final end = text.indexOf('\n', i);
      blank(end == -1 ? src.length : end);
    } else if (text.startsWith('/*', i)) {
      var depth = 0;
      var j = i;
      while (j < src.length) {
        if (text.startsWith('/*', j)) {
          depth++;
          j += 2;
        } else if (text.startsWith('*/', j)) {
          depth--;
          j += 2;
          if (depth == 0) break;
        } else {
          j++;
        }
      }
      blank(j);
    } else if (src[i] == "'" || src[i] == '"') {
      i = _afterLiteral(text, i);
    } else {
      i++;
    }
  }

  return src.join();
}

class _Found {
  const _Found(this.literal, this.at);

  final String literal;

  /// Where the opening quote is, so the caller can read what precedes it.
  final int at;
}

/// Every string literal in [source], which has already had its comments
/// blanked. The scanner is `no_words_in_the_domain_test.dart`'s — raw strings,
/// triple quotes, escapes and interpolation — copied rather than shared
/// because the domain package takes no dependency on this one.
List<_Found> _stringLiterals(String source) {
  final literals = <_Found>[];
  var i = 0;

  while (i < source.length) {
    final char = source[i];
    if (char != "'" && char != '"') {
      i++;
      continue;
    }

    final raw = i > 0 && source[i - 1] == 'r';
    final quote = source.startsWith(char * 3, i) ? char * 3 : char;
    final after = _afterLiteral(source, i);

    literals.add(
      _Found(
        source.substring(
          i + quote.length,
          (after - quote.length).clamp(0, after),
        ),
        raw ? i - 1 : i,
      ),
    );
    i = after;
  }

  return literals;
}

/// The index just past the literal's closing quote, given the index of its
/// opening one. Clamped to the end of the file so an unterminated literal
/// cannot spin.
int _afterLiteral(String source, int start) {
  final char = source[start];
  final raw = start > 0 && source[start - 1] == 'r';
  final quote = source.startsWith(char * 3, start) ? char * 3 : char;

  var i = start + quote.length;
  while (i < source.length) {
    if (!raw && source[i] == r'\') {
      i += 2;
      continue;
    }
    if (source.startsWith(quote, i)) return i + quote.length;
    i++;
  }
  return source.length;
}
