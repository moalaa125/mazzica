import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 1;
  final player = AudioPlayer();

  late final List<Widget> pages = [
    _buildPage('Explore', CupertinoIcons.compass),
    _buildPage('Music', CupertinoIcons.music_note),
    _buildPage('Files', CupertinoIcons.folder),
  ];

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      await player.setAsset('assets/music/AFROTO - CAPTAIN BLACK.mp3');
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // شريط التقدم بالزجاج
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

            final maxMs = duration.inMilliseconds
                .toDouble()
                .clamp(1.0, double.infinity)
                .toDouble();
            final valueMs = position.inMilliseconds
                .toDouble()
                .clamp(0.0, maxMs)
                .toDouble();

            return Column(
              children: [
                GlassSlider(
                  min: 0,
                  max: maxMs,
                  value: valueMs,
                  activeColor: AppColors.lime,
                  onChanged: (value) {
                    player.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // زرار تشغيل/إيقاف بالزجاج
  Widget _buildPlayPauseButton() {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;
        final processingState = playerState?.processingState;

        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          return SizedBox(
            width: 40.w,
            height: 40.w,
            child: const CircularProgressIndicator(color: AppColors.lime),
          );
        }

        return GlassIconButton(
          icon: Icon(
            playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
            color: AppColors.lime,
          ),
          shape: GlassIconButtonShape.circle,
          onPressed: () {
            if (playing) {
              player.pause();
            } else {
              player.play();
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: 8.w, right: 8.w),
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
              SizedBox(height: 30.h),
              Container(
                height: 350.h,
                width: 400.w,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Image.asset('assets/images/Music.png', scale: 1),
              ),
              SizedBox(height: 20.h),
              _buildSeekBar(),
              SizedBox(height: 12.h),
              Center(child: _buildPlayPauseButton()),
            ],
          ),
        ),
      ),
      background: Container(color: AppColors.bg),
      backgroundColor: AppColors.bg,
      bottomBar: GlassTabBar.bottom(
        selectedIconColor: AppColors.lime,
        indicatorColor: AppColors.lime.withValues(alpha: 0.18),
        onTabSelected: (i) => setState(() => _tab = i),
        tabs: const [
          GlassTab(icon: Icon(CupertinoIcons.compass), label: 'Explore'),
          GlassTab(icon: Icon(CupertinoIcons.music_note), label: 'Music'),
          GlassTab(icon: Icon(CupertinoIcons.folder), label: 'Files'),
        ],
        selectedIndex: _tab,
      ),
      statusBarStyle: GlassStatusBarStyle.auto,
    );
  }
}

Widget _buildPage(String label, IconData icon) {
  return Container(
    color: AppColors.surface,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.lime, size: 40.sp),
        SizedBox(height: 12.h),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Content goes here',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
      ],
    ),
  );
}
