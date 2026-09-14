import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

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
    return MaterialApp(
      title: 'Mazzica',
      builder: (context, child) =>
          Material(type: MaterialType.transparency, child: child!),
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}
