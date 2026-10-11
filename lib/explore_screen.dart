import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as p;

import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';
import 'package:mazzica/services/direct_media_download_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  InAppWebViewController? _webViewController;
  final TextEditingController _urlController = TextEditingController();

  final DirectMediaDownloadService _downloadService =
      DirectMediaDownloadService();

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

    final currentUrl = (await _webViewController?.getUrl())?.toString();

    if (!mounted) return;

    if (currentUrl == null || currentUrl.isEmpty) {
      _showMessage('No URL available.');
      return;
    }

    await _downloadDirectMedia(currentUrl);
  }

  Future<void> _downloadDirectMedia(String url) async {
    if (_isDownloading || !mounted) return;

    _isDownloading = true;

    final progress = ValueNotifier<double>(0);
    final status = ValueNotifier<String>('Connecting to media server...');

    var dialogOpen = false;
    var dialogClosed = false;
    File? downloadedFile;

    void closeDialog() {
      if (!dialogOpen || dialogClosed || !mounted) return;

      dialogClosed = true;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          dialogOpen = true;

          return CupertinoAlertDialog(
            title: const Text('Downloading Media'),
            content: Column(
              children: [
                SizedBox(height: 16.h),
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value > 0 ? value : null,
                    minHeight: 5,
                    backgroundColor: AppColors.surface,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.lime,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                ValueListenableBuilder<String>(
                  valueListenable: status,
                  builder: (_, value, __) => Text(
                    value,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      downloadedFile = await _downloadService.download(
        url: url,
        onProgress: (received, total) {
          if (total > 0) {
            progress.value = (received / total).clamp(0.0, 1.0);

            status.value =
                '${(progress.value * 100).toInt()}% '
                '(${(received / (1024 * 1024)).toStringAsFixed(1)} MB)';
          } else {
            status.value =
                'Downloaded ${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        },
      );

      final extension = p.extension(downloadedFile.path).toLowerCase();
      
      // Directly defined the extensions here to bypass the VS Code analyzer error
      const audioExtensions = {
        '.mp3',
        '.m4a',
        '.aac',
        '.wav',
        '.ogg',
        '.opus',
        '.flac'
      };

      if (audioExtensions.contains(extension)) {
        status.value = 'Adding audio to your library...';

        if (!mounted) return;
        await context.read<AudioLibraryCubit>().saveTrack(
          sourcePath: downloadedFile.path,
          title: p.basenameWithoutExtension(downloadedFile.path),
        );

        if (!mounted) return;
        await context.read<AudioLibraryCubit>().loadTracks();

        await downloadedFile.delete();
        downloadedFile = null;

        progress.value = 1;
        status.value = 'Download complete!';
        closeDialog();

        _showMessage('Audio saved to My Audios!');
      } else {
        progress.value = 1;
        status.value = 'Video saved successfully!';
        closeDialog();

        _showMessage('Video saved to the app Downloads directory.');
      }
    } catch (e, stackTrace) {
      debugPrint('Direct media download error: $e');
      debugPrintStack(stackTrace: stackTrace);

      closeDialog();

      if (mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Download Failed'),
            content: Text(e.toString()),
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
      closeDialog();
      progress.dispose();
      status.dispose();
      _isDownloading = false;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _downloadService.dispose();
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
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
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
                  onUpdateVisitedHistory: (controller, url, isReload) {
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
            onPressed: _canGoBack ? () => _webViewController?.goBack() : null,
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
            onPressed:
                _canGoForward ? () => _webViewController?.goForward() : null,
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
            onPressed: _isDownloading ? null : _handleDownloadCurrentPage,
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