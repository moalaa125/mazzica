import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/cubits/player_cubit.dart';
import 'package:mazzica/cubits/player_state.dart';

class MiniPlayerBar extends StatelessWidget {
  final VoidCallback onTap;

  const MiniPlayerBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64.h,
        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        child: GlassContainer(
          glowIntensity: 0.15,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: BlocBuilder<PlayerCubit, PlayerAppState>(
              buildWhen: (previous, current) =>
                  previous.title != current.title ||
                  previous.isPlaying != current.isPlaying,
              builder: (context, state) {
                return Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.lime.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.music_note_2,
                        color: AppColors.lime,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.title,
                            key: ValueKey(state.currentTrackId ?? state.title),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            state.isPlaying ? 'Playing' : 'Paused',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          context.read<PlayerCubit>().playPrevious(),
                      child: Icon(
                        CupertinoIcons.backward_end_fill,
                        color: AppColors.lime,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          context.read<PlayerCubit>().playPause(),
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.lime.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          state.isPlaying
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.play_fill,
                          color: AppColors.lime,
                          size: 20.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => context.read<PlayerCubit>().playNext(),
                      child: Icon(
                        CupertinoIcons.forward_end_fill,
                        color: AppColors.lime,
                        size: 20.sp,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
