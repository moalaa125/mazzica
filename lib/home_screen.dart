import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mazzica/constants/app_color.dart';
import 'package:mazzica/explore_screen.dart';
import 'package:mazzica/local_files_screen.dart';
import 'package:mazzica/my_audios.dart';
import 'package:mazzica/widgets/player/sliding_player_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 1;

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return const ExploreScreen();
      case 1:
        return const MyAudios();
      case 2:
        return const LocalFilesScreen();

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final effectiveBottomBarHeight = 85.h + bottomPadding;

    return GlassScaffold(
      body: Stack(
        children: [
          // 1. Current Active Tab Content takes the FULL screen height so items scroll under glass
          _buildTabContent(),

          // 2. Production Sliding Player Overlay
          SlidingPlayerOverlay(bottomBarHeight: effectiveBottomBarHeight),
        ],
      ),
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bg, AppColors.surface],
            stops: [0.6, 1.0],
          ),
        ),
      ),
      backgroundColor: AppColors.bg,
      bottomBar: GlassTabBar.bottom(
        selectedIconColor: AppColors.lime,
        indicatorColor: AppColors.lime.withValues(alpha: 0.18),
        onTabSelected: (i) => setState(() => _tab = i),
        tabs: [
          GlassTab(
            icon: Icon(CupertinoIcons.compass, size: 24.sp),
            label: 'Explore',
          ),
          GlassTab(
            icon: Icon(CupertinoIcons.music_note_2, size: 24.sp),
            label: 'Music',
          ),
          GlassTab(
            icon: Icon(CupertinoIcons.folder, size: 24.sp),
            label: 'Files',
          ),
        ],
        selectedIndex: _tab,
      ),
      statusBarStyle: GlassStatusBarStyle.light,
    );
  }
}
