import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_design_tokens.dart';

class AppTheme {
  static ThemeData get luxuryTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.ink,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink,
        onPrimary: AppColors.white,
        secondary: AppColors.lime,
        onSecondary: AppColors.ink,
        surface: AppColors.paperLight,
        onSurface: AppColors.textMain,
        error: AppColors.danger,
        onError: AppColors.white,
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          height: 1.02,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          color: AppColors.ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.9,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.45,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textMain,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textMain,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.ink),
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        modalBackgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: AppColors.white),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paperDark,
        selectedColor: AppColors.lime,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
