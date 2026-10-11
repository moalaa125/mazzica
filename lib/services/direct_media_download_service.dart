
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DirectMediaDownloadService {
  DirectMediaDownloadService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            followRedirects: true,
            maxRedirects: 5,
          ),
        );

  final Dio _dio;

  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.opus',
    '.flac',
  };

  static const _videoExtensions = {
    '.mp4',
    '.mov',
    '.m4v',
    '.webm',
  };

  bool _isYouTubeUrl(Uri uri) {
    final host = uri.host.toLowerCase();

    return host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be' ||
        host.endsWith('.youtu.be');
  }

  Future<File> download({
    required String url,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri.tryParse(url.trim());

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw Exception('Please enter a valid HTTP or HTTPS media URL.');
    }

    if (_isYouTubeUrl(uri)) {
      throw Exception(
        'YouTube page URLs cannot be downloaded as direct media files. '
        'Use an authorized download or import workflow.',
      );
    }

    final extension = p.extension(uri.path).toLowerCase();

    if (!_audioExtensions.contains(extension) &&
        !_videoExtensions.contains(extension)) {
      throw Exception(
        'Unsupported file extension. Use a direct link to a supported '
        'audio or video file.',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final downloadsDirectory = Directory(
      p.join(directory.path, 'Downloads'),
    );

    if (!await downloadsDirectory.exists()) {
      await downloadsDirectory.create(recursive: true);
    }

    final fileName =
        'media_${DateTime.now().microsecondsSinceEpoch}$extension';

    final file = File(p.join(downloadsDirectory.path, fileName));

    try {
      final response = await _dio.download(
        uri.toString(),
        file.path,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
          headers: {
            'Accept': 'audio/*, video/*, application/octet-stream',
          },
        ),
      );

      final contentType = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();

      if (contentType == 'text/html' ||
          contentType == 'application/json' ||
          contentType == 'text/plain') {
        throw Exception(
          'The URL returned a webpage or text instead of a media file.',
        );
      }

      if (response.statusCode != 200 &&
          response.statusCode != 206) {
        throw Exception('The server did not return a complete download.');
      }

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('The downloaded file is empty.');
      }

      return file;
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  void dispose() {
    _dio.close();
  }
}
