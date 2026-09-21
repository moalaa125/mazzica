import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/custom_buttons.dart';
import 'package:mazzica/widgets/wave.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:ui';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 1;
  final player = AudioPlayer();
  double? _dragValue;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;



  @override
  void initState() {
    super.initState();
    _loadAudio();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadAudio() async {
    try {
      await player.setAsset('assets/music/AFROTO - CAPTAIN BLACK.mp3');
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  // String _formatDuration(Duration d) {
  //   final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  //   final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  //   return '$minutes:$seconds';
  // }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, positionSnapshot) {
            var position = positionSnapshot.data ?? Duration.zero;
            if (position > duration) position = duration;

            final durationMs = duration.inMilliseconds.toDouble().clamp(
              1.0,
              double.infinity,
            );
            final positionMs = position.inMilliseconds.toDouble().clamp(
              0.0,
              durationMs,
            );
            final progress =
                _dragValue ?? (positionMs / durationMs).clamp(0.0, 1.0);

            return WaveSeekBar(
              waveCount: 3,
              progress: progress.toDouble(),
              activeColor: AppColors.lime,
              inactiveColor: AppColors.textSecondary,
              onSeek: (value) => setState(() => _dragValue = value),
              onSeekEnd: (value) {
                final seekMs = (value * durationMs).toInt();
                player.seek(Duration(milliseconds: seekMs));
                setState(() => _dragValue = null);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlayPauseButton() {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;
        // final processingState = playerState?.processingState;

        // if (processingState == ProcessingState.loading ||
        //     processingState == ProcessingState.buffering) {
        //   return SizedBox(
        //     width: 40.w,
        //     height: 40.w,
        //     child: const CircularProgressIndicator(color: AppColors.lime),
        //   );
        // }

        return CustomButtons(
          buttonIcon: playing
              ? CupertinoIcons.pause_fill
              : CupertinoIcons.play_fill,
          iconSize: 30.sp,
          function: () {
            if (playing) {
              player.pause();
            } else {
              player.play();
            }
          },
          buttonSize: 80.w,
        );
      },
    );
  }

  Widget _buildNextEndButton() {
    return CustomButtons(
      buttonIcon: CupertinoIcons.forward_end,
      iconSize: 24.sp,
      function: () {
        final newPosition = player.position + const Duration(seconds: 10);
        player.seek(
          newPosition > player.duration! ? player.duration : newPosition,
        );
      },
      buttonSize: 50.w,
    );
  }

  Widget _buildBackEndButton() {
    return CustomButtons(
      buttonIcon: CupertinoIcons.backward_end,
      iconSize: 24.sp,
      function: () {
        final newPosition = player.position - const Duration(seconds: 10);
        player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
      },
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
    return Column(
      children: [
        Text('Kaptin-Black', style: GoogleFonts.rammettoOne(fontSize: 40)),
        SizedBox(height: 2.h),
        Shimmer.fromColors(
          baseColor: AppColors.textSecondary,
          highlightColor: AppColors.textPrimary,
          child: Text(
            'AFROTO',
            style: GoogleFonts.abel(fontSize: 20, letterSpacing: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowingCover() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final strength = _glowAnimation.value;

        return Container(
          height: 400.h,
          width: 450.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.lime,
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
      child: Image.asset('assets/images/Music.png', scale: 1),
    );
  }

  @override
  void dispose() {
    player.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 15.w, right: 15.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mazzica',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 15.h),
                  _buildGlowingCover(),
                  SizedBox(height: 10.h),
                  Center(child: _buildTrackInfo()),
                  SizedBox(height: 20.h),
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
                    SizedBox(height: 15.h),
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
          background: Stack(
        fit: StackFit.expand,
        children: [
          // 1. لون الخلفية الأساسي الداكن
          Container(color: AppColors.bg),

          // 2. بقعة اللون الأولى (باللون البنفسجي) في أعلى اليسار
          Positioned(
            top: -50.h,
            left: -100.w,
            child: Container(
              width: 350.w,
              height: 350.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.violet.withValues(alpha: 0.5), // الشفافية للدمج
              ),
            ),
          ),

          // 3. بقعة اللون الثانية (باللون الليموني) في المنتصف/يمين
          Positioned(
            bottom: 100.h,
            right: -80.w,
            child: Container(
              width: 300.w,
              height: 300.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lime.withValues(alpha: 0.4),
              ),
            ),
          ),

          // 4. السحر: دمج الألوان وتذويبها معاً بضبابية عالية جداً
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0), // رقم عالي جداً لتذويب الحواف
            child: Container(
              color:  const Color(0x00000000), // هذا هو كود اللون الشفاف,
            ),
          ),
        ],
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
    );
  }
}


