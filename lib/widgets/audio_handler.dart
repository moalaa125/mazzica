import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mazzica/models/audio_track.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  late final Future<void> ready;

  StreamSubscription<PlaybackEvent>? _playbackSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  AudioPlayer get player => _player;

  List<AudioTrack> _tracks = [];
  List<String> _filePaths = [];
  List<MediaItem> _mediaItems = [];

  MyAudioHandler() {
    ready = _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;

    await session.configure(const AudioSessionConfiguration.music());

    _playbackSubscription = _player.playbackEventStream.listen(_broadcastState);

    _durationSubscription = _player.durationStream.listen(
      _updateCurrentMediaDuration,
    );
  }

  Future<Duration?> setQueue({
    required List<AudioTrack> tracks,
    required List<String> filePaths,
    required int initialIndex,
  }) async {
    await ready;

    if (tracks.isEmpty) {
      await clearQueue();
      return null;
    }

    if (tracks.length != filePaths.length) {
      throw ArgumentError('tracks and filePaths must have the same length.');
    }

    if (initialIndex < 0 || initialIndex >= tracks.length) {
      throw RangeError.index(initialIndex, tracks, 'initialIndex');
    }

    final queueChanged = !_sameQueue(tracks, filePaths);

    if (queueChanged) {
      _tracks = List<AudioTrack>.from(tracks);
      _filePaths = List<String>.from(filePaths);

      _mediaItems = List<MediaItem>.generate(tracks.length, (index) {
        final track = tracks[index];

        return MediaItem(id: track.id, title: track.title);
      });

      queue.add(List<MediaItem>.from(_mediaItems));

      final sources = List<AudioSource>.generate(tracks.length, (index) {
        return AudioSource.file(filePaths[index], tag: _mediaItems[index]);
      });

      final duration = await _player.setAudioSources(
        sources,
        initialIndex: initialIndex,
        initialPosition: Duration.zero,
        preload: true,
      );

      await _player.setLoopMode(LoopMode.all);

      _broadcastCurrentMediaItem(initialIndex);

      return duration;
    }

    await _player.seek(Duration.zero, index: initialIndex);

    _broadcastCurrentMediaItem(initialIndex);

    return _player.duration;
  }

  bool _sameQueue(List<AudioTrack> tracks, List<String> filePaths) {
    if (tracks.length != _tracks.length) {
      return false;
    }

    if (filePaths.length != _filePaths.length) {
      return false;
    }

    for (var i = 0; i < tracks.length; i++) {
      if (tracks[i].id != _tracks[i].id) {
        return false;
      }

      if (filePaths[i] != _filePaths[i]) {
        return false;
      }
    }

    return true;
  }

  Future<void> clearQueue() async {
    await ready;

    _tracks = [];
    _filePaths = [];
    _mediaItems = [];

    await _player.stop();
    await _player.clearAudioSources();

    queue.add(const []);
    mediaItem.add(null);

    playbackState.add(
      playbackState.value.copyWith(
        queueIndex: null,
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
  }

  void _broadcastCurrentMediaItem(int index) {
    if (index < 0 || index >= _mediaItems.length) {
      return;
    }

    mediaItem.add(_mediaItems[index]);
  }

  Future<void> updateCurrentTrackInfo(
    String trackId,
    String title, {
    Duration? duration,
  }) async {
    await ready;

    final index = _tracks.indexWhere((track) => track.id == trackId);

    if (index == -1) {
      return;
    }

    final updatedItem = _mediaItems[index].copyWith(
      title: title,
      duration: duration ?? _mediaItems[index].duration,
    );

    _mediaItems[index] = updatedItem;

    queue.add(List<MediaItem>.from(_mediaItems));

    if (_player.currentIndex == index) {
      mediaItem.add(updatedItem);
    }
  }

  void _updateCurrentMediaDuration(Duration? duration) {
    if (duration == null) {
      return;
    }

    final index = _player.currentIndex;

    if (index == null || index < 0 || index >= _mediaItems.length) {
      return;
    }

    final currentItem = _mediaItems[index];

    if (currentItem.duration == duration) {
      return;
    }

    final updatedItem = currentItem.copyWith(duration: duration);

    _mediaItems[index] = updatedItem;

    mediaItem.add(updatedItem);
    queue.add(List<MediaItem>.from(_mediaItems));
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

    final currentIndex = event.currentIndex;

    if (currentIndex != null &&
        currentIndex >= 0 &&
        currentIndex < _mediaItems.length) {
      final currentItem = _mediaItems[currentIndex];

      if (mediaItem.value?.id != currentItem.id) {
        mediaItem.add(currentItem);
      }
    }

    final hasQueue = _mediaItems.length > 1;

    final controls = <MediaControl>[
      if (hasQueue) MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      if (hasQueue) MediaControl.skipToNext,
    ];

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: hasQueue ? const [0, 1, 3] : const [0, 1],
        processingState: processingState,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: currentIndex,
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
  Future<void> seekForward(bool begin) async {
    await ready;

    if (!begin) {
      return;
    }

    final duration = _player.duration ?? Duration.zero;

    final newPosition = _player.position + const Duration(seconds: 10);

    await _player.seek(newPosition > duration ? duration : newPosition);
  }

  @override
  Future<void> seekBackward(bool begin) async {
    await ready;

    if (!begin) {
      return;
    }

    final newPosition = _player.position - const Duration(seconds: 10);

    await _player.seek(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
  }

  @override
  Future<void> skipToNext() async {
    await ready;

    if (_mediaItems.isEmpty) {
      return;
    }

    final currentIndex = _player.currentIndex ?? 0;

    final nextIndex = currentIndex >= _mediaItems.length - 1
        ? 0
        : currentIndex + 1;

    await skipToQueueItem(nextIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    await ready;

    if (_mediaItems.isEmpty) {
      return;
    }

    final currentIndex = _player.currentIndex ?? 0;

    final previousIndex = currentIndex <= 0
        ? _mediaItems.length - 1
        : currentIndex - 1;

    await skipToQueueItem(previousIndex);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await ready;

    if (index < 0 || index >= _mediaItems.length) {
      return;
    }

    if (_player.audioSources.isEmpty) {
      return;
    }

    await _player.seek(Duration.zero, index: index);

    _broadcastCurrentMediaItem(index);
  }

  @override
  Future<void> stop() async {
    await ready;

    await _player.stop();

    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  Future<void> dispose() async {
    await _playbackSubscription?.cancel();
    await _durationSubscription?.cancel();

    await _player.dispose();
  }
}
