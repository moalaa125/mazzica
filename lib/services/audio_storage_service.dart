import 'dart:convert';
import 'dart:io';

import 'package:mazzica/models/audio_track.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioStorageService {
  static const _key = 'saved_audio_tracks';
  static const _lastTrackKey = 'last_played_track_id';

  Future<String> get _audioDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(appDir.path, 'audios'));

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    return audioDir.path;
  }

  /// Copies an imported audio file into permanent app-owned storage.
  ///
  /// A unique stored filename is always generated. This prevents two
  /// different source files with the same basename from sharing one file.
  Future<String> copyToAppDir(String sourcePath) async {
    if (sourcePath.trim().isEmpty) {
      throw const FileSystemException('The selected file path is empty.');
    }

    if (sourcePath.startsWith('content://')) {
      throw const FileSystemException(
        'The selected file is exposed as a content URI and cannot be '
        'copied from a filesystem path. FilePicker must provide a local path.',
      );
    }

    final source = File(sourcePath);

    if (!await source.exists()) {
      throw FileSystemException(
        'The selected audio file no longer exists.',
        sourcePath,
      );
    }

    final sourceLength = await source.length();
    if (sourceLength <= 0) {
      throw FileSystemException(
        'The selected audio file is empty.',
        sourcePath,
      );
    }

    final dir = await _audioDir;
    final originalName = p.basename(sourcePath);
    final extension = p.extension(originalName);
    final baseName = p.basenameWithoutExtension(originalName)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();

    final safeBaseName = baseName.isEmpty ? 'audio' : baseName;
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    var fileName = '${timestamp}_$safeBaseName$extension';
    var destination = File(p.join(dir, fileName));

    var suffix = 0;
    while (await destination.exists()) {
      suffix++;
      fileName = '${timestamp}_${suffix}_$safeBaseName$extension';
      destination = File(p.join(dir, fileName));
    }

    await source.copy(destination.path);

    if (!await destination.exists() || await destination.length() <= 0) {
      if (await destination.exists()) {
        await destination.delete();
      }

      throw FileSystemException(
        'The audio file could not be copied into app storage.',
        destination.path,
      );
    }

    return fileName;
  }

  Future<String> getFilePath(String fileName) async {
    if (fileName.contains('/') || fileName.contains('\\')) {
      throw const FileSystemException('Invalid stored audio filename.');
    }

    final dir = await _audioDir;
    return p.join(dir, fileName);
  }

  Future<void> saveTrack(AudioTrack track) async {
    final tracks = await loadTracks();

    if (tracks.any((t) => t.id == track.id)) {
      return;
    }

    tracks.insert(0, track);
    await _saveTracks(tracks);
  }

  Future<List<AudioTrack>> loadTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);

    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    final decoded = json.decode(jsonStr);
    if (decoded is! List) {
      throw const FormatException('Saved audio library data is invalid.');
    }

    return decoded
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException('Invalid audio track entry.');
          }

          return AudioTrack.fromJson(
            Map<String, dynamic>.from(entry),
          );
        })
        .toList();
  }

  Future<void> deleteStoredFile(String fileName) async {
    final filePath = await getFilePath(fileName);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteTrack(AudioTrack track) async {
    final filePath = await getFilePath(track.fileName);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }

    final tracks = await loadTracks();
    tracks.removeWhere((t) => t.id == track.id);
    await _saveTracks(tracks);

    final prefs = await SharedPreferences.getInstance();
    final lastTrackId = prefs.getString(_lastTrackKey);
    if (lastTrackId == track.id) {
      await prefs.remove(_lastTrackKey);
    }
  }

  Future<void> saveLastPlayedTrackId(String trackId) async {
    if (trackId.trim().isEmpty) {
      throw  ArgumentError('Track ID cannot be empty.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTrackKey, trackId);
  }

  Future<void> clearLastPlayedTrack() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastTrackKey);
  }

  Future<AudioTrack?> getLastPlayedTrack() async {
    final prefs = await SharedPreferences.getInstance();
    final trackId = prefs.getString(_lastTrackKey);

    if (trackId == null || trackId.isEmpty) {
      return null;
    }

    final tracks = await loadTracks();

    for (final track in tracks) {
      if (track.id == trackId) {
        return track;
      }
    }

    // Never silently substitute another song for the requested last song.
    await prefs.remove(_lastTrackKey);
    return null;
  }

  Future<void> _saveTracks(List<AudioTrack> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(
      tracks.map((track) => track.toJson()).toList(),
    );
    await prefs.setString(_key, jsonStr);
  }
}
