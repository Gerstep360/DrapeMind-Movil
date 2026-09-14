import 'package:flutter/material.dart';

class AppColors {
  // Brand colors (DrapeMind Official Web Design System)
  static const Color ink = Color(0xFF10110F); // --dm-ink
  static const Color lime = Color(
    0xFFDFFF3F,
  ); // --dm-lime (Drape Lime insignia)
  static const Color limeSoft = Color(0xFFEEFF9D); // --dm-lime-soft
  static const Color cyan = Color(0xFFC9EEF0); // --dm-cyan
  static const Color cyanSoft = Color(0xFFE7F7F7); // --dm-cyan-soft

  // Legacy aliases mapped to modern design tokens
  static const Color forest = Color(
    0xFF10110F,
  ); // Replaced dark green with Atelier Ink
  static const Color forestDark = Color(0xFF000000); // Deep Black
  static const Color forestLight = Color(0xFF22231F); // Soft Ink
  static const Color acid = Color(0xFFDFFF3F); // Drape Lime
  static const Color gold = Color(0xFFE4B84D); // --dm-warning / gold

  // Background & paper tones (Soft Futurism / Warm Minimalism)
  static const Color paper = Color(0xFFF4F5EA); // --dm-bg
  static const Color paperLight = Color(0xFFFFFFFF); // --dm-surface
  static const Color paperDark = Color(
    0xFFF0F1EB,
  ); // --dm-gray-100 / surface-soft
  static const Color white = Color(0xFFFFFFFF);

  // Borders & lines
  static const Color line = Color(0xFFE1E3DA); // --dm-border
  static const Color lineStrong = Color(0xFFCDD0C5); // --dm-border-strong

  // Text & accents
  static const Color textMain = Color(0xFF10110F); // --dm-ink
  static const Color textMuted = Color(0xFF7B7F75); // --dm-gray-500
  static const Color textMutedStrong = Color(0xFF40433D); // --dm-gray-700

  // Status indicators
  static const Color danger = Color(0xFFE85D5D); // --dm-danger
  static const Color dangerBg = Color(0xFFFDE8E8);
  static const Color success = Color(0xFF57A773); // --dm-success
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFE4B84D); // --dm-warning
  static const Color warningBg = Color(0xFFFEF8EC);
}
