import 'package:flutter/material.dart';

/// The launcher's receipt, on the one screen that shows it: a paper with a
/// torn bottom edge, three printed lines and a total.
///
/// Painted rather than loaded. The launcher is an Android vector, which
/// Flutter cannot read, and `flutter_svg` is not a dependency worth adding for
/// one shape — so the path data in
/// `android/app/src/main/res/drawable/ic_launcher_foreground.xml` is drawn
/// here instead, in the same units, so the two can be checked against each
/// other.
///
/// Decoration, and excluded from what is read out: the name under it says
/// everything this says.
class ReceiptMark extends StatelessWidget {
  const ReceiptMark({super.key});

  /// Twice the units it is drawn in. Fixed, and deliberately outside the text
  /// scaler's reach — a mark is not type, and at 200% this would be a third
  /// of the screen.
  static const _size = Size(72, 112);

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;

    return ExcludeSemantics(
      child: CustomPaint(
        size: _size,
        painter: _Receipt(
          // White paper on a near-white ground vanished without an edge, so
          // light draws one and dark does not need one.
          paper: light ? colours.surfaceContainerLowest : colours.onSurface,
          edge: light ? colours.outline : null,
          printed: colours.outline,
          total: colours.primary,
        ),
      ),
    );
  }
}

class _Receipt extends CustomPainter {
  const _Receipt({
    required this.paper,
    required this.edge,
    required this.printed,
    required this.total,
  });

  final Color paper;
  final Color? edge;
  final Color printed;
  final Color total;

  /// The box the launcher's shape sits in, one unit wider and taller than the
  /// paper on every side so the light edge has somewhere to be drawn.
  static const _box = Size(36, 56);

  /// Where that box starts in the launcher's own 108-unit viewport. Every
  /// number below is the launcher's, so the two files read as the same shape.
  static const _origin = Offset(36, 26);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _box.width);
    canvas.translate(-_origin.dx, -_origin.dy);

    final receipt = _shape();
    canvas.drawPath(receipt, Paint()..color = paper);
    if (edge case final Color colour) {
      canvas.drawPath(
        receipt,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Three lines of print: one short, two full width.
    final ink = Paint()..color = printed;
    for (final line in const [
      (top: 36.0, width: 14.0),
      (top: 44.0, width: 20.0),
      (top: 52.0, width: 20.0),
    ]) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          44,
          line.top,
          44 + line.width,
          line.top + 3,
          _lineCorner,
        ),
        ink,
      );
    }

    // What the receipt is about, in the one colour on it that is not ink.
    canvas.drawRRect(
      RRect.fromLTRBR(44, 64, 64, 68, const Radius.circular(2)),
      Paint()..color = total,
    );

    canvas.restore();
  }

  static const _lineCorner = Radius.circular(1.5);
  static const _corner = 3.0;

  /// The paper itself: rounded at the top, torn along the bottom.
  Path _shape() {
    const left = 37.0;
    const right = 71.0;
    const top = 27.0;
    const tear = 78.0;
    const teeth = 12;
    const tooth = (right - left) / teeth;

    final path = Path()
      ..moveTo(left + _corner, top)
      ..lineTo(right - _corner, top)
      ..arcToPoint(
        const Offset(right, top + _corner),
        radius: const Radius.circular(_corner),
      )
      ..lineTo(right, tear);

    // Alternating down and up, ending back at the tear line on the left, so
    // the paper reads as having been pulled off a till roll.
    for (var tip = 1; tip <= teeth; tip++) {
      path.lineTo(right - tip * tooth, tip.isOdd ? tear + 3 : tear);
    }

    return path
      ..lineTo(left, top + _corner)
      ..arcToPoint(
        const Offset(left + _corner, top),
        radius: const Radius.circular(_corner),
      )
      ..close();
  }

  @override
  bool shouldRepaint(_Receipt old) =>
      old.paper != paper ||
      old.edge != edge ||
      old.printed != printed ||
      old.total != total;
}
