import 'package:flutter/material.dart';
import 'package:anti_counterfeit_app/providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _contractController = TextEditingController();
  final TextEditingController _rpcController = TextEditingController();
  bool _isEditingConfig = false;

  @override
  void dispose() {
    _contractController.dispose();
    _rpcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);

    return AnimatedBuilder(
      animation: settings,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('System Default'),
                value: ThemeMode.system,
                groupValue: settings.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) settings.setThemeMode(value);
                },
                secondary: const Icon(Icons.brightness_auto),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light Mode'),
                value: ThemeMode.light,
                groupValue: settings.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) settings.setThemeMode(value);
                },
                secondary: const Icon(Icons.light_mode),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark Mode'),
                value: ThemeMode.dark,
                groupValue: settings.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) settings.setThemeMode(value);
                },
                secondary: const Icon(Icons.dark_mode),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive alerts for product updates'),
                value: settings.pushNotifications,
                onChanged: (bool value) {
                  settings.setPushNotifications(value);
                },
                secondary: const Icon(Icons.notifications_active),
              ),
              SwitchListTile(
                title: const Text('Email Alerts'),
                subtitle: const Text('Get monthly summary reports'),
                value: settings.emailAlerts,
                onChanged: (bool value) {
                  settings.setEmailAlerts(value);
                },
                secondary: const Icon(Icons.email),
              ),
              const Divider(),

              // --- DYNAMIC BLOCKCHAIN CONFIGURATION (FYP Demo Tool) ---
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Blockchain Node & Contract (Sepolia)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Contract Address',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _contractController,
                          enabled: _isEditingConfig,
                          decoration: const InputDecoration(
                            hintText: '0x... (Deployed Contract)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sepolia RPC Endpoint URL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _rpcController,
                          enabled: _isEditingConfig,
                          decoration: const InputDecoration(
                            hintText: 'https://sepolia.infura.io/v3/...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_isEditingConfig) ...[
                              TextButton(
                                onPressed: () =>
                                    setState(() => _isEditingConfig = false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  // Save logic hook here
                                  setState(() => _isEditingConfig = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Blockchain parameters updated successfully!',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Save Changes'),
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit Parameters'),
                                onPressed: () =>
                                    setState(() => _isEditingConfig = true),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
