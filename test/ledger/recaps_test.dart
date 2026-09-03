import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/ledger/ledger_bloc.dart';
import 'package:where_money/ledger/recaps.dart';

/// The invariant that used to be three early-returns spread across two fields
/// and two methods on `LedgerBloc`. It is one object's now, so it is worth
/// asking it directly: everything here is about not paying for the same month
/// twice, and about a month being askable again once somebody lets go of it.
void main() {
  const august = 'hash-of-august-in-english';
  const september = 'hash-of-september-in-english';

  test('a month nobody has asked about is not known', () {
    expect(Recaps().held(august), isNull);
  });

  test('a month somebody is asking about reads as pending', () {
    final recaps = Recaps()..claim(august);

    expect(recaps.held(august), const RecapPending());
  });

  test('the second caller to claim a month is told somebody already has', () {
    final recaps = Recaps();

    expect(recaps.claim(august), isTrue);
    expect(recaps.claim(august), isFalse);
  });

  test('claiming one month says nothing about another', () {
    final recaps = Recaps()..claim(august);

    expect(recaps.claim(september), isTrue);
    expect(recaps.held(september), const RecapPending());
  });

  test('an answer displaces the pending', () {
    final recaps = Recaps()
      ..claim(august)
      ..keep(august, const RecapOnScreen('August was quiet.'));

    expect(recaps.held(august), const RecapOnScreen('August was quiet.'));
  });

  test('a month that has been answered is not asked about again', () {
    final recaps = Recaps()
      ..claim(august)
      ..keep(august, const RecapOnScreen('August was quiet.'));

    expect(recaps.claim(august), isFalse);
  });

  /// A refusal costs the same as an answer, so it is held the same way.
  test('a month the Model would not write is not paid for twice', () {
    final recaps = Recaps()
      ..claim(august)
      ..keep(august, const RecapUnavailable(WhyNoRecap.refused));

    expect(recaps.held(august), const RecapUnavailable(WhyNoRecap.refused));
    expect(recaps.claim(august), isFalse);
  });

  test('forgetting a month makes it unknown and askable again', () {
    final recaps = Recaps()
      ..claim(august)
      ..keep(august, const RecapUnavailable(WhyNoRecap.refused))
      ..forget(august);

    expect(recaps.held(august), isNull);
    expect(recaps.claim(august), isTrue);
  });
}
