import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularText extends StatelessWidget {
  const CircularText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.color,
    required this.radius,
    this.startAngle = math.pi * 0.75,
    this.endAngle = math.pi * 0.25,
  });

  final String text;
  final double fontSize;
  final Color color;
  final double radius;
  final double startAngle;
  final double endAngle;

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    final angleStep =
        (endAngle - startAngle) / (chars.length - 1).clamp(1, double.infinity);

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(chars.length, (index) {
          final angle = startAngle + (angleStep * index);
          final x = radius * math.cos(angle);
          final y = radius * math.sin(angle);

          return Transform.translate(
            offset: Offset(x, y),
            child: Transform.rotate(
              angle: angle - math.pi / 2,
              child: Text(
                chars[index],
              ),
            ),
          );
        }),
      ),
    );
  }
}