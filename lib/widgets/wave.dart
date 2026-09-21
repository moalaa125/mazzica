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
    this.waveCount = 4,
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

  // مسار الموجة الثابت — بيتحسب مرة واحدة بناءً على العرض الكلي فقط،
  // مش بناءً على progress، فشكل الموجة نفسه مايتغيرش أبدًا
  Path _buildFullWavePath(Size size) {
    const waveHeight = 6.0;
    final midY = size.height / 2;
    final segmentLength = size.width / (waveCount * 2);

    final path = Path();
    path.moveTo(0, midY);
    double x = 0;
    bool goingUp = true;
    while (x < size.width) {
      final nextX = (x + segmentLength).clamp(0, size.width).toDouble();
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

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = _buildFullWavePath(size);
    final splitX = size.width * progress;
    final midY = size.height / 2;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // نرسم الجزء اللي فات (من 0 لـ splitX) بلون نشط — بنفس مسار الموجة الثابت
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, splitX, size.height));
    canvas.drawPath(fullPath, activePaint);
    canvas.restore();

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(splitX, 0, size.width - splitX, size.height),
    );
    canvas.drawPath(fullPath, inactivePaint);
    canvas.restore();

    canvas.drawCircle(Offset(splitX, midY), 7, Paint()..color = activeColor);
  }

  @override
  bool shouldRepaint(covariant _WaveSeekBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.waveCount != waveCount;
}