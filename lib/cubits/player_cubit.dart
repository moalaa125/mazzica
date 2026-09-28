import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';
import 'package:mazzica/main.dart';
import 'package:mazzica/services/audio_storage_service.dart';
import 'player_state.dart';
import 'package:haudiotagger/haudiotagger.dart';
import 'package:path/path.dart' as p;

class PlayerCubit extends Cubit<PlayerAppState> {
  final AudioLibraryCubit _libraryCubit;
  final AudioStorageService _storageService;
  int _currentTrackIndex = -1;

  PlayerCubit(this._libraryCubit, this._storageService)
      : super(const PlayerAppState()) {
    _init();
  }

  get player => audioHandler.player;

  void _init() {
    audioHandler.onSkipToNext = () => playNext();
    audioHandler.onSkipToPrevious = () => playPrevious();

    player.playerStateStream.listen((playerState) {
      final isCompleted =
          playerState.processingState == ProcessingState.completed;

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
      if (duration != null && duration > Duration.zero) {
        emit(state.copyWith(duration: duration));
      }
    });

    _restoreLastPlayedTrack();
  }

  Future<void> _restoreLastPlayedTrack() async {
    try {
      final lastTrack = await _storageService.getLastPlayedTrack();
      if (lastTrack != null) {
        final filePath = await _storageService.getFilePath(lastTrack.fileName);
        final file = File(filePath);
        if (await file.exists()) {
          final tracks = await _storageService.loadTracks();
          _currentTrackIndex = tracks.indexWhere((t) => t.id == lastTrack.id);

          emit(state.copyWith(
            title: lastTrack.title,
            position: Duration.zero,
          ));

          await player.stop();
          final duration = await player.setFilePath(filePath);
          await audioHandler.updateCurrentTrackInfo(lastTrack.title, duration: duration);
          if (duration != null) {
            emit(state.copyWith(duration: duration));
          }
        }
      }
    } catch (_) {}
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
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.audio,
      );

      if (files.isNotEmpty && files.single.path != null) {
        final path = files.single.path!;
        String title = p.basenameWithoutExtension(path);

        try {
          final tag = await Haudiotagger.read(path);
          if (tag != null && tag.title != null && tag.title!.trim().isNotEmpty) {
            title = tag.title!;
          }
        } catch (_) {}

        emit(state.copyWith(
          title: title,
          position: Duration.zero,
        ));

        final savedTrack = await _libraryCubit.saveTrack(sourcePath: path, title: title);

        await player.stop();
        final duration = await player.setFilePath(path);
        await audioHandler.updateCurrentTrackInfo(title, duration: duration);
        await audioHandler.play();

        emit(state.copyWith(
          title: title,
          duration: duration ?? Duration.zero,
        ));

        _currentTrackIndex = 0;
        if (savedTrack != null) {
          await _storageService.saveLastPlayedTrackId(savedTrack.id);
        }
      }
    } catch (_) {}
  }

  Future<void> playFromLibrary(String filePath, String title) async {
    try {
      emit(state.copyWith(
        title: title,
        position: Duration.zero,
      ));

      final file = File(filePath);
      if (!await file.exists()) return;

      final tracks = await _storageService.loadTracks();
      _currentTrackIndex = tracks.indexWhere((t) => t.title == title);

      await player.stop();
      final duration = await player.setFilePath(filePath);
      await audioHandler.updateCurrentTrackInfo(title, duration: duration);
      await audioHandler.play();

      emit(state.copyWith(
        title: title,
        duration: duration ?? Duration.zero,
      ));

      if (_currentTrackIndex != -1) {
        await _storageService.saveLastPlayedTrackId(tracks[_currentTrackIndex].id);
      }
    } catch (_) {}
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