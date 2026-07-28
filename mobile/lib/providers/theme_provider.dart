import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app appearance: theme mode (system/light/dark) and the seed
/// (accent) color. Choices are persisted locally per device.
class ThemeProvider with ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  Color _seed = const Color(0xFF00BFA6); // High-tech teal accent by default.

  static const String _modeKey = 'theme.mode';
  static const String _seedKey = 'theme.seed';

  /// Curated "high-tech" accent palette the user can pick from.
  static const List<Color> presetSeeds = [
    Color(0xFF00BFA6), // teal
    Color(0xFF2E7D32), // green (classic)
    Color(0xFF2962FF), // electric blue
    Color(0xFF6200EA), // deep purple
    Color(0xFF00B8D4), // cyan
    Color(0xFFEF6C00), // amber/orange
    Color(0xFFD500F9), // magenta
    Color(0xFF455A64), // slate
  ];

  ThemeProvider() {
    _load();
  }

  ThemeMode get mode => _mode;
  Color get seed => _seed;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }

  Future<void> setSeed(Color seed) async {
    if (_seed.toARGB32() == seed.toARGB32()) return;
    _seed = seed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedKey, seed.toARGB32());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_modeKey);
    final seedValue = prefs.getInt(_seedKey);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
      _mode = ThemeMode.values[modeIndex];
    }
    if (seedValue != null) {
      _seed = Color(seedValue);
    }
    notifyListeners();
  }
}
