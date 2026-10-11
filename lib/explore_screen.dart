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
      // منع الخروج لتطبيق يوتيوب الخارجي عبر محاكاة متصفح Safari للجوال
      applicationNameForUserAgent:
          "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
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
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      final canGoForward = await _webViewController!.canGoForward();

      if (url != null) {
        _urlController.text = url.toString();
      }

      if (mounted) {
        setState(() {
          _canGoBack = canGoBack;
          _canGoForward = canGoForward;
        });
      }
    }
  }

  // عند الضغط على زر التنزيل في الشريط العلوي
  Future<void> _handleDownloadCurrentPage() async {
    final currentUrl = (await _webViewController?.getUrl())?.toString();

    if (currentUrl == null || currentUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No webpage loaded!')),
        );
      }
      return;
    }

    // التحقق من أن الرابط هو فيديو يوتيوب أو شورتس
    final isYouTubeVideo = currentUrl.contains('watch?v=') ||
        currentUrl.contains('youtu.be/') ||
        currentUrl.contains('/shorts/');

    if (!isYouTubeVideo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Please open a YouTube video or music first to download!',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        );
      }
      return;
    }

    // بدء تنزيل الصوت
    _downloadYouTubeAudio(currentUrl);
  }

  // تنزيل تيار الصوت وحفظه
  Future<void> _downloadYouTubeAudio(String rawUrl) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusText = ValueNotifier<String>('Connecting to video...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Downloading Track'),
        content: Column(
          children: [
            SizedBox(height: 14.h),
            ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (_, progress, __) => LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                valueColor: const AlwaysStoppedAnimation(AppColors.lime),
                backgroundColor: AppColors.surface,
              ),
            ),
            SizedBox(height: 8.h),
            ValueListenableBuilder<String>(
              valueListenable: statusText,
              builder: (_, text, __) => Text(
                text,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final yt = YoutubeExplode();

    try {
      final videoId = VideoId(rawUrl);

      statusText.value = 'Fetching track details...';
      final video = await yt.videos.get(videoId).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw 'Connection timed out while fetching video details.',
      );

      statusText.value = 'Fetching audio streams...';
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw 'Connection timed out while extracting audio.',
      );

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        throw 'No standalone audio stream available for this video.';
      }

      // اختيار تيار الصوت الأعلى جودة
      final audioStreamInfo = audioStreams.withHighestBitrate();

      statusText.value = 'Starting fast download...';

      final cleanTitle = video.title
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      final tempDir = await getTemporaryDirectory();
      final tempFilePath = p.join(tempDir.path, '$cleanTitle.m4a');

      // 🔥 إعداد كائن Dio بشكل متوافق ومضمون دون أخطاء في الـ BaseOptions
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 20);
      dio.options.receiveTimeout = const Duration(seconds: 60);
      dio.options.headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://www.youtube.com/',
      };

      await dio.download(
        audioStreamInfo.url.toString(),
        tempFilePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
            statusText.value =
                '${(progressNotifier.value * 100).toInt()}% downloaded';
          } else {
            final mb = (received / (1024 * 1024)).toStringAsFixed(1);
            statusText.value = 'Downloaded $mb MB...';
          }
        },
      );

      if (mounted) Navigator.pop(context); // إغلاق الدايالوج

      // الحفظ المباشر في مكتبة التطبيق
      if (mounted) {
        await context.read<AudioLibraryCubit>().saveTrack(
              sourcePath: tempFilePath,
              title: video.title,
            );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Successfully saved: "${video.title}"',
              style: const TextStyle(color: AppColors.lime),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // إغلاق الدايالوج في حالة الخطأ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.coral,
            content: Text('Download failed: $e'),
          ),
        );
      }
    } finally {
      yt.close();
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
            // الشريط العلوي مع زر التحميل
            _buildTopBar(),

            // مؤشر تحميل الصفحة
            if (_pageProgress < 1.0)
              LinearProgressIndicator(
                value: _pageProgress,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                minHeight: 2.h,
              ),

            // المتصفح
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                  initialSettings: _settings,
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) => _updateNavState(url),
                  onLoadStop: (controller, url) => _updateNavState(url),
                  onUpdateVisitedHistory: (controller, url, isReload) {
                    if (url != null) {
                      _updateNavState(url);
                    }
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _pageProgress = progress / 100;
                    });
                  },
                  // منع الخروج من التطبيق لأي رابط خارجي
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
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
          // زر الرجوع
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

          // زر التقدم
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

          // شريط العنوان والبحث
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
                decoration: const BoxDecoration(color: Colors.transparent),
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

          // 🔥 زر التنزيل الدائم في الشريط العلوي
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            onPressed: _handleDownloadCurrentPage,
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

          // زر التحديث
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