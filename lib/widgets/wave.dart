import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class WaveSeekBar extends StatefulWidget {
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
  State<WaveSeekBar> createState() => _WaveSeekBarState();
}

class _WaveSeekBarState extends State<WaveSeekBar> {
  bool _isHolding = false;

  // The exact position currently controlled by the finger.
  double? _interactionProgress;

  double _calculateProgress(
    double dx,
    double width,
  ) {
    if (width <= 0) {
      return 0.0;
    }

    return (dx / width).clamp(0.0, 1.0);
  }

  void _startInteraction() {
    if (!_isHolding) {
      setState(() {
        _isHolding = true;
        _interactionProgress = widget.progress;
      });
    }
  }

  void _updateInteraction(
    double progress,
  ) {
    _interactionProgress = progress;
    widget.onSeek(progress);
  }

  void _finishInteraction() {
    final finalProgress =
        _interactionProgress ?? widget.progress;

    _interactionProgress = null;

    if (_isHolding) {
      setState(() {
        _isHolding = false;
      });
    }

    // Send the exact value controlled by the finger.
    widget.onSeekEnd(finalProgress);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 30.h;
        final midY = height / 2;

        // While interacting, use the local value instead of waiting
        // for the parent widget to rebuild.
        final displayedProgress =
            _interactionProgress ?? widget.progress;

        final splitX = width * displayedProgress;

        final thumbY = midY +
            WaveSeekBar.waveAmplitude *
                math.sin(
                  displayedProgress *
                      widget.waveCount *
                      2 *
                      math.pi,
                );

        final thumbSize = _isHolding
            ? WaveSeekBar.thumbRadius * 2.8
            : WaveSeekBar.thumbRadius * 2;

        final thumbOffset = thumbSize / 2;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,

          // ---------------------------
          // TAP ANYWHERE ON THE WAVE
          // ---------------------------
          onTapDown: (details) {
            _startInteraction();

            final progress = _calculateProgress(
              details.localPosition.dx,
              width,
            );

            _updateInteraction(progress);
          },

          onTapUp: (_) {
            _finishInteraction();
          },

          onTapCancel: () {
            _interactionProgress = null;

            if (_isHolding) {
              setState(() {
                _isHolding = false;
              });
            }
          },

          // ---------------------------
          // DRAG
          // ---------------------------
          onHorizontalDragStart: (details) {
            _startInteraction();

            final progress = _calculateProgress(
              details.localPosition.dx,
              width,
            );

            _updateInteraction(progress);
          },

          onHorizontalDragUpdate: (details) {
            final progress = _calculateProgress(
              details.localPosition.dx,
              width,
            );

            _updateInteraction(progress);
          },

          onHorizontalDragEnd: (_) {
            _finishInteraction();
          },

          onHorizontalDragCancel: () {
            _interactionProgress = null;

            if (_isHolding) {
              setState(() {
                _isHolding = false;
              });
            }
          },

          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ---------------------------
                // WAVE
                // ---------------------------
                SizedBox(
                  width: double.infinity,
                  height: height,
                  child: CustomPaint(
                    painter: _WaveSeekBarPainter(
                      progress: displayedProgress,
                      activeColor: widget.activeColor,
                      inactiveColor: widget.inactiveColor,
                      waveCount: widget.waveCount,
                    ),
                  ),
                ),

                // ---------------------------
                // THUMB
                // ---------------------------
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,

                  left: splitX - thumbOffset,
                  top: thumbY - thumbOffset,

                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,

                      width: thumbSize,
                      height: thumbSize,

                      decoration: BoxDecoration(
                        shape: BoxShape.circle,

                        border: _isHolding
                            ? Border.all(
                                color: widget.activeColor.withValues(
                                  alpha: 0.9,
                                ),
                                width: 2,
                              )
                            : null,

                        boxShadow: _isHolding
                            ? [
                                BoxShadow(
                                  color: widget.activeColor.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 18,
                                  spreadRadius: 3,
                                ),
                              ]
                            : null,
                      ),

                      child: GlassContainer(
                        glowIntensity: _isHolding ? 0.35 : 0.1,
                        width: thumbSize,
                        height: thumbSize,
                      ),
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
      final y = midY +
          WaveSeekBar.waveAmplitude *
              math.sin(
                (x / size.width) *
                    waveCount *
                    2 *
                    math.pi,
              );

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

    // Active part
    canvas.save();

    canvas.clipRect(
      Rect.fromLTWH(
        0,
        0,
        splitX,
        size.height,
      ),
    );

    canvas.drawPath(
      fullPath,
      activePaint,
    );

    canvas.restore();

    // Inactive part
    canvas.save();

    canvas.clipRect(
      Rect.fromLTWH(
        splitX,
        0,
        size.width - splitX,
        size.height,
      ),
    );

    canvas.drawPath(
      fullPath,
      inactivePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant _WaveSeekBarPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.waveCount != waveCount;
  }
}