import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/constants/app_color.dart';
import 'mini_player_bar.dart';
import 'expanded_player_view.dart';

class SlidingPlayerOverlay extends StatefulWidget {
  final double bottomBarHeight;

  const SlidingPlayerOverlay({
    super.key,
    required this.bottomBarHeight,
  });

  @override
  State<SlidingPlayerOverlay> createState() => _SlidingPlayerOverlayState();
}

class _SlidingPlayerOverlayState extends State<SlidingPlayerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _expand() => _controller.animateTo(1.0, curve: Curves.easeOutCubic);
  void _collapse() => _controller.animateTo(0.0, curve: Curves.easeOutCubic);

  void _handleVerticalDragUpdate(DragUpdateDetails details, double totalHeight) {
    final delta = details.primaryDelta ?? 0;
    _controller.value -= delta / totalHeight;
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      _expand();
    } else if (velocity > 300) {
      _collapse();
    } else {
      if (_controller.value > 0.4) {
        _expand();
      } else {
        _collapse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final miniPlayerHeight = 68.h;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final collapsedTop = screenHeight - widget.bottomBarHeight - miniPlayerHeight;
        final currentTop = (1.0 - progress) * collapsedTop;

        return Positioned(
          left: 0,
          right: 0,
          top: currentTop.clamp(0.0, screenHeight),
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) =>
                _handleVerticalDragUpdate(details, screenHeight),
            onVerticalDragEnd: _handleVerticalDragEnd,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular((1.0 - progress) * 20),
              ),
              child: Material(
                color: progress > 0.02 ? AppColors.bg : Colors.transparent,
                child: Stack(
                  children: [
                    // 1. Expanded Player (Fixed Full Screen Size with OverflowBox to prevent RenderFlex overflow)
                    if (progress > 0.05)
                      Positioned.fill(
                        child: Opacity(
                          opacity: ((progress - 0.15) / 0.85).clamp(0.0, 1.0),
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: screenHeight,
                            maxHeight: screenHeight,
                            child: SizedBox(
                              height: screenHeight,
                              child: ExpandedPlayerView(onCollapse: _collapse),
                            ),
                          ),
                        ),
                      ),

                    // 2. Mini Player (Visible when collapsed)
                    if (progress < 0.85)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Opacity(
                          opacity: ((0.7 - progress) / 0.7).clamp(0.0, 1.0),
                          child: IgnorePointer(
                            ignoring: progress > 0.2,
                            child: MiniPlayerBar(onTap: _expand),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}