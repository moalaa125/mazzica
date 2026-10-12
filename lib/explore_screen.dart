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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  InAppWebViewController? _webViewController;
  final TextEditingController _urlController = TextEditingController();
  final Dio _dio = Dio();

  double _pageProgress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isDownloading = false;

  static const String _initialUrl = 'https://www.google.com';
  static const Set<String> _audioExtensions = {
    '.mp3', '.m4a', '.aac', '.wav', '.ogg', '.opus', '.flac',
  };

  late final InAppWebViewSettings _settings;

  @override
  void initState() {
    super.initState();
    _urlController.text = _initialUrl;
    _settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: true,
      useHybridComposition: true,
      transparentBackground: true,
      supportZoom: true,
      javaScriptEnabled: true,
      useShouldOverrideUrlLoading: true,
      // Keep web content in this WebView. Non-http(s) app/deep links are blocked.
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(message, style: const TextStyle(color: AppColors.lime)),
      ),
    );
  }

  void _loadUrl(String input) {
    final value = input.trim();
    if (value.isEmpty) return;

    String target = value;
    final parsed = Uri.tryParse(value);
    final hasHttpScheme = parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https');

    if (!hasHttpScheme) {
      final looksLikeDomain = value.contains('.') && !value.contains(' ');
      target = looksLikeDomain
          ? 'https://$value'
          : 'https://www.google.com/search?q=${Uri.encodeQueryComponent(value)}';
    }

    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(target)),
    );
  }

  Future<void> _updateNavState(WebUri? url) async {
    final controller = _webViewController;
    if (controller == null) return;
    try {
      final back = await controller.canGoBack();
      final forward = await controller.canGoForward();
      if (url != null) _urlController.text = url.toString();
      if (!mounted) return;
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    } catch (e) {
      debugPrint('Navigation state error: $e');
    }
  }

  String _safeFileName(String proposed, String fallbackExtension) {
    var name = p.basename(proposed.trim());
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    if (name.isEmpty || name == '.' || name == '..') {
      name = 'download_${DateTime.now().millisecondsSinceEpoch}$fallbackExtension';
    }
    return name;
  }

  Future<void> _handleWebViewDownload(DownloadStartRequest request) async {
    final uri = Uri.tryParse(request.url.toString());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showMessage('This download link is not supported.');
      return;
    }

    final suggested = request.suggestedFilename?.trim() ?? '';
    final urlExtension = p.extension(uri.path).toLowerCase();
    final suggestedExtension = p.extension(suggested).toLowerCase();
    final extension = suggestedExtension.isNotEmpty
        ? suggestedExtension
        : urlExtension;
    final fallback = extension.isNotEmpty ? extension : '.bin';
    final name = _safeFileName(
      suggested.isNotEmpty ? suggested : p.basename(uri.path),
      fallback,
    );

    await _downloadFile(uri, name, expectedAudio: _audioExtensions.contains(extension));
  }

  Future<void> _downloadCurrentPage() async {
    final controller = _webViewController;
    if (controller == null || _isDownloading) return;

    final webUri = await controller.getUrl();
    if (webUri == null) {
      _showMessage('Open a download link first.');
      return;
    }

    final uri = Uri.tryParse(webUri.toString());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showMessage('This page cannot be downloaded.');
      return;
    }

    final extension = p.extension(uri.path).toLowerCase();
    if (!_audioExtensions.contains(extension)) {
      _showMessage(
        'This page is not a direct audio file. Open a legal direct audio download link instead.',
      );
      return;
    }

    final name = _safeFileName(
      p.basename(uri.path),
      extension,
    );
    await _downloadFile(uri, name, expectedAudio: true);
  }

  Future<void> _downloadFile(
    Uri uri,
    String fileName, {
    required bool expectedAudio,
  }) async {
    if (_isDownloading) {
      _showMessage('A download is already in progress.');
      return;
    }
    if (!mounted) return;

    setState(() => _isDownloading = true);
    final progress = ValueNotifier<double>(0);
    final status = ValueNotifier<String>('Connecting…');
    final cancelToken = CancelToken();
    bool dialogWasShown = false;
    bool dialogWasClosed = false;
    String? tempPath;
    var preserveDownloadedFile = false;

    void closeProgressDialog() {
      if (!dialogWasShown || dialogWasClosed || !mounted) return;
      dialogWasClosed = true;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    }

    try {
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Downloading'),
          content: Padding(
            padding: EdgeInsets.only(top: 14.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value > 0 ? value : null,
                    minHeight: 5,
                    backgroundColor: AppColors.surface,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                  ),
                ),
                SizedBox(height: 10.h),
                ValueListenableBuilder<String>(
                  valueListenable: status,
                  builder: (_, value, __) => Text(
                    value,
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
                dialogWasClosed = true;
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      dialogWasShown = true;

      final tempDir = await getTemporaryDirectory();
      tempPath = p.join(
        tempDir.path,
        '${DateTime.now().microsecondsSinceEpoch}_${_safeFileName(fileName, '.bin')}',
      );

      final response = await _dio.download(
        uri.toString(),
        tempPath,
        cancelToken: cancelToken,
        deleteOnError: true,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
          headers: const {'Accept': '*/*'},
          validateStatus: (code) => code != null && code >= 200 && code < 300,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progress.value = (received / total).clamp(0.0, 1.0);
            status.value = '${(progress.value * 100).round()}% · '
                '${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
          } else {
            status.value = 'Downloaded ${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        },
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw Exception('The server did not return a successful download.');
      }

      final file = File(tempPath);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('The downloaded file is empty.');
      }

      final contentType = response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
      if (expectedAudio &&
          (contentType.contains('text/html') || contentType.contains('application/json'))) {
        throw Exception('The link returned a webpage instead of an audio file.');
      }

      final actualExtension = p.extension(fileName).toLowerCase();
      if (expectedAudio || _audioExtensions.contains(actualExtension)) {
        status.value = 'Saving to My Audios…';
        if (!mounted) return;

        await context.read<AudioLibraryCubit>().saveTrack(
          sourcePath: tempPath,
          title: p.basenameWithoutExtension(fileName),
        );
        if (!mounted) return;
        await context.read<AudioLibraryCubit>().loadTracks();
        closeProgressDialog();
        _showMessage('Audio saved to My Audios!');
      } else {
        final downloadsDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'Downloads'));
        await downloadsDir.create(recursive: true);
        final destination = p.join(downloadsDir.path, fileName);
        final uniqueDestination = await File(destination).exists()
            ? p.join(downloadsDir.path, '${DateTime.now().millisecondsSinceEpoch}_$fileName')
            : destination;
        await file.rename(uniqueDestination);
        tempPath = uniqueDestination;
        preserveDownloadedFile = true;
        closeProgressDialog();
        _showMessage('File saved inside Mazzica: Downloads/$fileName');
      }
    } on DioException catch (e) {
      closeProgressDialog();
      if (CancelToken.isCancel(e)) {
        if (mounted) _showMessage('Download cancelled.');
      } else {
        debugPrint('Download failed: ${e.message}');
        if (mounted) _showMessage('Download failed. The link may require login or block downloads.');
      }
    } catch (e) {
      closeProgressDialog();
      debugPrint('Download failed: $e');
      if (mounted) _showMessage('Download failed: ${e.toString()}');
    } finally {
      closeProgressDialog();
      if (tempPath != null && !preserveDownloadedFile) {
        try {
          final file = File(tempPath);
          if (await file.exists()) await file.delete();
        } catch (e) {
          debugPrint('Temporary file cleanup failed: $e');
        }
      }
      progress.dispose();
      status.dispose();
      if (mounted) setState(() => _isDownloading = false);
    }
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
                  initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                  initialSettings: _settings,
                  onWebViewCreated: (controller) => _webViewController = controller,
                  onLoadStart: (controller, url) => _updateNavState(url),
                  onLoadStop: (controller, url) => _updateNavState(url),
                  onUpdateVisitedHistory: (controller, url, isReload) {
                    if (url != null) _updateNavState(url);
                  },
                  onProgressChanged: (controller, progress) {
                    if (mounted) setState(() => _pageProgress = progress / 100);
                  },
                  onDownloadStartRequest: (controller, request) {
                    _handleWebViewDownload(request);
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    if (uri == null) return NavigationActionPolicy.CANCEL;
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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
              color: _canGoBack ? AppColors.lime : AppColors.textSecondary.withValues(alpha: 0.3),
              size: 22.sp,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _canGoForward ? () => _webViewController?.goForward() : null,
            child: Icon(
              CupertinoIcons.forward,
              color: _canGoForward ? AppColors.lime : AppColors.textSecondary.withValues(alpha: 0.3),
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
                border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
              ),
              child: CupertinoTextField(
                controller: _urlController,
                placeholder: 'Search or type URL…',
                placeholderStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 13.sp,
                ),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
                cursorColor: AppColors.lime,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                decoration: const BoxDecoration(color: Colors.transparent),
                textInputAction: TextInputAction.go,
                onSubmitted: _loadUrl,
                prefix: Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: Icon(CupertinoIcons.globe, color: AppColors.lime.withValues(alpha: 0.7), size: 16.sp),
                ),
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: 7.w),
            onPressed: _isDownloading ? null : _downloadCurrentPage,
            child: _isDownloading
                ? SizedBox(
                    width: 20.sp,
                    height: 20.sp,
                    child: const CupertinoActivityIndicator(color: AppColors.lime),
                  )
                : Icon(CupertinoIcons.cloud_download, color: AppColors.lime, size: 22.sp),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _webViewController?.reload(),
            child: Icon(CupertinoIcons.refresh, color: AppColors.textSecondary, size: 18.sp),
          ),
        ],
      ),
    );
  }
}
