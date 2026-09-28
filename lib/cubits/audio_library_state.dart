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

  static const Object _noChange = Object();

  AudioLibraryState copyWith({
    AudioLibraryStatus? status,
    List<AudioTrack>? tracks,
    Object? errorMessage = _noChange,
  }) {
    return AudioLibraryState(
      status: status ?? this.status,
      tracks: tracks ?? this.tracks,
      errorMessage: identical(errorMessage, _noChange)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
