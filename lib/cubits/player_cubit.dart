import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:haudiotagger/haudiotagger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';
import 'package:mazzica/main.dart';
import 'package:mazzica/models/audio_track.dart';
import 'package:mazzica/services/audio_storage_service.dart';
import 'package:path/path.dart' as p;

import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerAppState> {
  final AudioLibraryCubit _libraryCubit;
  final AudioStorageService _storageService;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  int _currentTrackIndex = -1;
  int _operationId = 0;
  bool _completionHandled = false;
  bool _initialized = false;

  PlayerCubit(this._libraryCubit, this._storageService)
      : super(const PlayerAppState()) {
    unawaited(_init());
  }

  AudioPlayer get player => audioHandler.player;

  Future<void> _init() async {
    try {
      await audioHandler.ready;

      audioHandler.onSkipToNext = playNext;
      audioHandler.onSkipToPrevious = playPrevious;

      _subscriptions.add(
        player.playerStateStream.listen(_onPlayerStateChanged),
      );

      _subscriptions.add(
        player.positionStream.listen((position) {
          if (!isClosed) {
            emit(state.copyWith(position: position));
          }
        }),
      );

      _initialized = true;

      await _restoreLastPlayedTrack();
    } catch (e) {
      _emitError('Audio player initialization failed: $e');
    }
  }

  void _onPlayerStateChanged(PlayerState playerState) {
    if (isClosed) return;

    final isCompleted =
        playerState.processingState == ProcessingState.completed;

    if (!isCompleted) {
      _completionHandled = false;
    }

    emit(
      state.copyWith(
        isPlaying: isCompleted ? false : playerState.playing,
        processingState: playerState.processingState,
      ),
    );

    if (isCompleted && !_completionHandled) {
      _completionHandled = true;
      unawaited(_onSongCompleted());
    }
  }

  Future<void> _restoreLastPlayedTrack() async {
    if (!_initialized || isClosed) return;

    try {
      final lastTrack = await _storageService.getLastPlayedTrack();

      if (lastTrack == null || isClosed) {
        return;
      }

      final filePath =
          await _storageService.getFilePath(lastTrack.fileName);

      final file = File(filePath);

      if (!await file.exists() || await file.length() <= 0) {
        await _storageService.clearLastPlayedTrack();
        return;
      }

      final tracks = await _storageService.loadTracks();

      final index = tracks.indexWhere(
        (track) => track.id == lastTrack.id,
      );

      if (index == -1) {
        await _storageService.clearLastPlayedTrack();
        return;
      }

      final operationId = ++_operationId;

      _currentTrackIndex = index;

      emit(
        state.copyWith(
          currentTrackId: lastTrack.id,
          title: lastTrack.title,
          position: Duration.zero,
          duration: Duration.zero,
          isPlaying: false,
          processingState: ProcessingState.loading,
          errorMessage: null,
        ),
      );

      await audioHandler.ready;

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      await player.stop();

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      final duration = await player.setFilePath(filePath);

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      await audioHandler.updateCurrentTrackInfo(
        lastTrack.id,
        lastTrack.title,
        duration: duration,
      );

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      emit(
        state.copyWith(
          duration: duration ?? Duration.zero,
          processingState: player.processingState,
          errorMessage: null,
        ),
      );
    } catch (e) {
      if (!isClosed) {
        _emitError(
          'Could not restore the last track: $e',
        );
      }
    }
  }

  Future<void> _onSongCompleted() async {
    if (isClosed) return;

    final tracks = _libraryCubit.state.tracks;

    if (tracks.isNotEmpty && _currentTrackIndex >= 0) {
      await playNext();
      return;
    }

    await player.seek(Duration.zero);
    await player.pause();
  }

  Future<void> pickAndPlayFile() async {
    final operationId = ++_operationId;

    try {
      await audioHandler.ready;

      // Compatible with the file_picker version used by this project.
      final files = await FilePicker.pickFiles(
        type: FileType.audio,
      );

      if (!_isCurrentOperation(operationId) || files.isEmpty) {
        return;
      }

      final pickedFile = files.single;
      final sourcePath = pickedFile.path;

      if (sourcePath == null || sourcePath.isEmpty) {
        _emitError(
          'The selected audio file does not have a readable local path.',
          operationId: operationId,
        );
        return;
      }

      String title =
          p.basenameWithoutExtension(sourcePath).trim();

      if (title.isEmpty) {
        title = 'Unknown track';
      }

      try {
        final tag = await Haudiotagger.read(sourcePath);

        final tagTitle = tag?.title?.trim();

        if (tagTitle != null && tagTitle.isNotEmpty) {
          title = tagTitle;
        }
      } catch (_) {
        // Metadata is optional.
        // Playback should still work if tag reading fails.
      }

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      // IMPORTANT:
      // The selected file is copied into permanent app storage.
      // The temporary picker path is never passed to just_audio.
      final savedTrack = await _libraryCubit.saveTrack(
        sourcePath: sourcePath,
        title: title,
      );

      if (!_isCurrentOperation(operationId) ||
          savedTrack == null) {
        return;
      }

      final tracks = _libraryCubit.state.tracks;

      _currentTrackIndex = tracks.indexWhere(
        (track) => track.id == savedTrack.id,
      );

      await _loadAndPlayTrack(
        savedTrack,
        operationId: operationId,
      );
    } catch (e) {
      if (_isCurrentOperation(operationId)) {
        _emitError(
          'Could not import/play the selected audio file: $e',
        );
      }
    }
  }

  /// Compatibility entry point for callers that still have a stored path.
  ///
  /// New code should call [playTrack] so the stable AudioTrack ID is used.
  Future<void> playFromLibrary(
    String filePath,
    String title,
  ) async {
    final tracks = await _storageService.loadTracks();

    AudioTrack? track;

    for (final candidate in tracks) {
      final candidatePath =
          await _storageService.getFilePath(
        candidate.fileName,
      );

      if (candidatePath == filePath) {
        track = candidate;
        break;
      }
    }

    // Title is only a backwards-compatible fallback.
    // It is intentionally rejected when ambiguous.
    if (track == null) {
      final matches = tracks.where(
        (candidate) => candidate.title == title,
      );

      if (matches.length == 1) {
        track = matches.single;
      }
    }

    if (track == null) {
      _emitError(
        'The selected track could not be found in the library.',
      );
      return;
    }

    await playTrack(track);
  }

  Future<void> playTrack(AudioTrack track) async {
    final operationId = ++_operationId;

    await _loadAndPlayTrack(
      track,
      operationId: operationId,
    );
  }

  Future<void> _loadAndPlayTrack(
    AudioTrack track, {
    required int operationId,
  }) async {
    try {
      final tracks = _libraryCubit.state.tracks;

      final libraryIndex = tracks.indexWhere(
        (candidate) => candidate.id == track.id,
      );

      if (libraryIndex >= 0) {
        _currentTrackIndex = libraryIndex;
      } else {
        final storedTracks =
            await _storageService.loadTracks();

        _currentTrackIndex = storedTracks.indexWhere(
          (candidate) => candidate.id == track.id,
        );

        if (_currentTrackIndex == -1) {
          throw StateError(
            'Track is no longer in the audio library.',
          );
        }
      }

      // Update the track identity immediately.
      // Playback streams should never decide which title
      // the UI displays.
      emit(
        state.copyWith(
          currentTrackId: track.id,
          title: track.title,
          position: Duration.zero,
          duration: Duration.zero,
          isPlaying: false,
          processingState: ProcessingState.loading,
          errorMessage: null,
        ),
      );

      await audioHandler.ready;

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      final filePath =
          await _storageService.getFilePath(track.fileName);

      final file = File(filePath);

      if (!await file.exists()) {
        throw FileSystemException(
          'The stored audio file no longer exists.',
          filePath,
        );
      }

      if (await file.length() <= 0) {
        throw FileSystemException(
          'The stored audio file is empty.',
          filePath,
        );
      }

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      await player.stop();

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      // Always use the permanent app-owned path.
      final duration =
          await player.setFilePath(filePath);

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      await audioHandler.updateCurrentTrackInfo(
        track.id,
        track.title,
        duration: duration,
      );

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      emit(
        state.copyWith(
          duration: duration ?? Duration.zero,
          processingState: player.processingState,
          errorMessage: null,
        ),
      );

      await _storageService.saveLastPlayedTrackId(
        track.id,
      );

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      await audioHandler.play();

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      emit(
        state.copyWith(
          isPlaying: true,
          processingState: player.processingState,
          errorMessage: null,
        ),
      );
    } catch (e) {
      if (_isCurrentOperation(operationId)) {
        _emitError(
          'Could not play "${track.title}": $e',
        );
      }
    }
  }

  Future<void> playNext() async {
    final tracks = _libraryCubit.state.tracks;

    if (tracks.isEmpty) {
      return;
    }

    final currentId = state.currentTrackId;

    final currentIndex = currentId == null
        ? _currentTrackIndex
        : tracks.indexWhere(
            (track) => track.id == currentId,
          );

    final nextIndex =
        currentIndex < 0 ||
                currentIndex >= tracks.length - 1
            ? 0
            : currentIndex + 1;

    final nextTrack = tracks[nextIndex];

    _currentTrackIndex = nextIndex;

    await playTrack(nextTrack);
  }

  Future<void> playPrevious() async {
    final tracks = _libraryCubit.state.tracks;

    if (tracks.isEmpty) {
      return;
    }

    final currentId = state.currentTrackId;

    final currentIndex = currentId == null
        ? _currentTrackIndex
        : tracks.indexWhere(
            (track) => track.id == currentId,
          );

    final previousIndex =
        currentIndex <= 0
            ? tracks.length - 1
            : currentIndex - 1;

    final previousTrack = tracks[previousIndex];

    _currentTrackIndex = previousIndex;

    await playTrack(previousTrack);
  }

  Future<void> playPause() async {
    try {
      await audioHandler.ready;

      if (player.processingState ==
          ProcessingState.completed) {
        await player.seek(Duration.zero);
        await audioHandler.play();
        return;
      }

      if (player.playing) {
        await audioHandler.pause();
      } else {
        await audioHandler.play();
      }
    } catch (e) {
      _emitError(
        'Playback control failed: $e',
      );
    }
  }

  Future<void> seek(Duration position) async {
    try {
      final safePosition =
          position < Duration.zero
              ? Duration.zero
              : position > state.duration
                  ? state.duration
                  : position;

      await audioHandler.seek(safePosition);
    } catch (e) {
      _emitError(
        'Seek failed: $e',
      );
    }
  }

  Future<void> seekForward10() async {
    await seek(
      state.position + const Duration(seconds: 10),
    );
  }

  Future<void> seekBackward10() async {
    await seek(
      state.position - const Duration(seconds: 10),
    );
  }

  Future<void> deleteTrack(AudioTrack track) async {
    final wasCurrent =
        state.currentTrackId == track.id;

    if (wasCurrent) {
      ++_operationId;

      try {
        await audioHandler.clearCurrentTrack();
      } catch (e) {
        _emitError(
          'Could not stop the current track: $e',
        );
        return;
      }

      _currentTrackIndex = -1;

      if (!isClosed) {
        emit(
          state.copyWith(
            currentTrackId: null,
            title: 'No track selected',
            position: Duration.zero,
            duration: Duration.zero,
            isPlaying: false,
            processingState: ProcessingState.idle,
            errorMessage: null,
          ),
        );
      }
    }

    try {
      await _libraryCubit.deleteTrack(track);

      if (wasCurrent) {
        await _storageService.clearLastPlayedTrack();
      }
    } catch (e) {
      _emitError(
        'Could not delete "${track.title}": $e',
      );
    }
  }

  bool _isCurrentOperation(int operationId) {
    return !isClosed && operationId == _operationId;
  }

  void _emitError(
    String message, {
    int? operationId,
  }) {
    if (isClosed) {
      return;
    }

    if (operationId != null &&
        !_isCurrentOperation(operationId)) {
      return;
    }

    emit(
      state.copyWith(
        isPlaying: false,
        errorMessage: message,
      ),
    );
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }

    audioHandler.onSkipToNext = null;
    audioHandler.onSkipToPrevious = null;

    return super.close();
  }
}