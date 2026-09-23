import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/home_screen.dart';
import 'package:audio_service/audio_service.dart';
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
    return ScreenUtilInit(
      designSize: const Size(412, 915),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Mazzica',
          builder: (context, child) =>
              Material(type: MaterialType.transparency, child: child!),
          theme: ThemeData.dark(),
          home: const HomeScreen(),
        );
      },
    );
  }
}
