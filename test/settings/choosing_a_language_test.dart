import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The Settings screen in both languages. Only this screen has moved over yet;
/// everything above it is still English, and that is what the expand half of
/// the migration is supposed to look like.
void main() {
  late InMemoryDevicePreferences preferences;

  setUp(() {
    preferences = InMemoryDevicePreferences();
  });

  Widget app({String language = 'en', ThemeMode theme = ThemeMode.system}) =>
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => InMemoryLedgerStore().stores,
        model: FakeModelGateway(),
        lock: FakeDeviceLock(),
        preferences: preferences,
        theme: theme,
        language: language,
        photograph: (_) async => null,
      );

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Settings offers both languages, each in its own', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    // Named in its own language either way round, so somebody can find theirs
    // without already reading the other one.
    expect(find.text('English'), findsWidgets);
    expect(find.text('中文'), findsWidgets);
  });

  testWidgets('every language the domain knows is named in the dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    // A language added to the closed set with no name beside it would print as
    // its own code here, which is the thing this catches.
    for (final language in languages) {
      expect(
        find.text(language),
        findsNothing,
        reason: '$language has no name of its own to show',
      );
    }
  });

  testWidgets('an app nobody has chosen a language on is in English', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    expect(find.text('Settings'), findsWidgets);
    expect(await preferences.language(), 'en');
  });

  testWidgets('choosing 中文 changes the screen there and then', (tester) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await choose(tester, '中文');

    expect(find.text('设置'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('and the choice is kept on the phone', (tester) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await choose(tester, '中文');

    expect(await preferences.language(), 'zh');
  });

  testWidgets('an app opened in 中文 is in 中文 on the frame it opens with', (
    tester,
  ) async {
    // One pump, not pumpAndSettle: whoever chose 中文 never sees an English
    // frame on the way in.
    await tester.pumpWidget(app(language: 'zh'));

    expect(
      Localizations.localeOf(tester.element(find.byType(Scaffold).first)),
      const Locale('zh'),
    );
  });

  testWidgets('every word on the screen moves, the panels below included', (
    tester,
  ) async {
    await tester.pumpWidget(app(language: 'zh'));
    await openSettings(tester);

    for (final chinese in [
      '设置',
      '主题',
      '语言',
      '锁定 where_money',
      '退出登录',
      '每次扫描请求的设置',
      '审核修正了什么',
    ]) {
      expect(find.text(chinese), findsWidgets, reason: '$chinese is missing');
    }

    for (final english in [
      'Settings',
      'Theme',
      'Language',
      'Lock where_money',
      'Sign out',
      'What each Scan asks for',
      'What Review had to correct',
    ]) {
      expect(
        find.text(english),
        findsNothing,
        reason: '$english is still here',
      );
    }
  });

  testWidgets('the Knobs the panel reports are read in 中文 too', (tester) async {
    await tester.pumpWidget(app(language: 'zh'));
    await openSettings(tester);

    // A count with a language of its own around it, which is the whole reason
    // these are ICU messages rather than concatenated fragments.
    expect(find.text('每日上限：40 次扫描'), findsOne);
    expect(find.text('模型：gpt-5-nano'), findsOne);
  });

  testWidgets('a language change does not undo the theme beside it', (
    tester,
  ) async {
    await tester.pumpWidget(app(theme: ThemeMode.dark));
    await openSettings(tester);

    await choose(tester, '中文');

    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
  });

  testWidgets('a screen that has not moved yet still renders its English', (
    tester,
  ) async {
    await tester.pumpWidget(app(language: 'zh'));
    await tester.pumpAndSettle();

    // The Ledger is tickets 06 onwards. Under a Chinese Settings it is still
    // English, and still there — which is what makes this migration one screen
    // at a time.
    expect(find.byTooltip('Settings'), findsOne);
  });
}
