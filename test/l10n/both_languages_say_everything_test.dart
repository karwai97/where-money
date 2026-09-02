import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The failure mode the rest of the suite cannot see. A key dropped from
/// **both** ARB files fails codegen loudly, because `nullable-getter: false`
/// means the getter has to exist. A key dropped from **zh alone** falls back to
/// the English one and the screen keeps working — it has happened twice, and
/// both times exactly one widget test caught it, by accident, because that
/// test happened to assert the whole sentence.
///
/// Ten keys have no assertion anywhere; each needs a state a widget test
/// cannot hold still. Key parity is the check that covers them, and it covers
/// the next ten without anybody adding a test.
void main() {
  final template = _Arb('lib/l10n/app_en.arb');
  final translations = [_Arb('lib/l10n/app_zh.arb')];

  test('every message file names its language', () {
    for (final arb in [template, ...translations]) {
      expect(
        arb.json['@@locale'],
        isNotNull,
        reason: '${arb.path} has no @@locale',
      );
    }
  });

  for (final arb in translations) {
    group('${arb.json['@@locale']}', () {
      test('says everything English says, and nothing English does not', () {
        expect(
          arb.keys.difference(template.keys),
          isEmpty,
          reason:
              'these are in ${arb.path} and not in ${template.path}, so '
              'nothing generates a getter for them and nothing reads them.',
        );
        expect(
          template.keys.difference(arb.keys),
          isEmpty,
          reason:
              'these fall back to English on a screen that looks finished. '
              'That is what l10n-untranslated.json is for and it should be {}.',
        );
      });

      test('fills the same blanks in every message', () {
        for (final key in arb.keys.intersection(template.keys)) {
          expect(
            arb.placeholdersIn(key),
            template.placeholdersIn(key),
            reason:
                '$key takes different placeholders in the two languages. A '
                'name only one side uses is rendered literally, braces and '
                'all.',
          );
        }
      });
    });
  }

  for (final arb in [template, ...translations]) {
    test('${arb.path} says each thing once', () {
      // Two spaces exactly. A `@key` block's own `description` and
      // `placeholders` are indented further and are not message names.
      final written = RegExp(
        r'^ {2}"(@{0,2}[A-Za-z0-9_]+)"\s*:',
        multiLine: true,
      ).allMatches(arb.source).map((match) => match.group(1)!).toList();

      final twice = written
          .where((key) => written.where((other) => other == key).length > 1)
          .toSet();

      expect(
        twice,
        isEmpty,
        reason:
            'a JSON object keeps the last of two keys with the same name, so '
            'the earlier message is in the file and not in the app.',
      );
    });
  }
}

class _Arb {
  _Arb(String path) : this._(path, File(path).readAsStringSync());

  _Arb._(this.path, this.source)
    : json = jsonDecode(source) as Map<String, Object?>;

  final String path;
  final String source;
  final Map<String, Object?> json;

  /// The messages, without `@@locale` or the `@key` blocks that describe them
  /// for a translator. Those are documentation and only the template carries
  /// most of them.
  Set<String> get keys =>
      json.keys.where((key) => !key.startsWith('@')).toSet();

  /// The blanks a message leaves for the app to fill. `=1{` and `other{` are a
  /// plural's branches rather than placeholders, which is why the closing brace
  /// is part of the match.
  Set<String> placeholdersIn(String key) => RegExp(
    r'\{(\w+)\}',
  ).allMatches(json[key]! as String).map((match) => match.group(1)!).toSet();
}
