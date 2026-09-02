/// The receipt photo, wherever it is being looked at. Review checks fields
/// against it and the Ledger answers "what was that 40 at the supermarket"
/// with it, and both want the same thing: a thumbnail that opens up.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class ReceiptOnScreen extends StatelessWidget {
  const ReceiptOnScreen(this.bytes, {super.key});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: AppLocalizations.of(context).receiptZoom,
    child: InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => _UpClose(bytes))),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.memory(bytes, fit: BoxFit.contain),
      ),
    ),
  );
}

/// Thermal print goes faint and small, so the receipt gets the whole screen and
/// as much magnification as the user's fingers ask for.
class _UpClose extends StatelessWidget {
  const _UpClose(this.bytes);

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(words.receiptTitle),
        leading: IconButton(
          tooltip: words.receiptBackToTheFields,
          icon: const Icon(Icons.arrow_back),
          onPressed: Navigator.of(context).pop,
        ),
      ),
      backgroundColor: Colors.black,
      body: InteractiveViewer(
        maxScale: 8,
        child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
      ),
    );
  }
}
