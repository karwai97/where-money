import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-0002's rule, checked mechanically: nothing above the repository ever
/// sees a Firestore document, snapshot or map. Enforcing it here means a stray
/// import fails the suite rather than a code review.
void main() {
  test('only the repository and the composition root import cloud_firestore', () {
    const allowed = {
      // The repository, which is the seam ADR-0002 draws.
      'lib/data/firestore_ledger_store.dart',
      // The composition root, which names FirebaseFirestore.instance to build
      // the repository and never touches a document itself.
      'lib/main.dart',
    };

    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains('cloud_firestore'))
        .map((file) => file.path.replaceAll(r'\', '/'))
        .where((path) => !allowed.contains(path))
        .toList();

    expect(offenders, isEmpty);
  });
}
