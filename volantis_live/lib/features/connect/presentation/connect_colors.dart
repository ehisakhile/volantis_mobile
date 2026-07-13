import 'package:flutter/material.dart';

/// Web-app-aligned dark-mode color tokens for Connect feature
/// These are sourced from the web app's Volantis Connect theme for visual uniformity
class ConnectColors {
  ConnectColors._();

  // Background & surface
  static const Color bg = Color(0xFF0C0C0B);
  static const Color bgSubtle = Color(0xFF141413);
  static const Color bgCard = Color(0xFF181817);
  static const Color surfaceLight = Color(0xFF1A2235);

  // Text
  static const Color text = Color(0xFFF0EFED);
  static const Color textSecondary = Color(0xFFA8A5A0);
  static const Color textTertiary = Color(0xFF6B6966);

  // Interactive
  static const Color accent = Color(0xFF4A9EFF);
  static const Color accentHover = Color(0xFF6FB3FF);
  static const Color accentDark = Color(0xFF1E3A5F);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFCA8A04);

  // Borders & dividers
  static const Color border = Color(0xFF2A2A27);
  static const Color borderHover = Color(0xFF3A3A36);

  // Secondary colors (from web app)
  static const Color accentPurple = Color(0xFFA78BFA);
  static const Color accentBlue = Color(0xFF3B82F6);

  // Utility
  static const Color disabled = Color(0xFF4B5563);
  static const Color shadow = Color(0x26000000); // Approximate shadow color
}
