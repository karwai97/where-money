import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/firestore_ledger_store.dart';
import 'session/google_sign_in_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No generated Dart options file: the native config (google-services.json,
  // GoogleService-Info.plist) is the only place project keys live, and it is
  // gitignored.
  await Firebase.initializeApp();

  final signIn = GoogleSignInGateway();
  await signIn.initialize();

  runApp(
    WhereMoneyApp(
      signIn: signIn,
      ledgerFor: (uid) => FirestoreLedgerStore(
        firestore: FirebaseFirestore.instance,
        uid: uid,
      ),
    ),
  );
}
