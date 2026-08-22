import 'package:flutter/material.dart';

/// App color palette for TatIslam — gold accent system.
class AppColors {
  AppColors._();

  // Primary Gold Accent
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFE0B84A);
  static const Color goldDark = Color(0xFFC49A2E);

  // Islamic Green — kept for brand name "ИСЛАМ" and "published" status badge
  static const Color islamGreen = Color(0xFF3CB371);

  // Legacy aliases for backward compatibility
  // secondary = islamGreen for admin screens (keep green there)
  static const Color primary = Colors.white;
  static const Color secondary = islamGreen;
  static const Color accent = Color(0xFFD32F2F); // Red for accents

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFF9E9E9E);

  // Status Colors
  static const Color success = gold;
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFC107);

  // Type Colors
  static const Color articleColor = gold;
  static const Color videoColor = Color(0xFF1976D2);
  static const Color audioColor = Color(0xFF7B1FA2);
  static const Color photoColor = Color(0xFF00897B);

  // Social Media Colors
  static const Color youtube = Color(0xFFFF0000);
  static const Color rutube = Color(0xFFE23636);
  static const Color vkontakte = Color(0xFF0077FF);
  static const Color bip = Color(0xFF6200EE);
  static const Color max = Color(0xFF0057B7);
  static const Color telegram = Color(0xFF0088CC);
  static const Color website = gold;
  static const Color email = Color(0xFF757575);

  // Bottom Navigation Colors
  static const Color navHome = gold;
  static const Color navCatalog = Color(0xFF1976D2); // Blue
  static const Color navSearch = Color(0xFFFF9800); // Orange
  static const Color navFavorites = Color(0xFFE91E63); // Pink/Red
  static const Color navAbout = Color(0xFF000000); // Black
}
