import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

/// What a console can and cannot do to a running app. Everything here is a
/// pure function over strings, which is the whole reason Knobs is a value and
/// not a collaborator.
void main() {
  test(
    'an app that has heard from no console runs on what it shipped with',
    () {
      expect(knobsFrom(const {}), const Knobs());
    },
  );

  test('a console changes the tier, the effort, the size and the cap', () {
    final knobs = knobsFrom(const {
      'model': 'gpt-5-mini',
      'reasoning_effort': 'medium',
      'image_long_edge': '1440',
      'daily_cap': '15',
    });

    expect(
      knobs,
      const Knobs(
        model: 'gpt-5-mini',
        effort: 'medium',
        longEdge: 1440,
        dailyCap: 15,
      ),
    );
  });

  test('a knob the console left alone keeps its compiled-in value', () {
    expect(
      knobsFrom(const {'model': 'gpt-5-mini'}),
      const Knobs(model: 'gpt-5-mini'),
    );
  });

  test('a model this app has never heard of is still sent', () {
    // The Worker holds the allowlist and falls back on anything it does not
    // recognise. A tier added there has to reach phones without an app
    // release, which it cannot if this end second-guesses it.
    expect(knobsFrom(const {'model': 'gpt-6-nano'}).model, 'gpt-6-nano');
  });

  test('a long edge that is not a number leaves the size alone', () {
    expect(knobsFrom(const {'image_long_edge': ''}).longEdge, 1024);
    expect(knobsFrom(const {'image_long_edge': '1024px'}).longEdge, 1024);
  });

  test('a long edge nothing could be read at is a typo, not a decision', () {
    expect(knobsFrom(const {'image_long_edge': '64'}).longEdge, 1024);
    expect(knobsFrom(const {'image_long_edge': '-1'}).longEdge, 1024);
    expect(knobsFrom(const {'image_long_edge': '99999'}).longEdge, 1024);
  });

  test('a cap that is not a whole count leaves the cap alone', () {
    expect(knobsFrom(const {'daily_cap': 'lots'}).dailyCap, 25);
    expect(knobsFrom(const {'daily_cap': '-3'}).dailyCap, 25);
  });

  test('a cap of nothing at all is a decision, and it holds', () {
    expect(knobsFrom(const {'daily_cap': '0'}).dailyCap, 0);
  });

  test('what a console is seeded with is what the app already runs on', () {
    expect(knobsFrom(const Knobs(longEdge: 1440).asDelivered()).longEdge, 1440);
  });
}
