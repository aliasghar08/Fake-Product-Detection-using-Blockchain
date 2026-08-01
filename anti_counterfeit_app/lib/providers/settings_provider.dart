import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _pushNotifications = true;
  bool _emailAlerts = false;

  ThemeMode get themeMode => _themeMode;
  bool get pushNotifications => _pushNotifications;
  bool get emailAlerts => _emailAlerts;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void setPushNotifications(bool value) {
    if (_pushNotifications != value) {
      _pushNotifications = value;
      notifyListeners();
    }
  }

  void setEmailAlerts(bool value) {
    if (_emailAlerts != value) {
      _emailAlerts = value;
      notifyListeners();
    }
  }
}

class SettingsScope extends InheritedNotifier<SettingsProvider> {
  const SettingsScope({
    super.key,
    required SettingsProvider super.notifier,
    required super.child,
  });

  static SettingsProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
  }
}
