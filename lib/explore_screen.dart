
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  InAppWebViewController? _webViewController;
  final TextEditingController _urlController = TextEditingController();

  double _pageProgress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isDownloading = false;

  final String _initialUrl = 'https://m.youtube.com';

  late final InAppWebViewSettings _settings;

  @override
  void initState() {
    super.initState();

    _urlController.text = _initialUrl;

    _settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: false,
      useHybridComposition: true,
      transparentBackground: true,
      supportZoom: true,
      applicationNameForUserAgent:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Version/16.0 Mobile/15E148 Safari/604.1',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          message,
          style: const TextStyle(color: AppColors.lime),
        ),
      ),
    );
  }

  void _loadUrl(String input) {
    String formattedUrl = input.trim();

    if (formattedUrl.isEmpty) return;

    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      if (formattedUrl.contains('.') && !formattedUrl.contains(' ')) {
        formattedUrl = 'https://$formattedUrl';
      } else {
        formattedUrl =
            'https://www.google.com/search?q=${Uri.encodeComponent(formattedUrl)}';
      }
    }

    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(formattedUrl)),
    );
  }

  Future<void> _updateNavState(WebUri? url) async {
    final controller = _webViewController;

    if (controller == null) return;

    try {
      final canGoBack = await controller.canGoBack();
      final canGoForward = await controller.canGoForward();

      if (url != null) {
        _urlController.text = url.toString();
      }

      if (!mounted) return;

      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    } catch (e) {
      debugPrint('Navigation state error: $e');
    }
  }

  Future<void> _handleDownloadCurrentPage() async {
    if (_isDownloading) return;

    final currentUrl =
        (await _webViewController?.getUrl())?.toString();

    if (currentUrl == null || currentUrl.isEmpty) {
      _showMessage('No webpage loaded.');
      return;
    }

    final uri = Uri.tryParse(currentUrl);

    if (uri == null) {
      _showMessage('Invalid webpage URL.');
      return;
    }

    final host = uri.host.toLowerCase();
    final isYouTubeHost =
        host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be';

    final isYouTubeVideo = isYouTubeHost &&
        (uri.path == '/watch' && uri.queryParameters.containsKey('v') ||
            uri.path.startsWith('/shorts/') ||
            host == 'youtu.be' && uri.pathSegments.isNotEmpty);

    if (!isYouTubeVideo) {
      _showMessage('Please open a YouTube video first.');
      return;
    }

    await _downloadAudio(currentUrl);
  }

  Future<void> _downloadAudio(String rawUrl) async {
    if (_isDownloading || !mounted) return;

    _isDownloading = true;

    final progressNotifier = ValueNotifier<double>(0.0);
    final statusText =
        ValueNotifier<String>('Getting track information...');

    var dialogOpen = false;
    var dialogClosed = false;
    var savedSuccessfully = false;
    String? tempFilePath;
    YoutubeExplode? yt;

    void closeDialog() {
      if (!dialogOpen || dialogClosed || !mounted) return;

      dialogClosed = true;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          dialogOpen = true;

          return CupertinoAlertDialog(
            title: const Text('Downloading Track'),
            content: Column(
              children: [
                SizedBox(height: 14.h),
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (_, progress, __) {
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: AppColors.surface,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                              AppColors.lime,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            color: AppColors.lime,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 8.h),
                ValueListenableBuilder<String>(
                  valueListenable: statusText,
                  builder: (_, text, __) {
                    return Text(
                      text,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );

      yt = YoutubeExplode();

      final videoId = VideoId(rawUrl);

      statusText.value = 'Getting video information...';

      final video = await yt.videos.get(videoId).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'Timed out while getting video information.',
        ),
      );

      final trackTitle = video.title.trim().isEmpty
          ? 'YouTube Audio'
          : video.title.trim();

      statusText.value = 'Finding audio stream...';

      final manifest =
          await yt.videos.streamsClient.getManifest(videoId).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Timed out while finding audio streams.',
        ),
      );

      // Prefer MP4 audio streams for compatibility with common players.
      // Fall back to another audio-only stream if MP4 is unavailable.
      final audioStreams = manifest.audioOnly.toList();

      if (audioStreams.isEmpty) {
        throw Exception('No audio-only stream is available.');
      }

      final mp4Streams = audioStreams
          .where((stream) => stream.container == StreamContainer.mp4)
          .toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

      audioStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));

      final audioStreamInfo =
          mp4Streams.isNotEmpty ? mp4Streams.first : audioStreams.first;

      statusText.value = 'Preparing audio file...';

      final tempDir = await getTemporaryDirectory();

      final extension = audioStreamInfo.container.name;

      tempFilePath = p.join(
        tempDir.path,
        'audio_${DateTime.now().microsecondsSinceEpoch}.$extension',
      );

      final file = File(tempFilePath);
      final sink = file.openWrite();

      final totalBytes = audioStreamInfo.size.totalBytes;
      var receivedBytes = 0;
      var lastProgressUpdate = DateTime.now();

      statusText.value = 'Connecting to audio stream...';

      try {
        final stream = yt.videos.streamsClient
            .get(audioStreamInfo)
            .timeout(
          const Duration(seconds: 30),
          onTimeout: (eventSink) {
            eventSink.addError(
              TimeoutException(
                'No audio data received for 30 seconds.',
              ),
            );
          },
        );

        await for (final chunk in stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          lastProgressUpdate = DateTime.now();

          if (totalBytes > 0) {
            final progress =
                (receivedBytes / totalBytes).clamp(0.0, 1.0);

            progressNotifier.value = progress;

            statusText.value =
                '${(progress * 100).toInt()}% downloaded '
                '(${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB)';
          } else {
            statusText.value =
                'Downloaded ${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB...';
          }
        }

        await sink.flush();
      } finally {
        await sink.close();
      }

      debugPrint(
        'Audio stream completed. '
        'Bytes: $receivedBytes / $totalBytes. '
        'Last update: $lastProgressUpdate',
      );

      if (receivedBytes == 0) {
        throw Exception('No audio data was received.');
      }

      if (totalBytes > 0 && receivedBytes < totalBytes) {
        throw Exception(
          'Download incomplete: received $receivedBytes of $totalBytes bytes.',
        );
      }

      progressNotifier.value = 1.0;
      statusText.value = 'Saving to your music library...';

      await context.read<AudioLibraryCubit>().saveTrack(
        sourcePath: tempFilePath,
        title: trackTitle,
      );

      await context.read<AudioLibraryCubit>().loadTracks();

      savedSuccessfully = true;

      closeDialog();

      _showMessage('Saved "$trackTitle" to My Audios!');
    } on DioException catch (e, stackTrace) {
      debugPrint('Download DioException: $e');
      debugPrintStack(stackTrace: stackTrace);

      closeDialog();

      final message = e.response?.statusCode == 403
          ? 'The audio stream was blocked (403). Please retry later.'
          : 'Download failed. Check your connection and try again.';

      if (mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Download Notice'),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Download error: $e');
      debugPrintStack(stackTrace: stackTrace);

      closeDialog();

      final message = e is TimeoutException
          ? 'The download timed out because no data arrived. Please retry.'
          : e.toString().contains('403')
              ? 'The audio stream was blocked (403). Please retry later.'
              : 'Download failed: ${e.toString()}';

      if (mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Download Notice'),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
      }
    } finally {
      yt?.close();

      if (!savedSuccessfully && tempFilePath != null) {
        try {
          final tempFile = File(tempFilePath);

          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint('Temporary file cleanup failed: $e');
        }
      }

      if (dialogOpen && !dialogClosed && mounted) {
        closeDialog();
      }

      progressNotifier.dispose();
      statusText.dispose();

      _isDownloading = false;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final bottomInset = 74.h + 68.h + bottomPadding + 10.h;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            if (_pageProgress < 1.0)
              LinearProgressIndicator(
                value: _pageProgress,
                backgroundColor: AppColors.surface,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.lime),
                minHeight: 2.h,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(_initialUrl),
                  ),
                  initialSettings: _settings,
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    _updateNavState(url);
                  },
                  onLoadStop: (controller, url) {
                    _updateNavState(url);
                  },
                  onUpdateVisitedHistory:
                      (controller, url, isReload) {
                    if (url != null) {
                      _updateNavState(url);
                    }
                  },
                  onProgressChanged: (controller, progress) {
                    if (!mounted) return;

                    setState(() {
                      _pageProgress = progress / 100;
                    });
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    final uri = navigationAction.request.url;

                    if (uri == null) {
                      return NavigationActionPolicy.CANCEL;
                    }

                    final scheme = uri.scheme.toLowerCase();

                    if (scheme != 'http' && scheme != 'https') {
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8.w,
        vertical: 8.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _canGoBack
                ? () => _webViewController?.goBack()
                : null,
            child: Icon(
              CupertinoIcons.back,
              color: _canGoBack
                  ? AppColors.lime
                  : AppColors.textSecondary.withValues(alpha: 0.3),
              size: 22.sp,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _canGoForward
                ? () => _webViewController?.goForward()
                : null,
            child: Icon(
              CupertinoIcons.forward,
              color: _canGoForward
                  ? AppColors.lime
                  : AppColors.textSecondary.withValues(alpha: 0.3),
              size: 22.sp,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Container(
              height: 36.h,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: CupertinoTextField(
                controller: _urlController,
                placeholder: 'Search or type URL...',
                placeholderStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 13.sp,
                ),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.sp,
                ),
                cursorColor: AppColors.lime,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                textInputAction: TextInputAction.go,
                onSubmitted: _loadUrl,
                prefix: Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: Icon(
                    CupertinoIcons.globe,
                    color: AppColors.lime.withValues(alpha: 0.7),
                    size: 16.sp,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            onPressed:
                _isDownloading ? null : _handleDownloadCurrentPage,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.arrow_down_to_line,
                color: AppColors.lime,
                size: 18,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _webViewController?.reload(),
            child: Icon(
              CupertinoIcons.refresh,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
          ),
        ],
      ),
    );
  }
}
