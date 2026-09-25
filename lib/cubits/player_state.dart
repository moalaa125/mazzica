import 'package:just_audio/just_audio.dart';

class PlayerAppState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final ProcessingState processingState;

  const PlayerAppState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.processingState = ProcessingState.idle,
  });

  PlayerAppState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    ProcessingState? processingState,
  }) {
    return PlayerAppState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      processingState: processingState ?? this.processingState,
    );
  }
}
