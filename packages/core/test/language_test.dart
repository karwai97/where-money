import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  test('every supported language is an ISO 639-1 code and nothing else', () {
    for (final language in languages) {
      expect(language, matches(RegExp(r'^[a-z]{2}$')));
    }
  });

  test('the set is closed and has no duplicates', () {
    expect(languages.toSet(), hasLength(languages.length));
  });

  test(
    'English is one of them, because it is what anything unknown becomes',
    () {
      expect(languages, contains(defaultLanguage));
      expect(defaultLanguage, 'en');
    },
  );

  test('there is a second language, or the closed set proves nothing', () {
    expect(languages.length, greaterThan(1));
  });
}
