import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mazzica/models/audio_track.dart';
import 'package:mazzica/services/audio_storage_service.dart';

import 'audio_library_state.dart';

class AudioLibraryCubit extends Cubit<AudioLibraryState> {
  final AudioStorageService _storageService;

  int _loadGeneration = 0;

  AudioLibraryCubit(this._storageService) : super(const AudioLibraryState()) {
    loadTracks();
  }

  Future<void> loadTracks() async {
    final generation = ++_loadGeneration;

    emit(state.copyWith(
      status: AudioLibraryStatus.loading,
      errorMessage: null,
    ));

    try {
      final tracks = await _storageService.loadTracks();

      if (isClosed || generation != _loadGeneration) return;

      emit(state.copyWith(
        status: AudioLibraryStatus.loaded,
        tracks: tracks,
        errorMessage: null,
      ));
    } catch (e) {
      if (isClosed || generation != _loadGeneration) return;

      emit(state.copyWith(
        status: AudioLibraryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<AudioTrack?> saveTrack({
    required String sourcePath,
    required String title,
  }) async {
    String? copiedFileName;

    try {
      copiedFileName = await _storageService.copyToAppDir(sourcePath);

      final now = DateTime.now();
      final track = AudioTrack(
        id: '${now.microsecondsSinceEpoch}',
        title: title.trim().isEmpty ? 'Unknown track' : title.trim(),
        fileName: copiedFileName,
        addedAt: now,
      );

      await _storageService.saveTrack(track);
      await loadTracks();

      return track;
    } catch (e) {
      // If metadata persistence fails after the physical copy succeeded,
      // remove the orphaned imported file.
      if (copiedFileName != null) {
        try {
          await _storageService.deleteStoredFile(copiedFileName);
        } catch (_) {
          // Preserve the original error; cleanup failure is secondary.
        }
      }

      if (!isClosed) {
        emit(state.copyWith(
          status: AudioLibraryStatus.error,
          errorMessage: e.toString(),
        ));
      }

      rethrow;
    }
  }

  Future<void> deleteTrack(AudioTrack track) async {
    try {
      await _storageService.deleteTrack(track);
      await loadTracks();
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          status: AudioLibraryStatus.error,
          errorMessage: e.toString(),
        ));
      }
      rethrow;
    }
  }

  Future<String> getFilePath(String fileName) {
    return _storageService.getFilePath(fileName);
  }
}
