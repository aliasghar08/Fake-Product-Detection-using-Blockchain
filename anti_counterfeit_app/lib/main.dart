import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:anti_counterfeit_app/services/blockchain_service.dart';
import 'package:anti_counterfeit_app/screens/scanner_screen.dart';
import 'package:anti_counterfeit_app/screens/manufacturer_screen.dart';
import 'package:anti_counterfeit_app/screens/retail_screen.dart';
import 'package:anti_counterfeit_app/widgets/app_drawer.dart';
import 'package:anti_counterfeit_app/providers/settings_provider.dart';

void main() {
  runApp(const AntiCounterfeitApp());
}

class AntiCounterfeitApp extends StatefulWidget {
  const AntiCounterfeitApp({super.key});

  @override
  State<AntiCounterfeitApp> createState() => _AntiCounterfeitAppState();
}

class _AntiCounterfeitAppState extends State<AntiCounterfeitApp> {
  final BlockchainService _blockchainService = BlockchainService();
  bool _isLoading = true;
  final SettingsProvider _settingsProvider = SettingsProvider();

  @override
  void initState() {
    super.initState();
    _initWeb3();
  }

  Future<void> _initWeb3() async {
    await _blockchainService.init();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      notifier: _settingsProvider,
      child: AnimatedBuilder(
        animation: _settingsProvider,
        builder: (context, child) {
          final textTheme = GoogleFonts.interTextTheme();
          
          return MaterialApp(
            title: 'BlockGuard',
            debugShowCheckedModeBanner: false,
            // ── MODERN LIGHT THEME ──────────────────────────────────────────
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4F46E5), // Indigo accent
                brightness: Brightness.light,
                surface: const Color(0xFFF8FAFC), // Cool grey background
              ),
              textTheme: textTheme,
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                scrolledUnderElevation: 0,
                titleTextStyle: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
                iconTheme: IconThemeData(color: Color(0xFF0F172A)),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: const Color(0xFFEEF2FF),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5), fontSize: 12);
                  }
                  return const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontSize: 12);
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Color(0xFF4F46E5));
                  }
                  return const IconThemeData(color: Color(0xFF64748B));
                }),
              ),
            ),
            // ── MODERN DARK THEME ───────────────────────────────────────────
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6366F1), // Bright indigo
                brightness: Brightness.dark,
                surface: const Color(0xFF0F172A), // Deep slate background
              ),
              textTheme: textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                scrolledUnderElevation: 0,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: const Color(0xFF1E293B),
                indicatorColor: const Color(0xFF3730A3).withOpacity(0.5),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF818CF8), fontSize: 12);
                  }
                  return const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF94A3B8), fontSize: 12);
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Color(0xFF818CF8));
                  }
                  return const IconThemeData(color: Color(0xFF94A3B8));
                }),
              ),
            ),
            themeMode: _settingsProvider.themeMode,
            home: _isLoading
                ? const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                    ),
                  )
                : MainNavigationScreen(
                    blockchainService: _blockchainService,
                  ),
          );
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final BlockchainService blockchainService;

  const MainNavigationScreen({
    super.key,
    required this.blockchainService,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      ScannerScreen(blockchainService: widget.blockchainService, isActive: _currentIndex == 0),
      ManufacturerScreen(blockchainService: widget.blockchainService),
      RetailerScreen(blockchainService: widget.blockchainService, isActive: _currentIndex == 2),
    ];

    final List<String> titles = [
      'Verify Product',
      'Manufacturer Portal',
      'Retailer Checkout',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Verify',
          ),
          NavigationDestination(
            icon: Icon(Icons.factory_outlined),
            selectedIcon: Icon(Icons.factory),
            label: 'Register',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Retail',
          ),
        ],
      ),
    );
  }
}
