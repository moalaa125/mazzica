import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  runApp(
    LiquidGlassWidgets.wrap(
      child: const MyApp(),
      brightnessResolver: Theme.maybeBrightnessOf,
      theme: GlassThemeData(
        dark: GlassThemeVariant(
          settings: const GlassThemeSettings(thickness: 30, blur: 8),
          quality: GlassQuality.standard,
          glowColors: GlassGlowColors(
            primary: const Color(0xFFC6FF3D),
            glowOpacity: 0.6,
          ),
        ),
        light: GlassThemeVariant(
          settings: const GlassThemeSettings(thickness: 30, blur: 8),
          quality: GlassQuality.standard,
          glowColors: GlassGlowColors(
            primary: const Color(0xFFC6FF3D),
            glowOpacity: 0.6,
          ),
        ),
      ),
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Music دلوقتي في المنتصف (index 1) وهو نقطة البداية الافتراضية
  int _tab = 1;

  static const _bg = Color(0xFF0E0F12);
  static const _surface = Color(0xFF1A1B20);
  static const _lime = Color(0xFFC6FF3D);
  static const _textPrimary = Color(0xFFF5F5F0);
  static const _textSecondary = Color(0xFF8A8A8F);

  // الترتيب اتغيّر: Explore - Music - Files
  late final List<Widget> pages = [
    _buildPage('Explore', CupertinoIcons.compass),
    _buildPage('Music', CupertinoIcons.music_note),
    _buildPage('Files', CupertinoIcons.folder),
  ];

  Widget _buildPage(String label, IconData icon) {
    return Container(
      color: _surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _lime, size: 40),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Content goes here',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E0F12), Color(0xFF1A1B20), Color(0xFF14171C)],
          ),
        ),
      ),
      backgroundColor: _bg,
      body: IndexedStack(index: _tab, children: pages),
      bottomBar: GlassTabBar.bottom(
        selectedIndex: _tab,
        onTabSelected: (i) => setState(() => _tab = i),
        quality: GlassQuality.premium,
        settings: const LiquidGlassSettings(
          specularSharpness: GlassSpecularSharpness.sharp,
        ),
        selectedIconColor: _lime,
        indicatorColor: _lime.withValues(alpha: 0.18),
        // نفس ترتيب الصفحات بالظبط: Explore - Music - Files
        tabs: const [
          GlassTab(icon: Icon(CupertinoIcons.compass), label: 'Explore'),
          GlassTab(icon: Icon(CupertinoIcons.music_note), label: 'Music'),
          GlassTab(icon: Icon(CupertinoIcons.folder), label: 'Files'),
        ],
      ),
    );
  }
}