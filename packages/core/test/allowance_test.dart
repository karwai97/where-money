import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

/// The day the Worker counts in rolls over in UTC, which is not midnight
/// anywhere the app is read. `resetsAt` is the only clock that counts, and the
/// rule for reading a remembered allowance against it lives here rather than on
/// the screen that draws one.
void main() {
  final resetsAt = DateTime.utc(2026, 8, 26);
  final allowance = Allowance(used: 12, limit: 20, resetsAt: resetsAt);

  test('an allowance still in its own day says what it says', () {
    final now = resetsAt.subtract(const Duration(hours: 6));

    expect(allowance.usedAt(now), 12);
    expect(allowance.spentAt(now), closeTo(0.6, 0.001));
  });

  test('a day that has rolled over has nothing spent in it yet', () {
    final now = resetsAt.add(const Duration(minutes: 1));

    expect(allowance.usedAt(now), 0);
    expect(allowance.spentAt(now), 0);
  });

  test('the moment it resets is already the new day', () {
    expect(allowance.usedAt(resetsAt), 0);
  });

  test('more used than the limit does not fill past the end', () {
    final spent = Allowance(used: 23, limit: 20, resetsAt: resetsAt);

    expect(spent.usedAt(resetsAt.subtract(const Duration(hours: 1))), 23);
    expect(spent.spentAt(resetsAt.subtract(const Duration(hours: 1))), 1);
  });

  test(
    'a cap of nothing is a day already gone rather than a division by it',
    () {
      final none = Allowance(used: 0, limit: 0, resetsAt: resetsAt);

      expect(none.spentAt(resetsAt.subtract(const Duration(hours: 1))), 1);
    },
  );
}
