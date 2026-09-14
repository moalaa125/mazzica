import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mazzica/constants/app_color.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 1;

  late final List<Widget> pages = [
    _buildPage('Explore', CupertinoIcons.compass),
    _buildPage('Music', CupertinoIcons.music_note),
    _buildPage('Files', CupertinoIcons.folder),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: IndexedStack(index: _tab, children: pages),
      background: Container(color: AppColors.bg),
      backgroundColor: AppColors.bg,
      bottomBar: GlassTabBar.bottom(
        selectedIconColor: AppColors.red,
        indicatorColor: AppColors.lime.withValues(alpha: 0.18),
        onTabSelected: (i) => setState(() => _tab = i),

        tabs: const [
          GlassTab(icon: Icon(CupertinoIcons.compass), label: 'Explore'),
          GlassTab(icon: Icon(CupertinoIcons.music_note), label: 'Music'),
          GlassTab(icon: Icon(CupertinoIcons.folder), label: 'Files'),
        ],
        selectedIndex: _tab,
      ),
      statusBarStyle: GlassStatusBarStyle.auto,
    );
  }
}

Widget _buildPage(String label, IconData icon) {
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
        const SizedBox(height: 4),
        const Text(
          'Content goes here',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}
