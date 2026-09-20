import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WaveSeekBar extends StatelessWidget {
  const WaveSeekBar({
    super.key,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.onSeek,
    required this.onSeekEnd,
    this.waveCount = 5, 
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSeekEnd;
  final int waveCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void handleDrag(double dx) {
          final newProgress = (dx / constraints.maxWidth).clamp(0.0, 1.0);
          onSeek(newProgress);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              handleDrag(details.localPosition.dx),
          onHorizontalDragEnd: (_) => onSeekEnd(progress),
          onTapDown: (details) {
            handleDrag(details.localPosition.dx);
            onSeekEnd(progress);
          },
          child: SizedBox(
            height: 30.h,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveSeekBarPainter(
                progress: progress,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                waveCount: waveCount,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveSeekBarPainter extends CustomPainter {
  _WaveSeekBarPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.waveCount,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int waveCount;

  @override
  void paint(Canvas canvas, Size size) {
    const waveHeight = 6.0;
    final midY = size.height / 2;
    final splitX = size.width * progress;

    // كل موجة كاملة = شريحتين (فوق وتحت)، فطول الشريحة = العرض الكلي ÷ (العدد × 2)
    final segmentLength = size.width / (waveCount * 2);

    Path buildWavePath(double startX, double endX) {
      final path = Path();
      path.moveTo(startX, midY);
      double x = startX;
      bool goingUp = true;
      while (x < endX) {
        final nextX = (x + segmentLength).clamp(startX, endX);
        path.quadraticBezierTo(
          x + (nextX - x) / 2,
          goingUp ? midY - waveHeight : midY + waveHeight,
          nextX,
          midY,
        );
        x = nextX;
        goingUp = !goingUp;
      }
      return path;
    }

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(buildWavePath(0, splitX), activePaint);

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(buildWavePath(splitX, size.width), inactivePaint);

    canvas.drawCircle(Offset(splitX, midY), 7, Paint()..color = activeColor);
  }

  @override
  bool shouldRepaint(covariant _WaveSeekBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.waveCount != waveCount;
}