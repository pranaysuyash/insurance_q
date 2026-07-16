import 'package:flutter/material.dart';
import '../../theme/coverwise_theme.dart';

class CoverWiseMark extends StatelessWidget {
  final double size;
  final bool onDark;
  final bool decorative;

  const CoverWiseMark({
    super.key,
    this.size = 96,
    this.onDark = false,
    this.decorative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: !decorative,
      label: decorative ? null : 'CoverWise shield',
      excludeSemantics: decorative,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CoverWiseMarkPainter(onDark: onDark)),
      ),
    );
  }
}

class _CoverWiseMarkPainter extends CustomPainter {
  final bool onDark;
  const _CoverWiseMarkPainter({required this.onDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shield = Path()
      ..moveTo(size.width * .5, size.height * .08)
      ..cubicTo(size.width * .65, size.height * .15, size.width * .78,
          size.height * .19, size.width * .88, size.height * .22)
      ..lineTo(size.width * .88, size.height * .49)
      ..cubicTo(size.width * .88, size.height * .72, size.width * .72,
          size.height * .88, size.width * .5, size.height * .96)
      ..cubicTo(size.width * .28, size.height * .88, size.width * .12,
          size.height * .72, size.width * .12, size.height * .49)
      ..lineTo(size.width * .12, size.height * .22)
      ..cubicTo(size.width * .22, size.height * .19, size.width * .35,
          size.height * .15, size.width * .5, size.height * .08)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: onDark
            ? const [Color(0xFF69A8FF), CoverWiseColors.blue]
            : const [CoverWiseColors.blue, CoverWiseColors.blueDeep],
      ).createShader(rect);
    canvas.drawPath(shield, paint);

    final check = Path()
      ..moveTo(size.width * .30, size.height * .51)
      ..lineTo(size.width * .44, size.height * .65)
      ..lineTo(size.width * .72, size.height * .35);
    canvas.drawPath(
      check,
      Paint()
        ..color = onDark ? CoverWiseColors.mint : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CoverWiseMarkPainter oldDelegate) =>
      oldDelegate.onDark != onDark;
}
