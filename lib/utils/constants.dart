import 'package:flutter/material.dart';

/// App color palette
class AppColors {
  // Base colors
  static const Color background = Color(0xFF2C2C2C);
  static const Color surface = Color(0xFF1C1C1C);
  static const Color surfaceLight = Color(0xFF3C3C3C);
  
  // Accent colors
  static const Color accent = Color(0xFF00BFFF);      // Cyan blue
  static const Color accentDim = Color(0xFF007ACC);   // Darker blue
  
  // Status colors
  static const Color danger = Color(0xFFAA4400);      // Orange-red
  static const Color dangerBright = Color(0xFFFF6600);
  static const Color success = Color(0xFF00AA44);     // Green
  static const Color warning = Color(0xFFFFAA00);     // Yellow-orange
  
  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white38;
  
  // Border colors
  static const Color border = Color(0xFF555555);
  static const Color borderLight = Color(0xFF666666);
}

/// Standard border radius
class AppRadius {
  static const double small = 5.0;
  static const double medium = 10.0;
  static const double large = 15.0;
  static const double circular = 999.0;
}

/// Standard spacing
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

/// Icon rail dimensions
class AppDimensions {
  static const double iconRailWidth = 61.0;  // 90% of original
  static const double controlPanelWidth = 280.0;
  static const double chatPanelWidth = 280.0;
}

