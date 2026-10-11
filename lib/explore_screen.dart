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

  // صفحة البداية الافتراضية (محرك بحث عام محايد تماماً ومقبول في المتاجر)
  final String _initialUrl = 'https://www.google.com';

  late final InAppWebViewSettings _settings;
  final Dio _dio = Dio();

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
      useOnDownloadStart: true,
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

  Future<void> _updateNavState() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      final canGoForward = await _webViewController!.canGoForward();
      if (mounted) {
        setState(() {
          _canGoBack = canGoBack;
          _canGoForward = canGoForward;
        });
      }
    }
  }

  // معالجة تنزيل الملف وحفظه داخل التطبيق
  Future<void> _downloadAndSaveFile(String fileUrl, {String? customName}) async {
    String suggestedName = customName ?? p.basename(Uri.parse(fileUrl).path);
    if (suggestedName.isEmpty || !suggestedName.contains('.')) {
      suggestedName = 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Download Media'),
        content: Text(
          'Do you want to download and import:\n"$suggestedName" to your library?',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // إظهار مؤشر تقدم التنزيل
    final progressNotifier = ValueNotifier<double>(0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (_, progress, __) => CupertinoAlertDialog(
          title: const Text('Downloading...'),
          content: Column(
            children: [
              SizedBox(height: 14.h),
              LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                valueColor: const AlwaysStoppedAnimation(AppColors.lime),
                backgroundColor: AppColors.surface,
              ),
              SizedBox(height: 8.h),
              Text(
                progress > 0
                    ? '${(progress * 100).toInt()}%'
                    : 'Connecting...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, suggestedName);

      await _dio.download(
        fileUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
          }
        },
      );

      // إغلاق نافذة التنزيل
      if (mounted) Navigator.pop(context);

      final title = p.basenameWithoutExtension(suggestedName);

      // حفظ الملف داخل مسار التطبيق ومكتبة الصوتيات
      if (mounted) {
        await context.read<AudioLibraryCubit>().saveTrack(
              sourcePath: tempPath,
              title: title,
            );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Imported "$title" to your music library!',
              style: const TextStyle(color: AppColors.lime),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.coral,
            content: Text('Download failed: $e'),
          ),
        );
      }
    }
  }

  // نافذة لإدخال رابط تنزيل مباشر يدوياً
  void _showDirectDownloadDialog() {
    final textController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Download from URL'),
        content: Padding(
          padding: EdgeInsets.only(top: 10.h),
          child: CupertinoTextField(
            controller: textController,
            placeholder: 'Paste direct audio link (e.g. .mp3)...',
            placeholderStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontSize: 12.sp,
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            cursorColor: AppColors.lime,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final url = textController.text.trim();
              Navigator.pop(ctx);
              if (url.isNotEmpty) {
                _downloadAndSaveFile(url);
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _dio.close();
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
            // شريط التنقل والبحث العلوي
            _buildTopBar(),

            // مؤشر تقدم تحميل صفحة الويب
            if (_pageProgress < 1.0)
              LinearProgressIndicator(
                value: _pageProgress,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                minHeight: 2.h,
              ),

            // متصفح الويب
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                  initialSettings: _settings,
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    if (url != null) {
                      _urlController.text = url.toString();
                    }
                    _updateNavState();
                  },
                  onLoadStop: (controller, url) {
                    if (url != null) {
                      _urlController.text = url.toString();
                    }
                    _updateNavState();
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _pageProgress = progress / 100;
                    });
                  },
                  onReceivedError: (controller, request, error) {
                    _updateNavState();
                  },
                  // 🔥 التقاط أي رابط تنزيل وسائط يتم الضغط عليه في الصفحة
                  onDownloadStartRequest: (controller, downloadRequest) {
                    _downloadAndSaveFile(
                      downloadRequest.url.toString(),
                      customName: downloadRequest.suggestedFilename,
                    );
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

          // شريط البحث والعناوين
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
                suffix: CupertinoButton(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  onPressed: () => _urlController.clear(),
                  child: Icon(
                    CupertinoIcons.clear_circled_solid,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    size: 16.sp,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: 4.w),

          // زر لصق وتنزيل رابط مباشر
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showDirectDownloadDialog,
            child: Icon(
              CupertinoIcons.arrow_down_circle,
              color: AppColors.lime,
              size: 22.sp,
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