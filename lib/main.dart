import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No generated Dart options file: the native config (google-services.json,
  // GoogleService-Info.plist) is the only place project keys live, and it is
  // gitignored.
  await Firebase.initializeApp();
  runApp(const WhereMoneyApp());
}

class WhereMoneyApp extends StatelessWidget {
  const WhereMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'where_money',
      theme: ThemeData(useMaterial3: true),
      home: const HomePlaceholder(),
    );
  }
}

class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('where_money')),
      body: const Center(child: Text('Nothing here yet.')),
    );
  }
}
