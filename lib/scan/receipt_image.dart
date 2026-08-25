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

/// What the Worker should be told this image is. It allowlists jpeg, png and
/// webp, and the data URL it builds has to name the type truthfully: a
/// photograph already inside [defaultLongEdge] is stored byte for byte, so
/// what came out of the gallery is not necessarily a JPEG.
String mediaTypeOf(Uint8List image) {
  bool magicAt(int offset, List<int> magic) {
    if (image.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (image[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (magicAt(0, [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (magicAt(0, [0x52, 0x49, 0x46, 0x46]) &&
      magicAt(8, [0x57, 0x45, 0x42, 0x50])) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
