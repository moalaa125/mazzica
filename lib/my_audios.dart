import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';
import 'package:mazzica/cubits/audio_library_state.dart';
import 'package:mazzica/cubits/player_cubit.dart';
import 'package:mazzica/models/audio_track.dart';

class MyAudios extends StatelessWidget {
  const MyAudios({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Saved audios',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18.sp,
          ),
        ),
        backgroundColor: AppColors.surface.withValues(alpha: 0.8),
      ),
      child: SafeArea(
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
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
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
        context.read<AudioLibraryCubit>().deleteTrack(track);
      },
      child: GestureDetector(
        onTap: () async {
          final libCubit = context.read<AudioLibraryCubit>();
          final playerCubit = context.read<PlayerCubit>();
          final filePath = await libCubit.getFilePath(track.fileName);
          await playerCubit.playFromLibrary(filePath, track.title);
          if (context.mounted) Navigator.pop(context);
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
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
                    Text(
                      track.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${track.addedAt.day}/${track.addedAt.month}/${track.addedAt.year}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: AppColors.textSecondary,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}