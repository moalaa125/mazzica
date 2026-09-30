import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';
import 'package:mazzica/cubits/audio_library_state.dart';
import 'package:mazzica/cubits/player_cubit.dart';
import 'package:mazzica/cubits/player_state.dart';
import 'package:mazzica/models/audio_track.dart';
import 'package:mazzica/widgets/custom_text_filed.dart';

class MyAudios extends StatelessWidget {
  const MyAudios({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    final bottomInset = 90.h + 68.h + bottomPadding + 16.h;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      navigationBar: CupertinoNavigationBar(
        enableBackgroundFilterBlur: true,
        automaticBackgroundVisibility: true,
        middle: Text(
          'Your Audios',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
        ),
        backgroundColor: AppColors.surface.withValues(alpha: 0.8),
      ),
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<AudioLibraryCubit, AudioLibraryState>(
          builder: (context, state) {
            if (state.status == AudioLibraryStatus.loading &&
                state.tracks.isEmpty) {
              return const Center(
                child: CupertinoActivityIndicator(color: AppColors.lime),
              );
            }

            if (state.tracks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.music_note_2,
                      size: 64.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'there is no saved songs',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18.sp,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'choose a song from the files and it will be saved here',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, bottomInset),
              itemCount: state.tracks.length,
              itemBuilder: (context, index) {
                final track = state.tracks[index];
                return _AudioTile(track: track);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({required this.track});

  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerAppState>(
      buildWhen: (previous, current) =>
          previous.currentTrackId != current.currentTrackId ||
          previous.isPlaying != current.isPlaying,
      builder: (context, state) {
        final isCurrentTrack = state.currentTrackId == track.id;
        final isPlaying = isCurrentTrack && state.isPlaying;

        return Dismissible(
          key: ValueKey(track.id),
          direction: DismissDirection.endToStart,

          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20.w),
            margin: EdgeInsets.only(bottom: 8.h),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.delete,
              color: AppColors.coral,
              size: 24.sp,
            ),
          ),

          onDismissed: (_) {
            context.read<PlayerCubit>().deleteTrack(track);
          },

          child: GestureDetector(
            onTap: () async {
              await context.read<PlayerCubit>().playTrack(track);
            },

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,

              margin: EdgeInsets.only(bottom: 8.h),

              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),

              decoration: BoxDecoration(
                color: isPlaying
                    ? AppColors.lime.withValues(alpha: 0.08)
                    : AppColors.surface,

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: isPlaying
                      ? AppColors.lime.withValues(alpha: 0.55)
                      : AppColors.textSecondary.withValues(alpha: 0.1),

                  width: isPlaying ? 1.2 : 1,
                ),

                boxShadow: isPlaying
                    ? [
                        BoxShadow(
                          color: AppColors.lime.withValues(alpha: 0.08),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),

              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),

                    width: 44.w,
                    height: 44.w,

                    decoration: BoxDecoration(
                      color: isPlaying
                          ? AppColors.lime.withValues(alpha: 0.2)
                          : AppColors.lime.withValues(alpha: 0.15),

                      borderRadius: BorderRadius.circular(10),

                      border: isPlaying
                          ? Border.all(
                              color: AppColors.lime.withValues(alpha: 0.4),
                            )
                          : null,
                    ),

                    child: isPlaying
                        ? const _PlayingIndicator()
                        : Icon(
                            CupertinoIcons.play_fill,
                            color: AppColors.lime,
                            size: 20.sp,
                          ),
                  ),

                  SizedBox(width: 12.w),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 38.h, 
                          width: 350.w,
                          child: GlassTextField(
                            placeholder: 'Search songs...',
                            prefixIcon: CupertinoIcons.search,
                            suffixIcon: CupertinoIcons.xmark_circle_fill,
                            onChanged: (value) => print(value),
                          ),
                        ),
                        Text(
                          track.title,
                          style: TextStyle(
                            color: isPlaying
                                ? AppColors.lime
                                : AppColors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 4.h),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),

                          child: isPlaying
                              ? Row(
                                  key: const ValueKey('playing'),
                                  children: [
                                    Icon(
                                      CupertinoIcons.waveform,
                                      color: AppColors.lime.withValues(
                                        alpha: 0.8,
                                      ),
                                      size: 12.sp,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      'NOW PLAYING',
                                      style: TextStyle(
                                        color: AppColors.lime.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  key: const ValueKey('date'),
                                  '${track.addedAt.day}/${track.addedAt.month}/${track.addedAt.year}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.sp,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),

                    child: isPlaying
                        ? Icon(
                            CupertinoIcons.waveform,
                            key: const ValueKey('waveform'),
                            color: AppColors.lime,
                            size: 20.sp,
                          )
                        : Icon(
                            CupertinoIcons.chevron_right,
                            key: const ValueKey('arrow'),
                            color: AppColors.textSecondary,
                            size: 16.sp,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;

        final heights = [
          8 + (10 * _wave(value)),
          14 + (12 * _wave(value + 0.25)),
          10 + (14 * _wave(value + 0.5)),
          16 + (8 * _wave(value + 0.75)),
        ];

        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(
              heights.length,
              (index) => Container(
                width: 3.w,
                height: heights[index].h,
                margin: EdgeInsets.symmetric(horizontal: 1.5.w),
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _wave(double value) {
    final normalized = value % 1.0;

    if (normalized < 0.5) {
      return normalized * 2;
    }

    return 2 - (normalized * 2);
  }
}
