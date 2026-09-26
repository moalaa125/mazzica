import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/custom_buttons.dart';
import 'package:mazzica/cubits/player_cubit.dart';
import 'package:mazzica/cubits/player_state.dart';
import 'package:mazzica/widgets/marquee_text.dart';
import 'package:mazzica/widgets/wave.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _tab = 1;
  double? _dragValue;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _lottieController = AnimationController(vsync: this);
  }

  Widget _buildSeekBar() {
    return BlocBuilder<PlayerCubit, PlayerAppState>(
      builder: (context, state) {
        final durationMs = state.duration.inMilliseconds.toDouble().clamp(
          1.0,
          double.infinity,
        );
        final positionMs = state.position.inMilliseconds.toDouble().clamp(
          0.0,
          durationMs,
        );
        final progress =
            _dragValue ?? (positionMs / durationMs).clamp(0.0, 1.0);

        return WaveSeekBar(
          waveCount: 2,
          progress: progress.toDouble(),
          activeColor: AppColors.lime,
          inactiveColor: AppColors.textSecondary,
          onSeek: (value) => setState(() => _dragValue = value),
          onSeekEnd: (value) {
            final seekMs = (value * durationMs).toInt();
            context.read<PlayerCubit>().seek(Duration(milliseconds: seekMs));
            setState(() => _dragValue = null);
          },
        );
      },
    );
  }

  Widget _buildPlayPauseButton() {
    return BlocBuilder<PlayerCubit, PlayerAppState>(
      builder: (context, state) {
        return CustomButtons(
          buttonIcon: state.isPlaying
              ? CupertinoIcons.pause_fill
              : CupertinoIcons.play_fill,
          iconSize: 30.sp,
          function: () => context.read<PlayerCubit>().playPause(),
          buttonSize: 80.w,
        );
      },
    );
  }

  Widget _buildPickFileButton() {
    return CustomButtons(
      buttonIcon: CupertinoIcons.folder_circle_fill,
      iconSize: 24.sp,
      buttonSize: 50.w,
      function: () => context.read<PlayerCubit>().pickAndPlayFile(),
    );
  }

  Widget _buildNextEndButton() {
    return CustomButtons(
      buttonIcon: CupertinoIcons.forward_end,
      iconSize: 24.sp,
      function: () => context.read<PlayerCubit>().seekForward10(),
      buttonSize: 50.w,
    );
  }

  Widget _buildBackEndButton() {
    return CustomButtons(
      buttonIcon: CupertinoIcons.backward_end,
      iconSize: 24.sp,
      function: () => context.read<PlayerCubit>().seekBackward10(),
      buttonSize: 50.w,
    );
  }

  Widget _buildEffectButton() {
    return GlassIconButton(
      icon: Icon(
        CupertinoIcons.slider_horizontal_3,
        color: AppColors.lime,
        size: 24.sp,
      ),
      shape: GlassIconButtonShape.circle,
      size: 50.w,
      onPressed: () {},
    );
  }

  Widget _buildFolderutton() {
    return GlassIconButton(
      icon: Icon(
        CupertinoIcons.music_note_list,
        color: AppColors.lime,
        size: 24.sp,
      ),
      shape: GlassIconButtonShape.circle,
      size: 50.w,
      onPressed: () {},
    );
  }
  Widget _buildTrackInfo() {
  return BlocBuilder<PlayerCubit, PlayerAppState>(
    builder: (context, state) {
      return SizedBox(
        width: double.infinity,
        child: MarqueeText(
          text: state.title,
          style: GoogleFonts.rammettoOne(
            fontSize: 40,
          ),
        ),
      );
    },
  );
}

  Widget _buildGlowingCover() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final strength = _glowAnimation.value;
        return Container(
          height: 350.h,
          width: 450.w,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lime),
            shape: BoxShape.circle,
            color: AppColors.bg,
            boxShadow: [
              BoxShadow(
                color: AppColors.violet.withValues(alpha: strength),
                blurRadius: 15 + (strength * 20),
                spreadRadius: -5,
              ),
              BoxShadow(
                color: AppColors.violet.withValues(alpha: strength * 0.6),
                blurRadius: 40 + (strength * 30),
              ),
              BoxShadow(
                color: AppColors.violet.withValues(alpha: strength * 0.25),
                blurRadius: 70 + (strength * 40),
                spreadRadius: 10,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Lottie.asset(
        'assets/animations/music.lottie',
        width: 100,
        height: 100,
        frameRate: FrameRate.max,
        controller: _lottieController,
        onLoaded: (composition) {
          _lottieController.duration = composition.duration;
          if (context.read<PlayerCubit>().state.isPlaying) {
            _lottieController.repeat();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerCubit, PlayerAppState>(
      listenWhen: (previous, current) =>
          previous.isPlaying != current.isPlaying,
      listener: (context, state) {
        if (state.isPlaying) {
          _glowController.repeat(reverse: true);
          _lottieController.repeat();
        } else {
          _glowController.stop();
          _lottieController.stop();
        }
      },
      child: GlassScaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 15.w, right: 15.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mazzica',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 30.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildPickFileButton(),
                      ],
                    ),
                    SizedBox(height: 15.h),
                    _buildGlowingCover(),
                    SizedBox(height: 100.h),
                    Center(child: _buildTrackInfo()),
                    SizedBox(height: 40.h),
                    Padding(
                      padding: EdgeInsets.only(left: 20.w, right: 20.w),
                      child: _buildSeekBar(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10.h),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildFolderutton(),
                            _buildBackEndButton(),
                            _buildPlayPauseButton(),
                            _buildNextEndButton(),
                            _buildEffectButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bg, AppColors.surface],
              stops: [0.6, 1.0],
            ),
          ),
        ),
        backgroundColor: AppColors.bg,
        bottomBar: GlassTabBar.bottom(
          selectedIconColor: AppColors.lime,
          indicatorColor: AppColors.lime.withValues(alpha: 0.18),
          onTabSelected: (i) => setState(() => _tab = i),
          tabs: [
            GlassTab(
              icon: Icon(CupertinoIcons.compass, size: 24.sp),
              label: 'Explore',
            ),
            GlassTab(
              icon: Icon(CupertinoIcons.music_note_2, size: 24.sp),
              label: 'Music',
            ),
            GlassTab(
              icon: Icon(CupertinoIcons.folder, size: 24.sp),
              label: 'Files',
            ),
          ],
          selectedIndex: _tab,
        ),
        statusBarStyle: GlassStatusBarStyle.auto,
      ),
    );
  }
}