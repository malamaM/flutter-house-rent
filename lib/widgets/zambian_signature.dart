import 'package:flutter/material.dart';

class ZambianSignature extends StatelessWidget {
  const ZambianSignature({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: .07)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: onDark
                ? Colors.white.withValues(alpha: .14)
                : colors.outlineVariant),
      ),
      child: Stack(children: [
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.favorite_rounded,
                size: 14,
                color: onDark ? const Color(0xFF78D6B5) : colors.primary),
            const SizedBox(width: 7),
            Text('Built by Zambians, for Zambians',
                style: TextStyle(
                    color: onDark ? Colors.white70 : colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .1)),
          ]),
        ),
        const Positioned(
          right: 10,
          top: 8,
          child: SizedBox(
            width: 32,
            height: 32,
            child: CustomPaint(painter: _ZambianHomePainter()),
          ),
        ),
      ]),
    );
  }
}

class _ZambianHomePainter extends CustomPainter {
  const _ZambianHomePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final house = Path()
      ..moveTo(size.width * .5, 0)
      ..lineTo(size.width, size.height * .38)
      ..lineTo(size.width * .88, size.height * .38)
      ..lineTo(size.width * .88, size.height)
      ..lineTo(size.width * .12, size.height)
      ..lineTo(size.width * .12, size.height * .38)
      ..lineTo(0, size.height * .38)
      ..close();

    canvas.drawShadow(house, Colors.black.withValues(alpha: .38), 5, true);
    canvas.save();
    canvas.clipPath(house);
    const flagColors = [
      Color(0xFF198A00),
      Color(0xFFDE2010),
      Color(0xFF101010),
      Color(0xFFEF7D00),
    ];
    final stripeWidth = size.width / flagColors.length;
    for (var index = 0; index < flagColors.length; index++) {
      canvas.drawRect(
        Rect.fromLTWH(index * stripeWidth, 0, stripeWidth + .5, size.height),
        Paint()..color = flagColors[index],
      );
    }
    canvas.restore();
    canvas.drawPath(
      house,
      Paint()
        ..color = Colors.white.withValues(alpha: .72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15,
    );
  }

  @override
  bool shouldRepaint(_ZambianHomePainter oldDelegate) => false;
}
