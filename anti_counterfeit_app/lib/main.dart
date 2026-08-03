import 'package:flutter/material.dart';
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
          return MaterialApp(
            title: 'Anti-Counterfeit App',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.grey[100],
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.blue,
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.black,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
            themeMode: _settingsProvider.themeMode,
            home: _isLoading
                ? const Scaffold(
                    body: Center(
                      child:
                          CircularProgressIndicator(color: Colors.blueAccent),
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
      ScannerScreen(blockchainService: widget.blockchainService),
      ManufacturerScreen(blockchainService: widget.blockchainService),
      RetailerScreen(blockchainService: widget.blockchainService),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Verify',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.factory),
            label: 'Register',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Retail',
          ),
        ],
      ),
    );
  }
}
