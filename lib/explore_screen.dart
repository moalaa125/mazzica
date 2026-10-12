import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';

/// In-app browser for Mazzica.
///
/// Supported downloads:
/// - Direct media URLs that return an actual audio file.
/// - Ordinary downloadable files explicitly exposed by a website.
///
/// This intentionally does not extract audio/video streams from YouTube pages
/// or bypass a website's download restrictions.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const String _homeUrl = 'https://www.google.com';
  static const Set<String> _audioExtensions = {
    '.mp3', '.m4a', '.aac', '.wav', '.ogg', '.opus', '.flac', '.aiff', '.aif',
  };

  final TextEditingController _addressController = TextEditingController();
  final Dio _dio = Dio();

  InAppWebViewController? _webController;
  CancelToken? _activeDownload;

  double _pageProgress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isDownloading = false;
  bool _isPageLoading = true;

  late final InAppWebViewSettings _webSettings;

  @override
  void initState() {
    super.initState();
    _addressController.text = _homeUrl;
    _webSettings = InAppWebViewSettings(
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: true,
      useShouldOverrideUrlLoading: true,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: true,
      supportZoom: true,
      transparentBackground: true,
      useHybridComposition: true,
      isInspectable: kDebugMode,
      // Never hand a website's custom app/deep-link scheme to another app.
      // HTTP and HTTPS navigation is handled by shouldOverrideUrlLoading.
    );
  }

  @override
  void dispose() {
    _activeDownload?.cancel('ExploreScreen disposed');
    _addressController.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          content: Text(
            message,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
  }

  Uri? _resolveAddress(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    final parsed = Uri.tryParse(input);
    if (parsed != null &&
        (parsed.scheme.toLowerCase() == 'http' ||
            parsed.scheme.toLowerCase() == 'https') &&
        parsed.host.isNotEmpty) {
      return parsed;
    }

    // Treat a simple domain as a URL; otherwise search Google.
    final looksLikeDomain =
        !input.contains(RegExp(r'\s')) && input.contains('.') && !input.startsWith('.');
    if (looksLikeDomain) {
      final withScheme = Uri.tryParse('https://$input');
      if (withScheme != null && withScheme.host.contains('.')) return withScheme;
    }

    return Uri.https('www.google.com', '/search', {'q': input});
  }

  Future<void> _navigate(String raw) async {
    final uri = _resolveAddress(raw);
    if (uri == null) {
      _message('Enter a website or search term first.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _webController?.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
  }

  Future<void> _refreshNavigationState(WebUri? currentUrl) async {
    final controller = _webController;
    if (controller == null) return;
    try {
      final back = await controller.canGoBack();
      final forward = await controller.canGoForward();
      if (!mounted) return;
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
        if (currentUrl != null) _addressController.text = currentUrl.toString();
      });
    } catch (error) {
      debugPrint('Browser navigation state error: $error');
    }
  }

  bool _isWebUri(WebUri? webUri) {
    if (webUri == null) return false;
    final uri = Uri.tryParse(webUri.toString());
    return uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https') &&
        uri.host.isNotEmpty;
  }

  String _cleanFileName(String candidate, {String fallback = 'download.bin'}) {
    var name = p.basename(candidate.trim());
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    if (name.isEmpty || name == '.' || name == '..') name = fallback;
    // Avoid accidental hidden files and excessively long names.
    if (name.startsWith('.')) name = 'download_$name';
    if (name.length > 140) {
      final extension = p.extension(name);
      final base = p.basenameWithoutExtension(name);
      name = '${base.substring(0, base.length.clamp(0, 120).toInt())}$extension';
    }
    return name;
  }

  Future<void> _handleWebViewDownload(DownloadStartRequest request) async {
    final uri = Uri.tryParse(request.url.toString());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      _message('This download link is not supported.');
      return;
    }

    final suggestedName = request.suggestedFilename?.trim() ?? '';
    final urlExtension = p.extension(uri.path).toLowerCase();
    final suggestedExtension = p.extension(suggestedName).toLowerCase();
    final extension = suggestedExtension.isNotEmpty ? suggestedExtension : urlExtension;
    final fallbackExtension = extension.isNotEmpty ? extension : '.bin';
    final name = _cleanFileName(
      suggestedName.isNotEmpty ? suggestedName : p.basename(uri.path),
      fallback: 'download_${DateTime.now().millisecondsSinceEpoch}$fallbackExtension',
    );

    await _downloadFile(
      uri,
      name,
      expectAudio: _audioExtensions.contains(extension),
    );
  }

  Future<void> _downloadButtonPressed() async {
    if (_isDownloading) return;
    final controller = _webController;
    if (controller == null) {
      _message('The browser is still starting. Try again in a moment.');
      return;
    }

    final current = await controller.getUrl();
    if (!_isWebUri(current)) {
      _message('Open a valid web link first.');
      return;
    }

    final uri = Uri.parse(current!.toString());
    final extension = p.extension(uri.path).toLowerCase();
    if (!_audioExtensions.contains(extension)) {
      _message(
        'This page is not a direct audio file. Use a website-provided download link for audio you are allowed to save.',
      );
      return;
    }

    await _downloadFile(
      uri,
      _cleanFileName(
        p.basename(uri.path),
        fallback: 'audio_${DateTime.now().millisecondsSinceEpoch}$extension',
      ),
      expectAudio: true,
    );
  }

  Future<void> _downloadFile(
    Uri uri,
    String fileName, {
    required bool expectAudio,
  }) async {
    if (_isDownloading) {
      _message('A download is already in progress.');
      return;
    }
    if (!mounted) return;

    final progress = ValueNotifier<double>(0);
    final status = ValueNotifier<String>('Connecting to server…');
    final cancelToken = CancelToken();
    _activeDownload = cancelToken;
    setState(() => _isDownloading = true);

    bool dialogClosed = false;
    String? tempPath;
    String? finalPath;
    bool keepFile = false;

    void closeDialog() {
      if (dialogClosed || !mounted) return;
      dialogClosed = true;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    }

    try {
      // A dedicated progress dialog keeps the browser responsive and lets the
      // user cancel a slow or stalled request.
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(expectAudio ? 'Saving audio' : 'Downloading file'),
          content: Padding(
            padding: EdgeInsets.only(top: 14.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, value, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: LinearProgressIndicator(
                      value: value > 0 ? value : null,
                      minHeight: 5.h,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                ValueListenableBuilder<String>(
                  valueListenable: status,
                  builder: (_, value, __) => Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                cancelToken.cancel('Cancelled by user');
                Navigator.of(dialogContext).pop();
                dialogClosed = true;
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      final tempDirectory = await getTemporaryDirectory();
      final uniquePrefix = DateTime.now().microsecondsSinceEpoch;
      tempPath = p.join(tempDirectory.path, '${uniquePrefix}_$fileName');

      final response = await _dio.download(
        uri.toString(),
        tempPath,
        cancelToken: cancelToken,
        deleteOnError: true,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 8),
          sendTimeout: const Duration(seconds: 30),
          headers: const {'Accept': '*/*'},
          validateStatus: (code) => code != null && code >= 200 && code < 300,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final fraction = (received / total).clamp(0.0, 1.0);
            progress.value = fraction;
            status.value = '${(fraction * 100).round()}% · '
                '${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
          } else {
            status.value = 'Received ${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        },
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw Exception('The server returned HTTP $statusCode.');
      }

      final downloaded = File(tempPath);
      if (!await downloaded.exists() || await downloaded.length() == 0) {
        throw Exception('The server returned an empty file.');
      }

      final contentType =
          (response.headers.value(Headers.contentTypeHeader) ?? '').toLowerCase();
      if (contentType.contains('text/html') || contentType.contains('application/json')) {
        throw Exception('The link returned a webpage or error response, not a media file.');
      }
      if (expectAudio &&
          contentType.isNotEmpty &&
          !contentType.startsWith('audio/') &&
          !contentType.contains('octet-stream') &&
          !contentType.contains('application/mp4') &&
          !contentType.contains('video/mp4')) {
        throw Exception('The server did not return a recognized audio file.');
      }

      if (expectAudio || _audioExtensions.contains(p.extension(fileName).toLowerCase())) {
        status.value = 'Adding to My Audios…';
        if (!mounted) return;

        // saveTrack must copy the source file to persistent app storage before
        // this temporary file is removed in finally.
        await context.read<AudioLibraryCubit>().saveTrack(
              sourcePath: tempPath,
              title: p.basenameWithoutExtension(fileName),
            );
        await context.read<AudioLibraryCubit>().loadTracks();
        closeDialog();
        _message('Audio saved to My Audios.');
      } else {
        final documents = await getApplicationDocumentsDirectory();
        final downloadsDirectory = Directory(p.join(documents.path, 'Downloads'));
        await downloadsDirectory.create(recursive: true);

        var destination = p.join(downloadsDirectory.path, fileName);
        if (await File(destination).exists()) {
          destination = p.join(
            downloadsDirectory.path,
            '${DateTime.now().millisecondsSinceEpoch}_$fileName',
          );
        }
        final savedFile = await downloaded.rename(destination);
        finalPath = savedFile.path;
        keepFile = true;
        closeDialog();
        _message('File saved inside Mazzica → Downloads.');
      }
    } on DioException catch (error) {
      closeDialog();
      if (CancelToken.isCancel(error)) {
        if (mounted) _message('Download cancelled.');
      } else {
        debugPrint('Mazzica download error: ${error.message}');
        if (mounted) {
          _message('Download failed. This link may require login or block direct downloads.');
        }
      }
    } catch (error, stackTrace) {
      closeDialog();
      debugPrint('Mazzica download error: $error\n$stackTrace');
      if (mounted) _message('Could not save this file. Check that the link is a real download.');
    } finally {
      closeDialog();
      if (!keepFile && tempPath != null) {
        try {
          final file = File(tempPath);
          if (await file.exists()) await file.delete();
        } catch (error) {
          debugPrint('Temporary download cleanup error: $error');
        }
      }
      progress.dispose();
      status.dispose();
      if (identical(_activeDownload, cancelToken)) _activeDownload = null;
      if (mounted) setState(() => _isDownloading = false);
      // finalPath is intentionally retained for non-audio downloads.
      debugPrint('Saved file path: ${finalPath ?? '(audio library)'}');
    }
  }

  Future<bool> _handlePopup(CreateWindowAction action) async {
    // Sites often use target="_blank". Load ordinary web links in this same
    // WebView instead of opening another app/window.
    final target = action.request.url;
    if (_isWebUri(target)) {
      await _webController?.loadUrl(urlRequest: URLRequest(url: target));
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final reservedBottom = 74.h + 68.h + safeBottom + 10.h;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildBrowserBar(),
            SizedBox(
              height: 2.h,
              child: _isPageLoading || _pageProgress < 1
                  ? LinearProgressIndicator(
                      value: _pageProgress > 0 ? _pageProgress : null,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: reservedBottom),
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_homeUrl)),
                  initialSettings: _webSettings,
                  onWebViewCreated: (controller) => _webController = controller,
                  onLoadStart: (controller, url) {
                    if (!mounted) return;
                    setState(() {
                      _isPageLoading = true;
                      _pageProgress = 0;
                    });
                    _refreshNavigationState(url);
                  },
                  onLoadStop: (controller, url) {
                    if (!mounted) return;
                    setState(() {
                      _isPageLoading = false;
                      _pageProgress = 1;
                    });
                    _refreshNavigationState(url);
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) {
                    _refreshNavigationState(url);
                  },
                  onProgressChanged: (controller, progress) {
                    if (!mounted) return;
                    setState(() {
                      _pageProgress = progress / 100;
                      _isPageLoading = progress < 100;
                    });
                  },
                  onDownloadStartRequest: (controller, request) {
                    _handleWebViewDownload(request);
                  },
                  onCreateWindow: (controller, action) => _handlePopup(action),
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    // Keep web pages inside Mazzica; reject tel:, intent:, youtube:
                    // and other schemes that may open external applications.
                    if (!_isWebUri(uri)) return NavigationActionPolicy.CANCEL;
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

  Widget _buildBrowserBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(7.w, 8.h, 7.w, 8.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _BrowserIconButton(
            icon: CupertinoIcons.back,
            enabled: _canGoBack,
            onPressed: () => _webController?.goBack(),
            tooltip: 'Back',
          ),
          _BrowserIconButton(
            icon: CupertinoIcons.forward,
            enabled: _canGoForward,
            onPressed: () => _webController?.goForward(),
            tooltip: 'Forward',
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Container(
              height: 39.h,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.18),
                ),
              ),
              child: CupertinoTextField(
                controller: _addressController,
                placeholder: 'Search Google or enter URL',
                placeholderStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.65),
                  fontSize: 11.sp,
                ),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 11.sp),
                cursorColor: AppColors.lime,
                padding: EdgeInsets.symmetric(horizontal: 9.w),
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const BoxDecoration(color: Colors.transparent),
                prefix: Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: Icon(
                    CupertinoIcons.globe,
                    color: AppColors.lime,
                    size: 15.sp,
                  ),
                ),
                onSubmitted: _navigate,
              ),
            ),
          ),
          SizedBox(width: 3.w),
          _BrowserIconButton(
            icon: CupertinoIcons.cloud_download,
            enabled: !_isDownloading,
            highlighted: true,
            onPressed: _downloadButtonPressed,
            tooltip: _isDownloading ? 'Download in progress' : 'Download direct audio',
          ),
          _BrowserIconButton(
            icon: CupertinoIcons.refresh,
            enabled: true,
            onPressed: () => _webController?.reload(),
            tooltip: 'Reload',
          ),
        ],
      ),
    );
  }
}

class _BrowserIconButton extends StatelessWidget {
  const _BrowserIconButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.tooltip,
    this.highlighted = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final String tooltip;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (highlighted ? AppColors.lime : AppColors.textSecondary)
        : AppColors.textSecondary.withValues(alpha: 0.3);

    return Tooltip(
      message: tooltip,
      child: CupertinoButton(
        minSize: 34,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        onPressed: enabled ? onPressed : null,
        child: Icon(icon, size: highlighted ? 21.sp : 20.sp, color: color),
      ),
    );
  }
}
