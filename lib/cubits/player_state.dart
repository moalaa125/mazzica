import 'package:just_audio/just_audio.dart';

class PlayerAppState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final ProcessingState processingState;
  final String title;
  final String? currentTrackId;
  final String? errorMessage;

  const PlayerAppState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.processingState = ProcessingState.idle,
    this.title = 'No track selected',
    this.currentTrackId,
    this.errorMessage,
  });

  static const Object _noChange = Object();

  PlayerAppState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    ProcessingState? processingState,
    String? title,
    Object? currentTrackId = _noChange,
    Object? errorMessage = _noChange,
  }) {
    return PlayerAppState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      processingState: processingState ?? this.processingState,
      title: title ?? this.title,
      currentTrackId: identical(currentTrackId, _noChange)
          ? this.currentTrackId
          : currentTrackId as String?,
      errorMessage: identical(errorMessage, _noChange)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
