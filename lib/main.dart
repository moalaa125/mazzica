import 'package:flutter/material.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlass.load(); // the shader, once; the bar falls back to blur without it
  LiquidTabBarController.shared.armGovernor();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
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
  int _tab = 0;

  final List<Widget> pages = const [
    Center(child: Text('Home Page')),
    Center(child: Text('Orders Page')),
    Center(child: Text('Wallet Page')),
    Center(child: Text('Me Page')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: LiquidTabBarController.shared.handleScroll,
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: LiquidTabBar(
        items: [
          LiquidTabItem.icon(
            label: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
          ),
          LiquidTabItem.icon(
            label: 'Orders',
            icon: Icons.receipt_long_outlined,
            badge: true,
          ),
          LiquidTabItem.icon(
            label: 'Wallet',
            icon: Icons.account_balance_wallet_outlined,
          ),
          LiquidTabItem.icon(label: 'Me', icon: Icons.person_outline),
        ],
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
      ),
    );
  }
}