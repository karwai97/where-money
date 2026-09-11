import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:where_money/data/device_preferences.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DevicePreferences preferencesHolding(Map<String, Object> data) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(data);
    return StoredDevicePreferences(SharedPreferencesAsync());
  }

  test('a phone nobody has chosen for follows the phone', () async {
    expect(await preferencesHolding({}).theme(), ThemeMode.system);
  });

  test('the choice is stored by name, not by its place in the enum', () async {
    await preferencesHolding({}).setTheme(ThemeMode.dark);

    expect(await SharedPreferencesAsync().getString('theme'), 'dark');
  });

  test('a stored choice comes back', () async {
    expect(
      await preferencesHolding({'theme': 'light'}).theme(),
      ThemeMode.light,
    );
  });

  test('a choice this version does not know falls back to the phone', () async {
    expect(
      await preferencesHolding({'theme': 'midnight'}).theme(),
      ThemeMode.system,
    );
  });

  test('a phone nobody has chosen a language on speaks English', () async {
    expect(await preferencesHolding({}).language(), defaultLanguage);
  });

  test('the language is stored as its code', () async {
    await preferencesHolding({}).setLanguage('zh');

    expect(await SharedPreferencesAsync().getString('language'), 'zh');
  });

  test('a stored language comes back', () async {
    expect(await preferencesHolding({'language': 'zh'}).language(), 'zh');
  });

  test('a language this version does not know falls back to English', () async {
    expect(await preferencesHolding({'language': 'tlh'}).language(), 'en');
  });

  test('a Ledger nobody has spent in yet has no Home Currency', () async {
    expect(await preferencesHolding({}).homeCurrency(), isNull);
  });

  test(
    'the Home Currency is stored as its code, and survives a restart',
    () async {
      await preferencesHolding({}).setHomeCurrency('SGD');

      expect(await SharedPreferencesAsync().getString('homeCurrency'), 'SGD');
      expect(
        await StoredDevicePreferences(SharedPreferencesAsync()).homeCurrency(),
        'SGD',
      );
    },
  );

  test('a code this version does not know reads as having none', () async {
    expect(
      await preferencesHolding({'homeCurrency': 'XYZ'}).homeCurrency(),
      isNull,
    );
  });

  test(
    'a phone that has never heard from the Worker remembers no allowance',
    () async {
      expect(await preferencesHolding({}).scanAllowance('kai'), isNull);
    },
  );

  test('a remembered allowance survives a restart', () async {
    final allowance = Allowance(
      used: 12,
      limit: 20,
      resetsAt: DateTime.utc(2026, 8, 26),
    );
    await preferencesHolding({}).rememberScanAllowance('kai', allowance);

    expect(
      await StoredDevicePreferences(
        SharedPreferencesAsync(),
      ).scanAllowance('kai'),
      allowance,
    );
  });

  test('one account on a phone cannot read what another was told', () async {
    final preferences = preferencesHolding({});
    await preferences.rememberScanAllowance(
      'kai',
      Allowance(used: 12, limit: 20, resetsAt: DateTime.utc(2026, 8, 26)),
    );

    expect(await preferences.scanAllowance('mei'), isNull);
  });

  test(
    'an allowance stored by a version that wrote it differently is gone',
    () async {
      expect(
        await preferencesHolding({
          'scanAllowance:kai': 'not json',
        }).scanAllowance('kai'),
        isNull,
      );
    },
  );
}
