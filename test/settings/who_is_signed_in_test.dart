import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/settings/initials.dart';

/// The two letters in the disc beside the name. Read down rather than across:
/// what a reader recognises at 36px is the first letter of what they are
/// called and the first letter of the family, and everything between those
/// two is noise at that size.
void main() {
  test('two words give the first letter of each', () {
    expect(initialsOf(name: 'Kar Wai', email: 'kai@example.com'), 'KW');
  });

  test('one word gives one letter', () {
    expect(initialsOf(name: 'Kai', email: 'kai@example.com'), 'K');
  });

  test('three words give the first and the last, not the middle', () {
    expect(initialsOf(name: 'Tan Kar Wai', email: 'kai@example.com'), 'TW');
  });

  test('a Chinese name gives a whole character rather than half of one', () {
    // Counted in code units this is two letters of one character. Counted in
    // grapheme clusters, which is what a reader counts in, it is one.
    expect(initialsOf(name: '陈嘉怡', email: 'kai@example.com'), '陈');
  });

  test('no name falls to the first letter of the address', () {
    expect(initialsOf(name: null, email: 'kai@example.com'), 'K');
  });

  test('a name that is only whitespace is no name', () {
    expect(initialsOf(name: '   ', email: 'kai@example.com'), 'K');
  });
}
