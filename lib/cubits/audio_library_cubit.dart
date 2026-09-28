import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mazzica/models/audio_track.dart';
import 'package:mazzica/services/audio_storage_service.dart';
import 'audio_library_state.dart';

class AudioLibraryCubit extends Cubit<AudioLibraryState> {
  final AudioStorageService _storageService;

  AudioLibraryCubit(this._storageService)
      : super(const AudioLibraryState()) {
    loadTracks();
  }

  Future<void> loadTracks() async {
    emit(state.copyWith(status: AudioLibraryStatus.loading));
    try {
      final tracks = await _storageService.loadTracks();
      emit(state.copyWith(
        status: AudioLibraryStatus.loaded,
        tracks: tracks,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AudioLibraryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> saveTrack({
    required String sourcePath,
    required String title,
  }) async {
    try {
      final fileName = await _storageService.copyToAppDir(sourcePath);

      final track = AudioTrack(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        fileName: fileName,
        addedAt: DateTime.now(),
      );

      await _storageService.saveTrack(track);
      await loadTracks();
    } catch (_) {}
  }

  Future<void> deleteTrack(AudioTrack track) async {
    try {
      await _storageService.deleteTrack(track);
      await loadTracks();
    } catch (e) {
      emit(state.copyWith(
        status: AudioLibraryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<String> getFilePath(String fileName) {
    return _storageService.getFilePath(fileName);
  }
}