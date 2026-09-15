// lib/core/colors.dart

import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

/// Centralized dynamic color palette for the Smart AC Controller app.
/// Dynamically connects to ThemeProvider for instant app-wide theme shifts.
class AppColors {
  AppColors._();

  static ThemeProvider? _activeTheme;

  /// Registers the current active ThemeProvider so static getters update dynamically.
  static void registerTheme(ThemeProvider theme) {
    _activeTheme = theme;
  }

  static bool get isLight => _activeTheme?.isLight ?? false;

  // ---------------------------------------------------------------------
  // DYNAMIC BASE COLORS
  // ---------------------------------------------------------------------
  static Color get background =>
      _activeTheme?.background ?? const Color(0xFF0A0E17); // Cyber Dark default

  static Color get card =>
      _activeTheme?.card ?? const Color(0xFF141924); // Cyber Dark card default

  static Color get cardElevated =>
      _activeTheme?.cardElevated ?? const Color(0xFF1C2230);

  static Color get divider => isLight
      ? const Color(0xFFE2E8F0)
      : const Color(0x1AFFFFFF); // light border vs 10% white

  // ---------------------------------------------------------------------
  // DYNAMIC BRAND / ACCENT COLORS
  // ---------------------------------------------------------------------
  static Color get primary =>
      _activeTheme?.primary ?? const Color(0xFF00E5FF); // Cyber Dark Neon Cyan

  static Color get purple =>
      _activeTheme?.purple ?? const Color(0xFF8B5CF6); // Cyber Dark Purple

  static Color get green =>
      _activeTheme?.green ?? const Color(0xFF00E676); // Cyber Dark Neon Green

  static Color get orange =>
      _activeTheme?.orange ?? const Color(0xFFFF9100); // Neon Amber Orange

  static Color get yellow =>
      _activeTheme?.yellow ?? const Color(0xFFFFD600); // Bright Gold Yellow

  static const Color red = Color(0xFFFF4757);
  static const Color error = Color(0xFFFF4757);
  static Color get success => green;

  // ---------------------------------------------------------------------
  // TEXT
  // ---------------------------------------------------------------------
  static Color get textPrimary =>
      _activeTheme?.textPrimary ?? const Color(0xFFFFFFFF);

  static Color get textSecondary =>
      _activeTheme?.textSecondary ?? Colors.white.withValues(alpha: 0.6);

  static Color get textTertiary =>
      _activeTheme?.textTertiary ?? Colors.white.withValues(alpha: 0.4);

  static Color get textDisabled =>
      _activeTheme?.textDisabled ?? Colors.white.withValues(alpha: 0.25);

  // ---------------------------------------------------------------------
  // STATUS COLORS
  // ---------------------------------------------------------------------
  static Color get online => green;
  static const Color offline = red;
  static Color get warning => yellow;

  // ---------------------------------------------------------------------
  // GRADIENTS
  // ---------------------------------------------------------------------
  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, purple],
      );

  static LinearGradient get energyGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primary, primary.withValues(alpha: 0.0)],
      );

  static LinearGradient get successGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [green, green.withValues(alpha: 0.7)],
      );

  static LinearGradient get warningGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [yellow, orange],
      );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [red, Color(0xFFB8003C)],
  );

  static RadialGradient glowGradient(Color color, {double opacity = 0.2}) {
    return RadialGradient(
      colors: [color.withValues(alpha: opacity), Colors.transparent],
    );
  }

  // ---------------------------------------------------------------------
  // GLASS SURFACES
  // ---------------------------------------------------------------------
  static Color get glassSurface =>
      _activeTheme?.glassSurface ?? card.withValues(alpha: 0.55);

  static Color get glassBorder =>
      _activeTheme?.glassBorder ?? Colors.white.withValues(alpha: 0.06);

  static Color get glassBorderStrong =>
      _activeTheme?.glassBorderStrong ?? Colors.white.withValues(alpha: 0.12);

  // ---------------------------------------------------------------------
  // SHADOWS
  // ---------------------------------------------------------------------
  static List<BoxShadow> neonShadow(Color color, {double blur = 20}) {
    if (_activeTheme != null) {
      return _activeTheme!.neonShadow(color, blur: blur);
    }
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.45),
        blurRadius: blur,
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> get cardShadow =>
      _activeTheme?.cardShadow ??
      [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  // ---------------------------------------------------------------------
  // COLOR HELPERS
  // ---------------------------------------------------------------------
  static Color statusColor(bool isOnline) => isOnline ? online : offline;

  static Color healthColor(int score) {
    if (score >= 70) return green;
    if (score >= 40) return yellow;
    return red;
  }
}