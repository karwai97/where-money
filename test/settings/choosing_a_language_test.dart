import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../as_drawn.dart';
import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The Settings screen in both languages. What the Ledger behind it reads as
/// is the_ledger_speaks_chinese_test.dart's; this file is about the Setting
/// itself, so the way in is the icon rather than its tooltip.
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
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Settings offers both languages, each in its own', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
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

    await tester.tap(find.byType(DropdownButtonFormField<String>));
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

    expect(markSaying('Settings'), findsWidgets);
    expect(await preferences.language(), 'en');
  });

  testWidgets('choosing 中文 changes the screen there and then', (tester) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await choose(tester, '中文');

    expect(markSaying('设置'), findsWidgets);
    expect(markSaying('Settings'), findsNothing);
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
    // Settings runs past the bottom of a small phone, and what is below the
    // fold is never built. This claim is about the panels down there, so the
    // screen has to be tall enough to hold them.
    tester.view
      ..physicalSize = const Size(1000, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(language: 'zh'));
    await openSettings(tester);

    // Exactly as the message files hold them. Every one of these is drawn as
    // a tracked mark, and a mark in a language with no upper case to go to is
    // not cased at all — otherwise the app's own name inside "锁定 Where
    // Money" would be the only shouting on the screen.
    for (final chinese in ['设置', '主题', '语言', '锁定 Where Money', '主货币', '退出登录']) {
      expect(find.text(chinese), findsWidgets, reason: '$chinese is missing');
    }

    for (final english in [
      'Settings',
      'Theme',
      'Language',
      'Lock Where Money',
      'Home Currency',
      'Sign out',
    ]) {
      // Both cases, because only the marks are drawn upper: English left in a
      // sentence under a row would slip past a finder that asks for shouting.
      expect(
        find.text(english),
        findsNothing,
        reason: '$english is still here',
      );
      expect(
        markSaying(english),
        findsNothing,
        reason: '$english is still here, in the case a mark is drawn in',
      );
    }
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
}
