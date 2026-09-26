import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mazzica/main.dart';
import 'player_state.dart';
import 'package:haudiotagger/haudiotagger.dart';
import 'package:path/path.dart' as p;

class PlayerCubit extends Cubit<PlayerAppState> {
  PlayerCubit() : super(const PlayerAppState()) {
    _init();
  }

  get player => audioHandler.player;

  void _init() {
    player.playerStateStream.listen((playerState) {
      emit(
        state.copyWith(
          isPlaying: playerState.playing,
          processingState: playerState.processingState,
        ),
      );
    });

    player.positionStream.listen((position) {
      emit(state.copyWith(position: position));
    });

    player.durationStream.listen((duration) {
      emit(state.copyWith(duration: duration ?? Duration.zero));
    });
  }

  Future<void> pickAndPlayFile() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.audio,
    );

    if (files.isNotEmpty && files.single.path != null) {
      final path = files.single.path!;

      await player.setFilePath(path);
      audioHandler.play();

      String title = p.basenameWithoutExtension(path); 

      try {
        final tag = await Haudiotagger.read(path);
        if (tag != null && tag.title != null && tag.title!.trim().isNotEmpty) {
          title = tag.title!;
        }
      } catch (e) {
        // 
      }

      await audioHandler.updateCurrentTrackInfo(title);

      emit(state.copyWith(title: title));
    }
  }

  void playPause() {
    if (state.isPlaying) {
      audioHandler.pause();
    } else {
      audioHandler.play();
    }
  }

  void seek(Duration position) => audioHandler.seek(position);

  void seekForward10() {
    final newPosition = state.position + const Duration(seconds: 10);
    audioHandler.seek(
      newPosition > state.duration ? state.duration : newPosition,
    );
  }

  void seekBackward10() {
    final newPosition = state.position - const Duration(seconds: 10);
    audioHandler.seek(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
  }
}