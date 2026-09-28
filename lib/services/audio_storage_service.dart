import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:mazzica/models/audio_track.dart';

class AudioStorageService {
  static const _key = 'saved_audio_tracks';

  Future<String> get _audioDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(appDir.path, 'audios'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  Future<String> copyToAppDir(String sourcePath) async {
    final dir = await _audioDir;
    final fileName = p.basename(sourcePath);
    final destPath = p.join(dir, fileName);

    if (!await File(destPath).exists()) {
      await File(sourcePath).copy(destPath);
    }
    return fileName;
  }

  Future<String> getFilePath(String fileName) async {
    final dir = await _audioDir;
    return p.join(dir, fileName);
  }

  Future<void> saveTrack(AudioTrack track) async {
    final tracks = await loadTracks();

    if (tracks.any((t) => t.fileName == track.fileName)) return;

    tracks.insert(0, track); 
    await _saveTracks(tracks);
  }

  Future<List<AudioTrack>> loadTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = json.decode(jsonStr);
    return jsonList
        .map((e) => AudioTrack.fromJson(e as Map<String, dynamic>))
        .toList();
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
  }

  Future<void> _saveTracks(List<AudioTrack> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(tracks.map((t) => t.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }
    static const _lastTrackKey = 'last_played_track_id';

  Future<void> saveLastPlayedTrackId(String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTrackKey, trackId);
  }

  Future<AudioTrack?> getLastPlayedTrack() async {
    final prefs = await SharedPreferences.getInstance();
    final trackId = prefs.getString(_lastTrackKey);
    if (trackId == null) return null;

    final tracks = await loadTracks();
    try {
      return tracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return tracks.isNotEmpty ? tracks.first : null;
    }
  }
}