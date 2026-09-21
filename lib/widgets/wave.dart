import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class WaveSeekBar extends StatelessWidget {
  const WaveSeekBar({
    super.key,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.onSeek,
    required this.onSeekEnd,
    this.waveCount = 2,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSeekEnd;
  final int waveCount;

  static const double waveAmplitude = 10.0;
  static const double thumbRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void handleDrag(double dx) {
          final newProgress = (dx / constraints.maxWidth).clamp(0.0, 1.0);
          onSeek(newProgress);
        }

        final width = constraints.maxWidth;
        final height = 30.h;
        final midY = height / 2;

        final splitX = width * progress;
        final thumbY = midY + waveAmplitude * math.sin(progress * waveCount * 2 * math.pi);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              handleDrag(details.localPosition.dx),
          onHorizontalDragEnd: (_) => onSeekEnd(progress),
          onTapDown: (details) {
            final newProgress = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onSeek(newProgress);
            onSeekEnd(newProgress);
          },
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: height,
                  child: CustomPaint(
                    painter: _WaveSeekBarPainter(
                      progress: progress,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      waveCount: waveCount,
                    ),
                  ),
                ),
                Positioned(
                  left: splitX - thumbRadius,
                  top: thumbY - thumbRadius,
                  child: IgnorePointer(
                    child: GlassContainer(
                      glowIntensity: .1,
                      width: thumbRadius * 2,
                      height: thumbRadius * 2,
                      // borderRadius: BorderRadius.circular(thumbRadius),
                    ),
                  ),
                ),
              ],
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

  Path _buildFullWavePath(Size size) {
    final path = Path();
    final midY = size.height / 2;

    path.moveTo(0, midY);

    for (double x = 0; x <= size.width; x += 1) {
      final y = midY + WaveSeekBar.waveAmplitude * math.sin((x / size.width) * waveCount * 2 * math.pi);
      path.lineTo(x, y);
    }

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = _buildFullWavePath(size);
    final splitX = size.width * progress;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

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
  }

  @override
  bool shouldRepaint(covariant _WaveSeekBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.waveCount != waveCount;
}