import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:where_money_core/where_money_core.dart';

/// The long edge a receipt is stored and sent at. A portrait receipt saturates
/// the model's patch budget at around 1440px, so anything larger bills
/// identically while costing real upload bandwidth.
const defaultLongEdge = 1024;

/// Shrinks a photograph to [longEdge] on its long side, or hands back exactly
/// what it was given when it is already small enough — re-encoding a picture
/// that does not need it only loses detail off faint thermal print.
Uint8List resizeForStorage(
  Uint8List photograph, {
  int longEdge = defaultLongEdge,
}) {
  final decoded = img.decodeImage(photograph);
  if (decoded == null) return photograph;

  final fitted = fitToLongEdge(decoded.width, decoded.height, longEdge);
  if (fitted.width == decoded.width && fitted.height == decoded.height) {
    return photograph;
  }

  return img.encodeJpg(
    img.copyResize(
      decoded,
      width: fitted.width,
      height: fitted.height,
      interpolation: img.Interpolation.average,
    ),
    quality: 85,
  );
}
