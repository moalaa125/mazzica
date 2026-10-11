import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/constants/app_color.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _showWebView = false;
  InAppWebViewController? _webViewController;
  double _progress = 0.0;
  bool _canGoBack = false;

  late final InAppWebViewSettings _settings;

  final String _youtubeUrl = 'https://www.youtube.com';

  @override
  void initState() {
    super.initState();
    _settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: false,
      useHybridComposition: true,
      transparentBackground: true,
      supportZoom: true,
    );
  }

  Future<void> _updateNavState() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      if (mounted) setState(() => _canGoBack = canGoBack);
    }
  }

  Future<void> _handleBack() async {
    if (_canGoBack) {
      _webViewController?.goBack();
    } else {
      setState(() => _showWebView = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      child: SafeArea(
        child: _showWebView ? _buildWebView() : _buildEntryScreen(),
      ),
    );
  }

  Widget _buildEntryScreen() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h),
          Text(
            'Explore',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Browse and bring your own files into Mazzica',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _showWebView = true),
              child: Container(
                width: 220.w,
                padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 20.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: AppColors.lime.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: 0.08),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 70.w,
                      height: 70.w,
                      decoration: BoxDecoration(
                        color: AppColors.lime.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.lime.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.play_rectangle_fill,
                        color: AppColors.lime,
                        size: 32.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Open Browser',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Opens inside Mazzica',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          const Spacer(),
        ],
      ),
    );
  }


  Widget _buildWebView() {
    return Column(
      children: [
        _buildTopBar(),
        if (_progress < 1.0) _buildProgressBar(),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_youtubeUrl)),
            initialSettings: _settings,
            onWebViewCreated: (controller) => _webViewController = controller,
            onLoadStart: (controller, url) => _updateNavState(),
            onLoadStop: (controller, url) => _updateNavState(),
            onProgressChanged: (controller, progress) {
              setState(() => _progress = progress / 100);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return SizedBox(
      height: 2.5.h,
      width: double.infinity,
      child: Stack(
        children: [
          Container(color: AppColors.surface),
          FractionallySizedBox(
            widthFactor: _progress.clamp(0.0, 1.0),
            child: Container(color: AppColors.lime),
          ),
        ],
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
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _handleBack,
            child: Icon(
              CupertinoIcons.back,
              color: AppColors.lime,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'YouTube',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _webViewController?.reload(),
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