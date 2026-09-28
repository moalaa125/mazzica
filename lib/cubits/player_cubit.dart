import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';
import 'package:mazzica/main.dart';
import 'player_state.dart';
import 'package:haudiotagger/haudiotagger.dart';
import 'package:path/path.dart' as p;

class PlayerCubit extends Cubit<PlayerAppState> {
  final AudioLibraryCubit _libraryCubit;
  int _currentTrackIndex = -1;

  PlayerCubit(this._libraryCubit) : super(const PlayerAppState()) {
    _init();
  }

  get player => audioHandler.player;

    void _init() {
    audioHandler.onSkipToNext = () => playNext();
    audioHandler.onSkipToPrevious = () => playPrevious();

    player.playerStateStream.listen((playerState) {
      final isCompleted = playerState.processingState == ProcessingState.completed;
      
      if (isCompleted) {
        _onSongCompleted();
      }

      emit(
        state.copyWith(
          isPlaying: isCompleted ? false : playerState.playing,
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

  void _onSongCompleted() {
    final tracks = _libraryCubit.state.tracks;
    if (tracks.isNotEmpty && _currentTrackIndex != -1) {
      playNext();
    } else {
      player.seek(Duration.zero);
      player.pause();
    }
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

      await _libraryCubit.saveTrack(sourcePath: path, title: title);
      _currentTrackIndex = 0;
    }
  }

  Future<void> playFromLibrary(String filePath, String title) async {
    final tracks = _libraryCubit.state.tracks;
    _currentTrackIndex = tracks.indexWhere((t) => t.title == title);

    await player.setFilePath(filePath);
    audioHandler.play();
    await audioHandler.updateCurrentTrackInfo(title);
    emit(state.copyWith(title: title));
  }

  Future<void> playNext() async {
    final tracks = _libraryCubit.state.tracks;
    if (tracks.isEmpty) return;

    if (_currentTrackIndex < tracks.length - 1) {
      _currentTrackIndex++;
    } else {
      _currentTrackIndex = 0; 
    }

    final nextTrack = tracks[_currentTrackIndex];
    final filePath = await _libraryCubit.getFilePath(nextTrack.fileName);
    await playFromLibrary(filePath, nextTrack.title);
  }

  Future<void> playPrevious() async {
    final tracks = _libraryCubit.state.tracks;
    if (tracks.isEmpty) return;

    if (_currentTrackIndex > 0) {
      _currentTrackIndex--;
    } else {
      _currentTrackIndex = tracks.length - 1; 
    }

    final prevTrack = tracks[_currentTrackIndex];
    final filePath = await _libraryCubit.getFilePath(prevTrack.fileName);
    await playFromLibrary(filePath, prevTrack.title);
  }

  void playPause() {
    if (player.processingState == ProcessingState.completed) {
      player.seek(Duration.zero);
      audioHandler.play();
      return;
    }

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