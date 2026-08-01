import 'package:flutter/material.dart';
import 'package:anti_counterfeit_app/providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    
    return AnimatedBuilder(
      animation: settings,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
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
            padding: EdgeInsets.all(16.0),
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
        ],
      ),
    );
      },
    );
  }
}
