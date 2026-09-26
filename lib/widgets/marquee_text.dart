import 'dart:async';
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.speed = 40,
    this.pauseDuration = const Duration(seconds: 1),
  });

  final String text;
  final TextStyle style;
  final double speed;
  final Duration pauseDuration;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrollController.jumpTo(0);
      _startScrollingIfNeeded();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrollingIfNeeded());
  }

  void _startScrollingIfNeeded() {
    _timer?.cancel();
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return; 

    _timer = Timer(widget.pauseDuration, _scrollForward);
  }

  Future<void> _scrollForward() async {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final duration = Duration(
      milliseconds: (maxScroll / widget.speed * 1000).round(),
    );

    await _scrollController.animateTo(
      maxScroll,
      duration: duration,
      curve: Curves.linear,
    );

    await Future.delayed(widget.pauseDuration);
    if (!_scrollController.hasClients) return;

    await _scrollController.animateTo(
      0,
      duration: duration,
      curve: Curves.linear,
    );

    _timer = Timer(widget.pauseDuration, _scrollForward);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), 
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}