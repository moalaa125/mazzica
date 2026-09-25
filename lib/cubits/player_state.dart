import 'package:just_audio/just_audio.dart';

class PlayerAppState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final ProcessingState processingState;
  final String title;
  final String artist;

  const PlayerAppState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.processingState = ProcessingState.idle,
    this.title = 'No track selected',
    this.artist = '',
  });

  PlayerAppState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    ProcessingState? processingState,
    String? title,
    String? artist,
  }) {
    return PlayerAppState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      processingState: processingState ?? this.processingState,
      title: title ?? this.title,
      artist: artist ?? this.artist,
    );
  }
}