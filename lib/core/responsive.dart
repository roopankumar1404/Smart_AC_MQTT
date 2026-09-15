// lib/core/responsive.dart

import 'package:flutter/material.dart';

/// Responsive breakpoint helper for Phone / Tablet / Desktop layouts.
///
/// Breakpoints:
/// - Phone:   < 700px
/// - Tablet:  700px – 1099px
/// - Desktop: >= 1100px
class Responsive {
  Responsive._();

  static const double _tabletBreakpoint = 700;
  static const double _desktopBreakpoint = 1100;

  static double widthOf(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double heightOf(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isMobile(BuildContext context) =>
      widthOf(context) < _tabletBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= _tabletBreakpoint && w < _desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      widthOf(context) >= _desktopBreakpoint;

  /// Returns one of [mobile], [tablet], [desktop] depending on screen width.
  /// Falls back to [mobile] if [tablet]/[desktop] are not provided.
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Horizontal padding scaled to device class — used consistently
  /// across screens for outer content padding.
  static double horizontalPadding(BuildContext context) {
    return value<double>(
      context: context,
      mobile: 16,
      tablet: 28,
      desktop: 40,
    );
  }

  /// Max content width so desktop layouts don't stretch edge-to-edge
  /// on ultra-wide monitors.
  static double maxContentWidth(BuildContext context) {
    return value<double>(
      context: context,
      mobile: double.infinity,
      tablet: double.infinity,
      desktop: 1440,
    );
  }

  /// Grid column count helper for metric card grids.
  static int gridColumns(BuildContext context) {
    return value<int>(
      context: context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );
  }

  /// Returns true if the device is in landscape orientation.
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Safe area–aware bottom padding (useful for floating bottom nav).
  static double bottomSafePadding(BuildContext context) =>
      MediaQuery.of(context).padding.bottom;
}