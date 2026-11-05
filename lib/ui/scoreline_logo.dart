import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scoreline/theme/arena_theme.dart';

/// Default footprint for the header mark.
const logoSize = 34.0;

/// Bolt outline in a 0..1 box — the same six points the launcher icon's vector
/// path uses.
const _bolt = <(double, double)>[
  (0.585, 0.16),
  (0.315, 0.545),
  (0.475, 0.545),
  (0.415, 0.84),
  (0.685, 0.455),
  (0.525, 0.455),
];

const _hexRadius = 0.46;
const _hexSides = 6;
const _degreesPerSide = 60.0;
const _startAngle = -90.0;

/// The hex badge with the bolt, drawn rather than imported.
///
/// The launcher icon cannot use this shape — adaptive icons are masked to the
/// launcher's own outline, so the hex points would be sliced off — which is
/// exactly why the mark is worth having here, where nothing masks it.
class ScorelineLogo extends StatelessWidget {
  /// Creates the mark at [size] logical pixels square.
  const ScorelineLogo({this.size = logoSize, super.key});

  /// Side length of the square the mark is drawn into.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _LogoPainter()),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final n = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final hex = Path();
    for (var i = 0; i < _hexSides; i++) {
      final radians = (_startAngle + i * _degreesPerSide) * math.pi / 180;
      final x = cx + n * _hexRadius * math.cos(radians);
      final y = cy + n * _hexRadius * math.sin(radians);
      if (i == 0) {
        hex.moveTo(x, y);
      } else {
        hex.lineTo(x, y);
      }
    }
    hex.close();

    canvas.drawPath(
      hex,
      Paint()
        ..shader = const LinearGradient(
          // Corner to corner, matching the Compose Brush.linearGradient that
          // runs Offset(0, 0) to Offset(width, height).
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [violet, cyan],
        ).createShader(Offset.zero & size),
    );

    final bolt = Path();
    for (final (i, (bx, by)) in _bolt.indexed) {
      final x = cx - n / 2 + bx * n;
      final y = cy - n / 2 + by * n;
      if (i == 0) {
        bolt.moveTo(x, y);
      } else {
        bolt.lineTo(x, y);
      }
    }
    bolt.close();

    canvas.drawPath(bolt, Paint()..color = Colors.white);
  }

  // The mark never changes: no field to compare, nothing to repaint for.
  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
