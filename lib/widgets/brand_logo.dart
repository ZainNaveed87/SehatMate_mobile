import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: const Center(child: SizedBox(width: 19, height: 19, child: CustomPaint(painter: _BrandMarkPainter()))),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          const Text(
            'SehatRoute AI',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
            ),
          ),
        ],
      ],
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final route = Path()
      ..moveTo(5, 19)
      ..cubicTo(9, 19, 9, 13, 13, 13)
      ..cubicTo(17, 13, 19, 11, 19, 8);
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(5, 19), 2, Paint()..color = Colors.white);

    final heart = Path()
      ..moveTo(15, 10.5)
      ..cubicTo(14.4, 9.9, 11.8, 7.6, 11.8, 6)
      ..cubicTo(11.8, 4.5, 13, 3.3, 14.4, 3.3)
      ..cubicTo(15.3, 3.3, 15.9, 3.8, 16.5, 4.5)
      ..cubicTo(17.1, 3.8, 17.7, 3.3, 18.6, 3.3)
      ..cubicTo(20, 3.3, 21.2, 4.5, 21.2, 6)
      ..cubicTo(21.2, 7.6, 18.6, 9.9, 18, 10.5)
      ..lineTo(16.5, 12)
      ..close();
    canvas.drawPath(heart, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
