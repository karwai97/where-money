import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:where_money_core/where_money_core.dart';

/// The knobs as a Firebase console has them, over the ones the app was
/// compiled with. Read once at launch, so a knob turned now is what the next
/// launch scans with.
///
/// Nothing here can fail in a way worth telling anyone about, and nothing here
/// may fail in a way that stops the app: this is awaited before `runApp`, so a
/// throw that escapes is a phone showing nothing at all. A first launch with
/// no network, a phone without Play services, and a project whose template has
/// never been published all scan normally on the compiled-in values.
Future<Knobs> knobsFromRemoteConfig({Knobs fallback = const Knobs()}) async {
  final remote = FirebaseRemoteConfig.instance;

  try {
    await remote.setDefaults(fallback.asDelivered());
    await remote.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        // A tier changed to answer a misread total has to reach the phone on
        // the next launch, not in twelve hours. One operator reads this
        // console, so there is no fetch storm to throttle.
        minimumFetchInterval: Duration.zero,
      ),
    );
    await remote.fetchAndActivate();
  } catch (_) {
    // Whatever the last fetch activated is still there, and the defaults set
    // above are behind that.
  }

  try {
    return knobsFrom({
      for (final MapEntry(:key, :value) in remote.getAll().entries)
        key: value.asString(),
    }, fallback: fallback);
  } catch (_) {
    // Remote Config is not on this phone at all.
    return fallback;
  }
}
