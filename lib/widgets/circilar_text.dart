import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularText extends StatelessWidget {
  const CircularText({
    super.key,
    required this.text,
    required this.style, // بياخد TextStyle جاهز بالكامل (زي GoogleFonts.rammettoOne)
    required this.radius,
    this.arcSpan = math.pi * 0.35, // مساحة القوس — رقم صغير يعني جزء بسيط بس من الدائرة
  });

  final String text;
  final TextStyle style;
  final double radius;
  final double arcSpan;

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    // القوس بيتمركز فوق الدائرة (زاوية -90 درجة = math.pi * 1.5)، ومنتشر يمين وشمال بمقدار arcSpan
    final centerAngle = -math.pi / 2;
    final startAngle = centerAngle - (arcSpan / 2);
    final endAngle = centerAngle + (arcSpan / 2);
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
              angle: angle + math.pi / 2,
              child: Text(chars[index], style: style),
            ),
          );
        }),
      ),
    );
  }
}