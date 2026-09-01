import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/device_preferences.dart';
import 'data/device_scan_store.dart';
import 'data/firestore_ledger_store.dart';
import 'knobs/remote_config_knobs.dart';
import 'lock/local_auth_lock.dart';
import 'scan/worker_model_gateway.dart';
import 'session/google_sign_in_gateway.dart';

/// The deployed Worker. Not a secret — the key is a Worker secret and is never
/// in this repo, in Remote Config, or in a build-time define.
final worker = Uri.parse('https://where-money.karwai-ngim.workers.dev');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No generated Dart options file: the native config (google-services.json,
  // GoogleService-Info.plist) is the only place project keys live, and it is
  // gitignored.
  await Firebase.initializeApp();

  final signIn = GoogleSignInGateway();
  await signIn.initialize();

  final documents = await getApplicationDocumentsDirectory();
  final knobs = await knobsFromRemoteConfig();

  // Read before the first frame is drawn: whoever chose Dark should not be
  // shown a light app on the way in. Awaited before `runApp`, so a preference
  // store that will not answer has to leave the app opening on the default
  // rather than on nothing at all.
  final preferences = StoredDevicePreferences();
  final theme = await preferences.theme().catchError((_) => ThemeMode.system);

  runApp(
    WhereMoneyApp(
      signIn: signIn,
      lock: LocalAuthLock(),
      preferences: preferences,
      knobs: knobs,
      theme: theme,
      model: WorkerModelGateway(
        endpoint: worker,
        knobs: knobs,
        idToken: () =>
            FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(),
      ),
      ledgerFor: (uid) => FirestoreLedgerStore(
        firestore: FirebaseFirestore.instance,
        uid: uid,
        // Per user, so signing in as someone else on a shared phone does not
        // show their receipts.
        scans: DeviceScanStore(Directory(p.join(documents.path, 'scans', uid))),
      ),
    ),
  );
}
