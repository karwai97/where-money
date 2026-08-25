import 'package:where_money/data/device_preferences.dart';

class InMemoryDevicePreferences implements DevicePreferences {
  InMemoryDevicePreferences({bool locksOnOpen = true}) : _locks = locksOnOpen;

  bool _locks;
  final _explained = <String>{};

  @override
  Future<bool> locksOnOpen() async => _locks;

  @override
  Future<void> setLocksOnOpen(bool value) async => _locks = value;

  @override
  Future<bool> hasExplainedMissingPhotos(String uid) async =>
      _explained.contains(uid);

  @override
  Future<void> rememberExplainingMissingPhotos(String uid) async =>
      _explained.add(uid);
}
