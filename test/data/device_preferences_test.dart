import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:where_money/data/device_preferences.dart';

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
}
