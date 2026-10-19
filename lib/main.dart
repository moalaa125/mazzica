import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:audio_service/audio_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/cubits/audio_library_cubit.dart';
import 'package:mazzica/cubits/player_cubit.dart';  
import 'package:mazzica/home_screen.dart';
import 'package:mazzica/services/audio_storage_service.dart';
import 'package:mazzica/widgets/audio_handler.dart';

late MyAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mazzica.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
      theme: GlassThemeData(
        dark: GlassThemeVariant(
          settings: const GlassThemeSettings(thickness: 30, blur: 8),
          glowColors: GlassGlowColors(
            primary: AppColors.lime,
            glowOpacity: 0.6,
          ),
        ),
        light: GlassThemeVariant(
          settings: const GlassThemeSettings(thickness: 30, blur: 8),
          glowColors: GlassGlowColors(
            primary: AppColors.lime,
            glowOpacity: 0.6,
          ),
        ),
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = AudioStorageService();

    return ScreenUtilInit(
      designSize: const Size(412, 915),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => AudioLibraryCubit(storageService),
            ),
            BlocProvider(
              create: (context) => PlayerCubit(
                context.read<AudioLibraryCubit>(),
                storageService,
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Mazzica',
            builder: (context, child) =>
                Material(type: MaterialType.transparency, child: child!),
            theme: ThemeData.dark(),
            home: const AppSharingHandler(
              child: HomeScreen(),
            ),
          ),
        );
      },
    );
  }
}

/// ودجت لمراقبة واستقبال مشاركات الملفات الصوتية القادمة من نظام iOS / Android
class AppSharingHandler extends StatefulWidget {
  final Widget child;
  const AppSharingHandler({super.key, required this.child});

  @override
  State<AppSharingHandler> createState() => _AppSharingHandlerState();
}

class _AppSharingHandlerState extends State<AppSharingHandler> {
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initSharingListener();
  }

  void _initSharingListener() {
    // 1. عند مشاركة ملف أثناء تشغيل التطبيق في الخلفية
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty && mounted) {
          _processSharedAudioFile(files.first.path);
        }
      },
      onError: (err) {
        debugPrint("Sharing intent stream error: $err");
      },
    );

    // 2. عند فتح التطبيق من الإغلاق التام عبر اختيار "Open In Mazzica"
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty && mounted) {
        _processSharedAudioFile(files.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  Future<void> _processSharedAudioFile(String sharedFilePath) async {
    try {
      final libraryCubit = context.read<AudioLibraryCubit>();
      final playerCubit = context.read<PlayerCubit>();

      // 1. نسخ الملف لمجلد audios الدائم وحفظه وإنشاء الـ AudioTrack
      final track = await libraryCubit.addSharedTrack(sharedFilePath);

      // 2. استدعاء دالة التشغيل في PlayerCubit (استبدل اسم الدالة إن كان مختلفاً لديك مثل playTrack)
      await playerCubit.playTrack(track);
    } catch (e) {
      debugPrint("Error processing shared audio file: $e");
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}