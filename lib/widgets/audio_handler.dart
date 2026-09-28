import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  late final Future<void> ready;

  StreamSubscription<PlaybackEvent>? _playbackSubscription;

  AudioPlayer get player => _player;

  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  MyAudioHandler() {
    ready = _init();
  }

  Future<void> updateCurrentTrackInfo(
    String trackId,
    String title, {
    Duration? duration,
  }) async {
    await ready;

    mediaItem.add(
      MediaItem(
        id: trackId,
        title: title,
        duration: duration,
      ),
    );
  }

  Future<void> clearCurrentTrack() async {
    await ready;
    mediaItem.add(null);
    await _player.stop();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _playbackSubscription = _player.playbackEventStream.listen(
      _broadcastState,
    );
  }

  void _broadcastState(PlaybackEvent event) {
    final processingState = const {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[_player.processingState];

    if (processingState == null) {
      return;
    }

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  @override
  Future<void> play() async {
    await ready;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await ready;
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await ready;
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    await ready;
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    await ready;
    final callback = onSkipToNext;
    if (callback != null) {
      await callback();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    await ready;
    final callback = onSkipToPrevious;
    if (callback != null) {
      await callback();
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  Future<void> dispose() async {
    await _playbackSubscription?.cancel();
    await _player.dispose();
  }
}
