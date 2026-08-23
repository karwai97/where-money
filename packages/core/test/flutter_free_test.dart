import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('the core package declares no dependency on Flutter', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;

    for (final section in const ['dependencies', 'dev_dependencies']) {
      final declared = pubspec[section];
      if (declared is! YamlMap) continue;

      for (final entry in declared.entries) {
        final name = entry.key.toString();
        expect(
          name.contains('flutter'),
          isFalse,
          reason: '$section declares $name; core stays pure Dart',
        );

        final constraint = entry.value;
        if (constraint is YamlMap) {
          expect(
            constraint['sdk'],
            isNot('flutter'),
            reason: '$section pulls $name from the Flutter SDK',
          );
        }
      }
    }
  });
}
