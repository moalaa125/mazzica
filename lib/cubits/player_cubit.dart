// lib/cubits/player_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerAppState> {
  final AudioPlayer player = AudioPlayer();

  PlayerCubit() : super(const PlayerAppState()) {
    _init();
  }

  Future<void> _init() async {
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

    try {
      await player.setAsset('assets/music/AFROTO - CAPTAIN BLACK.mp3');
    } catch (e) {
      print('error');
    }
  }

  void playPause() {
    if (state.isPlaying) {
      player.pause();
    } else {
      player.play();
    }
  }

  void seek(Duration position) => player.seek(position);

  void seekForward10() {
    final newPosition = state.position + const Duration(seconds: 10);
    player.seek(newPosition > state.duration ? state.duration : newPosition);
  }

  void seekBackward10() {
    final newPosition = state.position - const Duration(seconds: 10);
    player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  @override
  Future<void> close() {
    player.dispose();
    return super.close();
  }
}