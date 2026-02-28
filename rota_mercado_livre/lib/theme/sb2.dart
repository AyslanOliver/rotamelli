import 'package:flutter/material.dart';

class SB2 {
  SB2._();
  // Core colors
  static const Color primary = Color(0xFF4E73DF);
  static const Color secondary = Color(0xFF858796);
  static const Color danger = Color(0xFFE74A3B);
  static const Color success = Color(0xFF1CC88A);
  static const Color info = Color(0xFF36B9CC);
  static const Color warning = Color(0xFFF6C23E);
  static const Color background = Color(0xFFF8F9FC);
  static const Color divider = Color(0xFFE3E6F0);
  static const Color text = Color(0xFF5A5C69);
  static const Color surface = Colors.white;

  // Typography
  static const double letterSpacing = 0.8;

  // Spacing
  static const EdgeInsets cardPadding = EdgeInsets.all(12);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(8));

  // Animation
  static const Duration animDuration = Duration(milliseconds: 300);
  static const Curve animInCurve = Curves.easeOutCubic;
  static const Curve animOutCurve = Curves.easeInCubic;
}
