import 'dart:io';

import 'package:test/test.dart';

/// The other half of the rule `flutter_free_test.dart` polices. Words live in
/// the app; the domain holds kinds, slugs and numbers (ADR-0007). Reading the
/// source is the only way to make that permanent — a map of slugs to slugs is
/// one careless edit away from being a map of slugs to labels again.
void main() {
  test('the domain package exports no user-facing display strings', () {
    final offenders = <String>[];

    for (final file in _sources()) {
      for (final literal in _stringLiterals(file.readAsStringSync())) {
        if (_isMachineReadable(literal) || _allowed.contains(literal)) continue;
        offenders.add('${file.path}: "$literal"');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these read as words a user would recognise. A Category, a payment '
          'method or a month is a slug here and a label in the app; see '
          'ADR-0007.',
    );
  });
}

/// Sample Ledgers are excluded: a merchant is called what it is called, in
/// every language, and the fixtures are data the app prints verbatim rather
/// than words it chooses.
const _sampleData = 'fixtures.dart';

const _allowed = {
  // Developer-facing. Neither of these ever reaches a screen.
  r'Expected a JSON object, got ${decoded.runtimeType}.',
  r'Knobs(model: $model, effort: $effort, longEdge: $longEdge, ',
  r'dailyCap: $dailyCap)',
  // Currency aliases: what a receipt prints where a code belongs. Machine-
  // readable in the same sense a code is — the app never chose these words,
  // and it does not translate them either.
  r'S$',
  r'HK$',
  r'NT$',
};

Iterable<File> _sources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where((file) => !file.path.endsWith(_sampleData));

/// Slugs, wire keys, model ids, currency codes and anything with no letters in
/// it at all. Interpolation and escapes are dropped first, so `'$total'` and
/// `'\n'` both count as empty.
bool _isMachineReadable(String literal) {
  final text = literal
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '')
      .replaceAll(RegExp(r'\\.', dotAll: true), '');

  return RegExp(r'^[^A-Za-z]*$').hasMatch(text) ||
      RegExp(r'^[a-z][a-z0-9_./-]*$').hasMatch(text) ||
      RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(text);
}

/// Every string literal in [source], comments and directives left out. Written
/// by hand because the alternative is a dependency, and this package does not
/// take dependencies to keep a rule about itself.
List<String> _stringLiterals(String source) {
  final src = source
      .split('\n')
      .where((line) => !RegExp(r'^\s*(import|export|part)\b').hasMatch(line))
      .join('\n');

  final literals = <String>[];
  var i = 0;

  while (i < src.length) {
    final char = src[i];

    if (src.startsWith('//', i)) {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
    } else if (src.startsWith('/*', i)) {
      i += 2;
      var depth = 1;
      while (i < src.length && depth > 0) {
        if (src.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (src.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
    } else if (char == "'" || char == '"') {
      final raw = i > 0 && src[i - 1] == 'r';
      final quote = src.startsWith(char * 3, i) ? char * 3 : char;
      i += quote.length;

      final start = i;
      while (i < src.length) {
        if (!raw && src[i] == r'\') {
          i += 2;
          continue;
        }
        if (src.startsWith(quote, i)) break;
        i++;
      }

      literals.add(src.substring(start, i.clamp(0, src.length)));
      i += quote.length;
    } else {
      i++;
    }
  }

  return literals;
}
