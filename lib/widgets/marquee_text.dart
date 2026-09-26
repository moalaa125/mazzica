import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.speed = 30,
    this.spacing = 60,
    this.startDelay = const Duration(milliseconds: 800),
    this.endPause = const Duration(milliseconds: 900),
    this.fadeWidth = 18,
  });

  final String text;
  final TextStyle style;

  final double speed;

  final double spacing;
  final Duration startDelay;
  final Duration endPause;
  final double fadeWidth;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double _textWidth = 0;
  double _availableWidth = 0;

  bool _shouldScroll = false;
  int _animationVersion = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.speed != widget.speed ||
        oldWidget.spacing != widget.spacing) {
      _measureAndStart();
    }
  }

  void _measureAndStart() {
    if (!mounted) return;

    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: widget.style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    _textWidth = painter.width;

    final shouldScroll = _textWidth > _availableWidth;

    if (_shouldScroll == shouldScroll &&
        _controller.isAnimating &&
        shouldScroll) {
      return;
    }

    _shouldScroll = shouldScroll;

    _animationVersion++;

    _controller.stop();
    _controller.reset();

    if (!_shouldScroll) {
      return;
    }

    final distance = _textWidth + widget.spacing;

    final duration = Duration(
      milliseconds: ((distance / widget.speed) * 1000).round(),
    );

    _controller.duration = duration;

    _startAnimation(_animationVersion);
  }

  Future<void> _startAnimation(int version) async {
    await Future.delayed(widget.startDelay);

    if (!mounted ||
        version != _animationVersion ||
        !_shouldScroll) {
      return;
    }

    while (mounted &&
        version == _animationVersion &&
        _shouldScroll) {
      await _controller.forward();

      if (!mounted ||
          version != _animationVersion ||
          !_shouldScroll) {
        return;
      }

      await Future.delayed(widget.endPause);

      if (!mounted ||
          version != _animationVersion ||
          !_shouldScroll) {
        return;
      }

      _controller.reset();

      await Future.delayed(widget.startDelay);

      if (!mounted ||
          version != _animationVersion ||
          !_shouldScroll) {
        return;
      }
    }
  }

  @override
  void dispose() {
    _animationVersion++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        if (width != _availableWidth) {
          _availableWidth = width;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _measureAndStart();
            }
          });
        }

        final height = (widget.style.fontSize ?? 16) * 1.3;

        return SizedBox(
          width: double.infinity,
          height: height,
          child: ClipRect(
            child: _shouldScroll
                ? _buildScrollingText()
                : _buildStaticText(),
          ),
        );
      },
    );
  }

  Widget _buildStaticText() {
    return Center(
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildScrollingText() {
    final totalDistance = _textWidth + widget.spacing;

    return ShaderMask(
      shaderCallback: (bounds) {
        final fade = (widget.fadeWidth / bounds.width)
            .clamp(0.0, 0.45);

        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [
            0,
            fade,
            1 - fade,
            1,
          ],
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final dx = -(_controller.value * totalDistance);

          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              ),
            ),
          );
        },
        child: _buildTextPair(),
      ),
    );
  }

  Widget _buildTextPair() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
        ),

        SizedBox(
          width: widget.spacing,
        ),

        Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
        ),
      ],
    );
  }
}