import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/constants/app_color.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  InAppWebViewController? _webViewController;
  final TextEditingController _urlController = TextEditingController();

  double _progress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  // الموقع الافتراضي للاستكشاف (يمكنك تغييره لأي منصة تريدها مثل SoundCloud أو غيرها)
  final String _initialUrl = 'https://soundcloud.com/discover';

  late final InAppWebViewSettings _settings;

  @override
  void initState() {
    super.initState();
    _urlController.text = _initialUrl;

    // إعدادات الـ WebView المتوافقة مع تشغيل الصوتيات في v6.1.5
    _settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: false,
      useHybridComposition: true,
      transparentBackground: true,
      supportZoom: true,
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
        // إذا كان نص بحث عادي، ابحث في Google
        formattedUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(formattedUrl)}';
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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    // مساحة سفلية لحماية المحتوى من التداخل مع المشغل السفلي
    final bottomInset = 74.h + 68.h + bottomPadding + 10.h;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. شريط التحكم والبحث العلوي
            _buildTopBar(),

            // 2. مؤشر التحميل الخطي (يظهر فقط أثناء التحميل)
            if (_progress < 1.0)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                minHeight: 2.5.h,
              ),

            // 3. متصفح الويب WebView
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
                      _progress = progress / 100;
                    });
                  },
                  onReceivedError: (controller, request, error) {
                    _updateNavState();
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
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
            onPressed: _canGoBack
                ? () {
                    _webViewController?.goBack();
                  }
                : null,
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
            onPressed: _canGoForward
                ? () {
                    _webViewController?.goForward();
                  }
                : null,
            child: Icon(
              CupertinoIcons.forward,
              color: _canGoForward
                  ? AppColors.lime
                  : AppColors.textSecondary.withValues(alpha: 0.3),
              size: 22.sp,
            ),
          ),

          SizedBox(width: 6.w),

          // شريط البحث والعناوين
          Expanded(
            child: Container(
              height: 38.h,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: CupertinoTextField(
                controller: _urlController,
                placeholder: 'Search or enter URL...',
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

          // زر إعادة التحميل
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              _webViewController?.reload();
            },
            child: Icon(
              CupertinoIcons.refresh,
              color: AppColors.lime,
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }
}