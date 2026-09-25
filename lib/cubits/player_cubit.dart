import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mazzica/main.dart';
import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerAppState> {
  PlayerCubit() : super(const PlayerAppState()) {
    _init();
  }

  get player => audioHandler.player;

  void _init() {
    player.playerStateStream.listen((playerState) {
      emit(state.copyWith(
        isPlaying: playerState.playing,
        processingState: playerState.processingState,
      ));
    });

    player.positionStream.listen((position) {
      emit(state.copyWith(position: position));
    });

    player.durationStream.listen((duration) {
      emit(state.copyWith(duration: duration ?? Duration.zero));
    });
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
    audioHandler.seek(newPosition > state.duration ? state.duration : newPosition);
  }

  void seekBackward10() {
    final newPosition = state.position - const Duration(seconds: 10);
    audioHandler.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

}