import 'package:flutter/material.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/providers/text_scale_provider.dart';

/// App theme configuration - Light theme with TatIslam gold accent system.
class AppTheme {
  AppTheme._();

  /// Base unscaled font sizes mapped by TextTheme style name.
  /// These are the reference sizes for all 15+ Material TextTheme styles.
  static const Map<String, double> _baseFontSizes = {
    'displayLarge': 57,
    'displayMedium': 45,
    'displaySmall': 36,
    'headlineLarge': 32,
    'headlineMedium': 28,
    'headlineSmall': 24,
    'titleLarge': 22,
    'titleMedium': 16,
    'titleSmall': 14,
    'bodyLarge': 16,
    'bodyMedium': 14,
    'bodySmall': 12,
    'labelLarge': 14,
    'labelMedium': 12,
    'labelSmall': 11,
  };

  /// Builds a complete [TextTheme] with all font sizes scaled by [scale].
  static TextTheme buildTextTheme(double scale) {
    final s = scale;
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: (_baseFontSizes['displayLarge']! * s).roundToDouble(),
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: (_baseFontSizes['displayMedium']! * s).roundToDouble(),
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: (_baseFontSizes['displaySmall']! * s).roundToDouble(),
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      ),
      headlineLarge: TextStyle(
        fontSize: (_baseFontSizes['headlineLarge']! * s).roundToDouble(),
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: (_baseFontSizes['headlineMedium']! * s).roundToDouble(),
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: (_baseFontSizes['headlineSmall']! * s).roundToDouble(),
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: (_baseFontSizes['titleLarge']! * s).roundToDouble(),
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: (_baseFontSizes['titleMedium']! * s).roundToDouble(),
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: (_baseFontSizes['titleSmall']! * s).roundToDouble(),
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: (_baseFontSizes['bodyLarge']! * s).roundToDouble(),
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: (_baseFontSizes['bodyMedium']! * s).roundToDouble(),
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: (_baseFontSizes['bodySmall']! * s).roundToDouble(),
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: (_baseFontSizes['labelLarge']! * s).roundToDouble(),
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: (_baseFontSizes['labelMedium']! * s).roundToDouble(),
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: (_baseFontSizes['labelSmall']! * s).roundToDouble(),
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }

  /// Returns a full [ThemeData] with the given text scale applied.
  /// All sub-themes that contain hardcoded TextStyles are updated to use
  /// the scaled textTheme, so every UI element scales automatically.
  static ThemeData lightThemeWithScale(TextScaleLevel level) {
    final double s = level.scale;
    final textTheme = buildTextTheme(s);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gold,
        brightness: Brightness.light,
        primary: AppColors.gold,
        secondary: AppColors.gold,
      ).copyWith(
        primary: AppColors.gold,
        secondary: AppColors.gold,
      ),
      primaryColor: AppColors.gold,
      scaffoldBackgroundColor: AppColors.background,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── Input Decoration ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Text Selection ──
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.gold,
        selectionColor: Color(0x55D4A843),
        selectionHandleColor: AppColors.gold,
      ),

      // ── Progress Indicators ──
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
        linearTrackColor: Color(0x33D4A843),
        circularTrackColor: Color(0x33D4A843),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textLight,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ── Navigation Bar (M3) ──
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(color: AppColors.gold);
          }
          return textTheme.labelSmall;
        }),
      ),

      // ── Floating Action Button ──
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ── Tab Bar ──
      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelLarge,
      ),

      // ── List Tile ──
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium,
      ),

      // ── Typography ──
      textTheme: textTheme,
    );
  }
}
