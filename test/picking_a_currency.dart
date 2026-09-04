import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Inside the currency sheet rather than on the form underneath it. The sheet
/// covers the screen it was opened from, and both of them have fields and rows.
Finder inTheCurrencySheet(Finder matching) =>
    find.descendant(of: find.byType(BottomSheet), matching: matching);

/// Choosing a currency the way a user does: open the sheet from the thing that
/// shows the current one, search for the code, tap it. The search is not
/// optional — the tail of the list is a hundred and seventy rows and a
/// `ListView` does not build the ones nobody has scrolled to.
Future<void> pickCurrency(WidgetTester tester, String from, String code) async {
  // The row or the field rather than the words in it: a label sits inside the
  // thing that opens the sheet, and tapping the words alone warns about it.
  await tester.tap(
    find.ancestor(of: find.text(from), matching: find.byType(InkWell)).first,
  );
  await tester.pumpAndSettle();

  await tester.enterText(inTheCurrencySheet(find.byType(TextField)), code);
  await tester.pumpAndSettle();

  await tester.tap(inTheCurrencySheet(find.widgetWithText(ListTile, code)));
  await tester.pumpAndSettle();
}
