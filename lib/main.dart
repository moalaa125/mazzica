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

// ألوان الهوية — موحدة في مكان واحد عشان تتستخدم في كل الشاشات
class AppColors {
  static const bg = Color(0xFF0E0F12);
  static const surface = Color(0xFF1A1B20);
  static const lime = Color(0xFFC6FF3D);
  static const coral = Color(0xFFFF5C7A);
  static const violet = Color(0xFF8A5CFF);
  static const textPrimary = Color(0xFFF5F5F0);
  static const textSecondary = Color(0xFF8A8A8F);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Music في المنتصف وهو نقطة البداية
  int _tab = 1;

  late final List<Widget> pages = [
    _PlaceholderPage(label: 'Explore', icon: CupertinoIcons.compass),
    const MusicScreen(),
    _PlaceholderPage(label: 'Files', icon: CupertinoIcons.folder),
  ];

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
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _tab, children: pages),
      bottomBar: GlassTabBar.bottom(
        selectedIndex: _tab,
        onTabSelected: (i) => setState(() => _tab = i),
        quality: GlassQuality.premium,
        settings: const LiquidGlassSettings(
          specularSharpness: GlassSpecularSharpness.sharp,
        ),
        selectedIconColor: AppColors.lime,
        indicatorColor: AppColors.lime.withValues(alpha: 0.18),
        tabs: const [
          GlassTab(icon: Icon(CupertinoIcons.compass), label: 'Explore'),
          GlassTab(icon: Icon(CupertinoIcons.music_note), label: 'Music'),
          GlassTab(icon: Icon(CupertinoIcons.folder), label: 'Files'),
        ],
      ),
    );
  }
}

// صفحة بسيطة مؤقتة للتابين التانيين لحد ما نصممهم بنفس التفصيل
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.lime, size: 40),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// شاشة المشغل
// ============================================================

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  bool _isPlaying = false;

  // قيم تجريبية للإيكولايزر (5 نطاقات)، من 0.0 لـ 1.0
  final List<double> _eqValues = [0.55, 0.4, 0.75, 0.3, 0.6];
  final List<String> _eqLabels = ['60Hz', '230Hz', '910Hz', '3.6k', '14k'];

  int _selectedPreset = 0;
  final List<String> _presets = ['Deep Bass', 'Clear Vocals', 'Flat'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // موجة صوتية (Hero art) — رسم مقصود بدل صورة غلاف
            _WaveformArt(isPlaying: _isPlaying),

            const SizedBox(height: 24),

            // عنوان الأغنية + الفنان — محاذاة يسار مش نص كسر للتماثل
            const Text(
              'Night Drive',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Unknown Artist',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),

            const SizedBox(height: 20),

            // شريط التقدم
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.35,
                minHeight: 4,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation(AppColors.lime),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1:12',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '3:24',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // أزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(
                  CupertinoIcons.shuffle,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                const Icon(
                  CupertinoIcons.backward_fill,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                GestureDetector(
                  onTap: () => setState(() => _isPlaying = !_isPlaying),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      color: AppColors.bg,
                      size: 30,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.forward_fill,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                const Icon(
                  CupertinoIcons.repeat,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),

            const SizedBox(height: 36),

            // الإيكولايزر
            const Text(
              'Equalizer',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_eqValues.length, (i) {
                  return _EqSlider(
                    value: _eqValues[i],
                    label: _eqLabels[i],
                    onChanged: (v) => setState(() => _eqValues[i] = v),
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // Presets قابلة للمشاركة
            const Text(
              'Presets',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: List.generate(_presets.length, (i) {
                final selected = i == _selectedPreset;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPreset = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.lime : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _presets[i],
                          style: TextStyle(
                            color: selected
                                ? AppColors.bg
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.share,
                            size: 13,
                            color: AppColors.bg,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// موجة صوتية مرسومة بديلة عن غلاف الأغنية
class _WaveformArt extends StatelessWidget {
  const _WaveformArt({required this.isPlaying});
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(double.infinity, 90),
        painter: _WaveformPainter(isPlaying: isPlaying),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.isPlaying});
  final bool isPlaying;

  // ارتفاعات ثابتة تعطي شكل موجة، بدل عشوائية تتغير كل مرة
  static const List<double> _heights = [
    0.3, 0.6, 0.4, 0.9, 0.5, 0.7, 0.35, 0.8, 0.45, 0.65,
    0.3, 0.55, 0.75, 0.4, 0.6, 0.85, 0.5, 0.3, 0.7, 0.45,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _heights.length;
    final barWidth = size.width / (barCount * 2);
    final gradientColors = [AppColors.lime, AppColors.coral, AppColors.violet];

    for (int i = 0; i < barCount; i++) {
      final t = i / (barCount - 1);
      final color = Color.lerp(
        Color.lerp(gradientColors[0], gradientColors[1], (t * 2).clamp(0, 1)),
        gradientColors[2],
        ((t - 0.5) * 2).clamp(0, 1),
      )!;

      final barHeight = size.height * _heights[i];
      final dx = i * barWidth * 2 + barWidth / 2;
      final paint = Paint()
        ..color = color.withValues(alpha: isPlaying ? 1.0 : 0.5)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth * 0.8;

      canvas.drawLine(
        Offset(dx, size.height / 2 - barHeight / 2),
        Offset(dx, size.height / 2 + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.isPlaying != isPlaying;
}

// سلايدر عمودي واحد للإيكولايزر
class _EqSlider extends StatelessWidget {
  const _EqSlider({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final double value;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.lime,
                inactiveTrackColor: AppColors.surface,
                thumbColor: AppColors.lime,
                trackHeight: 22,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                ),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
        ),
      ],
    );
  }
}