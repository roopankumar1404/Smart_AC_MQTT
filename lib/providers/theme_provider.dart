// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  cyberDark,  // Cyber Midnight Dark — Electric Neon Cyan & Purple on Deep Navy (Original Theme)
  cyberLight, // Cyber Tech Light — Cobalt Blue & Cyber Cyan on Titanium White
}

class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.cyberDark;
  AppThemeMode get mode => _mode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyThemeMode);
      if (saved == 'cyberLight') {
        _mode = AppThemeMode.cyberLight;
      } else {
        _mode = AppThemeMode.cyberDark;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(AppThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = newMode == AppThemeMode.cyberLight ? 'cyberLight' : 'cyberDark';
      await prefs.setString(_keyThemeMode, val);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // THEME COLOR PALETTES
  // ---------------------------------------------------------------------
  bool get isCyberDark => _mode == AppThemeMode.cyberDark;
  bool get isCyberLight => _mode == AppThemeMode.cyberLight;
  bool get isDark => _mode == AppThemeMode.cyberDark;
  bool get isLight => _mode == AppThemeMode.cyberLight;

  /// Background color
  Color get background {
    switch (_mode) {
      case AppThemeMode.cyberLight:
        return const Color(0xFFF0F4F8); // Titanium silver light
      case AppThemeMode.cyberDark:
        return const Color(0xFF0A0E17); // Original Cyber Midnight Deep Navy
    }
  }

  /// Card surface color
  Color get card {
    switch (_mode) {
      case AppThemeMode.cyberLight:
        return const Color(0xFFFFFFFF); // Pure white card
      case AppThemeMode.cyberDark:
        return const Color(0xFF141924); // Original Dark Glass Card
    }
  }

  /// Card elevated color
  Color get cardElevated {
    switch (_mode) {
      case AppThemeMode.cyberLight:
        return const Color(0xFFE2E8F0);
      case AppThemeMode.cyberDark:
        return const Color(0xFF1C2230);
    }
  }

  /// Primary brand accent
  Color get primary {
    switch (_mode) {
      case AppThemeMode.cyberLight:
        return const Color(0xFF0066FF); // Cobalt blue
      case AppThemeMode.cyberDark:
        return const Color(0xFF00E5FF); // Electric Neon Cyan
    }
  }

  /// Secondary accent / purple
  Color get purple {
    switch (_mode) {
      case AppThemeMode.cyberLight:
        return const Color(0xFF00C8FF); // Cyber cyan
      case AppThemeMode.cyberDark:
        return const Color(0xFF8B5CF6); // Electric Purple
    }
  }

  /// Green accent
  Color get green {
    switch (_mode) {
      case AppThemeMode.cyberLight:
        return const Color(0xFF10B981);
      case AppThemeMode.cyberDark:
        return const Color(0xFF00E676); // Neon Emerald
    }
  }

  /// Orange accent
  Color get orange {
    switch (_mode) {
      case AppThemeMode.cyberLight:
        return const Color(0xFFF97316);
      case AppThemeMode.cyberDark:
        return const Color(0xFFFF9100); // Neon Amber Orange
    }
  }

  /// Yellow accent
  Color get yellow {
    switch (_mode) {
      case AppThemeMode.cyberLight:
        return const Color(0xFFEAB308);
      case AppThemeMode.cyberDark:
        return const Color(0xFFFFD600); // Bright Gold Yellow
    }
  }

  // ---------------------------------------------------------------------
  // DYNAMIC TEXT COLORS
  // ---------------------------------------------------------------------
  Color get textPrimary =>
      isLight ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);

  Color get textSecondary =>
      isLight ? const Color(0xFF475569) : Colors.white.withValues(alpha: 0.6);

  Color get textTertiary =>
      isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4);

  Color get textDisabled =>
      isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.25);

  // ---------------------------------------------------------------------
  // GLASS & SURFACES
  // ---------------------------------------------------------------------
  Color get glassSurface => isLight
      ? const Color(0xFFFFFFFF).withValues(alpha: 0.90)
      : card.withValues(alpha: 0.70);

  Color get glassBorder => isLight
      ? const Color(0xFF0066FF).withValues(alpha: 0.12)
      : const Color(0xFF00E5FF).withValues(alpha: 0.14);

  Color get glassBorderStrong => isLight
      ? const Color(0xFF0066FF).withValues(alpha: 0.25)
      : const Color(0xFF00E5FF).withValues(alpha: 0.30);

  // ---------------------------------------------------------------------
  // SHADOWS
  // ---------------------------------------------------------------------
  List<BoxShadow> get cardShadow => isLight
      ? [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ];

  List<BoxShadow> neonShadow(Color color, {double blur = 20}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: isLight ? 0.30 : 0.45),
        blurRadius: blur,
        spreadRadius: 0,
      ),
    ];
  }
}

