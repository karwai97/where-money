import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two promises about what capture *cannot* do. Neither is reachable from a
/// behavioural test — an absence of network calls looks exactly like a test
/// that forgot to make any — so both are checked the way ADR-0002's rule
/// already is, by reading what the code is built from.
void main() {
  /// Everything a photograph passes through between the shutter and the disk.
  /// `FirestoreLedgerStore` is deliberately not here: it hands all four Scan
  /// methods straight to the device store and is short enough to read.
  final scanPath = const [
    'lib/scan/inbox_bloc.dart',
    'lib/scan/receipt_image.dart',
    'lib/scan/photographer.dart',
    'lib/data/device_scan_store.dart',
    'lib/data/scan_record.dart',
  ].map(File.new);

  test(
    'a Scan is written without anything on the way reaching the network',
    () {
      const network = [
        'cloud_firestore',
        'firebase',
        'package:http',
        'HttpClient',
      ];

      final reaching = [
        for (final file in scanPath)
          for (final word in network)
            if (file.readAsStringSync().contains(word)) '${file.path}: $word',
      ];

      expect(reaching, isEmpty);
    },
  );

  test('the only thing that deletes a Scan is the user abandoning it', () {
    final deleting = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) =>
              RegExp(r'\.delete(Sync)?\(').hasMatch(file.readAsStringSync()),
        )
        .map((file) => file.path.replaceAll(r'\', '/'))
        .toList();

    expect(deleting, ['lib/data/device_scan_store.dart']);
  });
}
