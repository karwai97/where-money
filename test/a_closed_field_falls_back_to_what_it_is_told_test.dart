import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/a_form_of_rows.dart';
import 'package:where_money/l10n/app_localizations.dart';

/// A stored value that is not one of the options has to be drawn as something,
/// and what it is drawn as is the caller's to say. It used to be `options.last`
/// — right by accident in Review, where both taxonomies end in their catch-all,
/// and wrong anywhere else: a Setting's list ends wherever it ends.
void main() {
  Future<void> draw(
    WidgetTester tester, {
    required String value,
    required String whenUnrecognised,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Closed<String>(
          name: 'language',
          label: 'Language',
          value: value,
          options: const ['en', 'zh'],
          whenUnrecognised: whenUnrecognised,
          copy: (code) => code,
          onChosen: (_) {},
        ),
      ),
    ),
  );

  testWidgets('a value in the list is the value shown', (tester) async {
    await draw(tester, value: 'zh', whenUnrecognised: 'en');

    expect(find.text('zh'), findsOneWidget);
  });

  testWidgets('a value the list has never heard of shows the fallback', (
    tester,
  ) async {
    await draw(tester, value: 'fr', whenUnrecognised: 'en');

    expect(find.text('en'), findsOneWidget);
    expect(
      find.text('zh'),
      findsNothing,
      reason:
          'the last option is the fallback only where the list happens to end '
          'in one',
    );
  });
}
