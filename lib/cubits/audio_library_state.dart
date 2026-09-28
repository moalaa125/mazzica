import 'package:mazzica/models/audio_track.dart';

enum AudioLibraryStatus { initial, loading, loaded, error }

class AudioLibraryState {
  final AudioLibraryStatus status;
  final List<AudioTrack> tracks;
  final String? errorMessage;

  const AudioLibraryState({
    this.status = AudioLibraryStatus.initial,
    this.tracks = const [],
    this.errorMessage,
  });

  AudioLibraryState copyWith({
    AudioLibraryStatus? status,
    List<AudioTrack>? tracks,
    String? errorMessage,
  }) {
    return AudioLibraryState(
      status: status ?? this.status,
      tracks: tracks ?? this.tracks,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}