import 'package:flutter/material.dart';

/// Breakpoint thresholds for adaptive layout.
class ResponsiveBreakpoints {
  static const double _mobileMax = 700;
  static const double _tabletMin = 1000;

  /// Portrait phone (narrow, portrait orientation).
  static bool isMobilePortrait(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.shortestSide;
    return width < _mobileMax &&
        MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Phone in landscape or compact foldable landscape.
  static bool isCompactLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.longestSide;
    // Landscape phone: width >= height, and longest side < tablet threshold
    return MediaQuery.of(context).orientation == Orientation.landscape &&
        width < _tabletMin;
  }

  /// Tablet or large screen (either orientation).
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.longestSide;
    return width >= _tabletMin;
  }

  /// Returns the width to use for layout decisions.
  static double layoutWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Returns the height to use for layout decisions.
  static double layoutHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Whether the device is in landscape orientation.
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Scale factor for glassmorphism elements on tablets.
  /// Returns 1.0 for phones, 1.12 for tablets.
  static double glassScale(BuildContext context) {
    if (isTablet(context)) return 1.12;
    if (isCompactLandscape(context)) return 1.06;
    return 1.0;
  }
}
