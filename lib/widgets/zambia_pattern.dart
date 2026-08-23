import 'package:flutter/material.dart';

/// A quiet, repeatable line-art pattern inspired by Zambia's landscape and
/// identity. It is intentionally abstract so it behaves like texture rather
/// than competing with foreground content.
class ZambiaPattern extends StatelessWidget {
  const ZambiaPattern({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _ZambiaPatternPainter(
        line: colors.primary.withValues(alpha: dark ? .15 : .085),
        accentOpacity: dark ? .18 : .13,
      ),
    );
  }
}

class _ZambiaPatternPainter extends CustomPainter {
  final Color line;
  final double accentOpacity;

  const _ZambiaPatternPainter(
      {required this.line, required this.accentOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const tile = 72.0;
    var row = 0;
    for (double y = -18; y < size.height + tile; y += tile) {
      final offset = row.isEven ? -18.0 : 18.0;
      var column = 0;
      for (double x = offset; x < size.width + tile; x += tile) {
        canvas.save();
        canvas.translate(x, y);
        switch ((row + column) % 5) {
          case 0:
            _drawEagle(canvas, stroke);
          case 1:
            _drawFalls(canvas, stroke);
          case 2:
            _drawZambia(canvas, stroke);
          case 3:
            _drawHome(canvas, stroke);
          default:
            _drawMaize(canvas, stroke);
        }
        canvas.restore();
        column++;
      }
      row++;
    }

    // A tiny, restrained nod to the flag rather than a literal flag block.
    const flag = [
      Color(0xFF198A00),
      Color(0xFFDE2010),
      Color(0xFF101010),
      Color(0xFFEF7D00),
    ];
    final dots = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < flag.length; index++) {
      dots.color = flag[index].withValues(alpha: accentOpacity);
      canvas.drawCircle(Offset(size.width - 22 - index * 8, 18), 2.1, dots);
      canvas.drawCircle(Offset(20 + index * 8, size.height - 17), 1.7, dots);
    }
  }

  void _drawEagle(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(18, 33)
      ..quadraticBezierTo(27, 19, 36, 29)
      ..quadraticBezierTo(45, 19, 54, 33)
      ..quadraticBezierTo(45, 29, 38, 37)
      ..lineTo(36, 45)
      ..lineTo(34, 37)
      ..quadraticBezierTo(27, 29, 18, 33);
    canvas.drawPath(path, paint);
  }

  void _drawFalls(Canvas canvas, Paint paint) {
    canvas.drawPath(
        Path()
          ..moveTo(18, 24)
          ..quadraticBezierTo(36, 18, 54, 24),
        paint);
    for (final x in [23.0, 31.5, 40.0, 48.5]) {
      canvas.drawPath(
          Path()
            ..moveTo(x, 25)
            ..cubicTo(x - 3, 31, x + 3, 37, x, 44),
          paint);
    }
    canvas.drawPath(
        Path()
          ..moveTo(20, 49)
          ..quadraticBezierTo(36, 43, 52, 49),
        paint);
  }

  void _drawZambia(Canvas canvas, Paint paint) {
    // Simplified from Natural Earth's Zambia admin-0 boundary. Keeping the
    // distinctive north-western arm and eastern edge makes it recognisable at
    // this deliberately tiny wallpaper scale.
    const boundary = <Offset>[
      Offset(30.740, -8.340),
      Offset(31.556, -8.762),
      Offset(32.759, -9.231),
      Offset(33.231, -9.677),
      Offset(33.486, -10.526),
      Offset(33.114, -11.607),
      Offset(33.306, -12.436),
      Offset(32.992, -12.784),
      Offset(32.688, -13.713),
      Offset(33.214, -13.972),
      Offset(30.179, -14.796),
      Offset(30.274, -15.508),
      Offset(29.517, -15.645),
      Offset(28.947, -16.043),
      Offset(28.468, -16.468),
      Offset(27.598, -17.291),
      Offset(27.044, -17.938),
      Offset(26.707, -17.961),
      Offset(26.382, -17.846),
      Offset(25.084, -17.662),
      Offset(24.682, -17.353),
      Offset(24.034, -17.296),
      Offset(23.215, -17.523),
      Offset(22.562, -16.898),
      Offset(21.888, -16.080),
      Offset(21.934, -12.898),
      Offset(24.016, -12.911),
      Offset(23.931, -12.566),
      Offset(24.080, -12.191),
      Offset(23.904, -11.722),
      Offset(24.018, -11.237),
      Offset(23.912, -10.927),
      Offset(24.257, -10.952),
      Offset(24.315, -11.263),
      Offset(24.783, -11.239),
      Offset(25.418, -11.331),
      Offset(25.752, -11.785),
      Offset(26.553, -11.924),
      Offset(27.164, -11.609),
      Offset(27.389, -12.133),
      Offset(28.155, -12.272),
      Offset(28.524, -12.699),
      Offset(28.934, -13.249),
      Offset(29.700, -13.257),
      Offset(29.616, -12.179),
      Offset(29.342, -12.361),
      Offset(28.642, -11.972),
      Offset(28.372, -11.794),
      Offset(28.496, -10.790),
      Offset(28.674, -9.606),
      Offset(28.450, -9.165),
      Offset(28.735, -8.527),
      Offset(29.003, -8.407),
      Offset(30.346, -8.238),
    ];
    const minLongitude = 21.887843;
    const maxLongitude = 33.485688;
    const northLatitude = -8.238257;
    const southLatitude = -17.961229;
    Offset point(Offset coordinate) => Offset(
          18 +
              ((coordinate.dx - minLongitude) / (maxLongitude - minLongitude)) *
                  37,
          18 +
              ((northLatitude - coordinate.dy) /
                      (northLatitude - southLatitude)) *
                  36,
        );
    final map = Path()
      ..moveTo(point(boundary.first).dx, point(boundary.first).dy);
    for (final coordinate in boundary.skip(1)) {
      final mapped = point(coordinate);
      map.lineTo(mapped.dx, mapped.dy);
    }
    map.close();
    canvas.drawPath(map, paint);
    canvas.drawCircle(point(const Offset(28.3228, -15.3875)), 1.45, paint);
  }

  void _drawHome(Canvas canvas, Paint paint) {
    final house = Path()
      ..moveTo(18, 35)
      ..lineTo(36, 21)
      ..lineTo(54, 35)
      ..moveTo(22, 33)
      ..lineTo(22, 50)
      ..lineTo(50, 50)
      ..lineTo(50, 33)
      ..moveTo(32, 50)
      ..lineTo(32, 40)
      ..lineTo(40, 40)
      ..lineTo(40, 50);
    canvas.drawPath(house, paint);
  }

  void _drawMaize(Canvas canvas, Paint paint) {
    canvas.drawPath(
        Path()
          ..moveTo(36, 52)
          ..quadraticBezierTo(33, 35, 36, 20),
        paint);
    canvas.drawPath(
        Path()
          ..moveTo(35, 40)
          ..quadraticBezierTo(22, 34, 21, 26)
          ..quadraticBezierTo(31, 28, 35, 40)
          ..moveTo(36, 34)
          ..quadraticBezierTo(50, 28, 51, 21)
          ..quadraticBezierTo(40, 24, 36, 34)
          ..moveTo(35, 47)
          ..quadraticBezierTo(25, 43, 24, 37)
          ..moveTo(36, 43)
          ..quadraticBezierTo(46, 39, 48, 33),
        paint);
  }

  @override
  bool shouldRepaint(_ZambiaPatternPainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.accentOpacity != accentOpacity;
}
