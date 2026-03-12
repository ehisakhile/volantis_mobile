import 'package:flutter/material.dart';

/// App color constants for VolantisLive
/// Using a dark theme with accent colors - update with brand colors when available
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4A42CC);

  // Secondary Colors
  static const Color secondary = Color(0xFF2D2D2D);
  static const Color secondaryLight = Color(0xFF454545);
  static const Color secondaryDark = Color(0xFF1A1A1A);

  // Accent Colors
  static const Color accent = Color(0xFF00D9FF);
  static const Color accentLight = Color(0xFF5CE6FF);
  static const Color accentDark = Color(0xFF00A8CC);

  // Background Colors (Dark Theme)
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF2A2A2A);
  static const Color cardBackground = Color(0xFF252525);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textHint = Color(0xFF666666);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB74D);
  static const Color info = Color(0xFF29B6F6);

  // Live Indicator
  static const Color live = Color(0xFFFF4444);
  static const Color liveBackground = Color(0x33FF4444);

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF6C63FF),
    Color(0xFF00D9FF),
  ];

  static const List<Color> darkGradient = [
    Color(0xFF1E1E1E),
    Color(0xFF121212),
  ];

  // Player Colors
  static const Color playerBackground = Color(0xFF1A1A1A);
  static const Color progressBarBackground = Color(0xFF3A3A3A);
  static const Color progressBarActive = Color(0xFF6C63FF);

  // Divider
  static const Color divider = Color(0xFF333333);

  // Shimmer
  static const Color shimmerBase = Color(0xFF2A2A2A);
  static const Color shimmerHighlight = Color(0xFF3A3A3A);
}