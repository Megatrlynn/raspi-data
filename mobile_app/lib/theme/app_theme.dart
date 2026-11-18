import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  // Brand Neon & Cyber Accents
  static const Color berry = Color(0xFFFF2A5F);
  static const Color berryGlow = Color(0x66FF2A5F);
  static const Color cyan = Color(0xFF00F0FF);
  static const Color cyanGlow = Color(0x6600F0FF);
  static const Color emerald = Color(0xFF00E676);
  static const Color emeraldGlow = Color(0x6600E676);
  static const Color amber = Color(0xFFFFB300);
  static const Color amberGlow = Color(0x66FFB300);
  static const Color purple = Color(0xFFA855F7);
  static const Color blue = Color(0xFF3B82F6);

  // Dark Theme Palette (Deep Space Obsidian & Titanium)
  static const Color darkBg = Color(0xFF090B10);
  static const Color darkSurface = Color(0xFF111520);
  static const Color darkSurfaceElevated = Color(0xFF181E2E);
  static const Color darkBorder = Color(0xFF222B3F);
  static const Color darkBorderGlow = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Theme Palette (Clean Ceramic Titanium & Slate)
  static const Color lightBg = Color(0xFFF6F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderGlow = Color(0xFFCBD5E1);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient berryGradient = LinearGradient(
    colors: [Color(0xFFFF2A5F), Color(0xFFC01048)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00F0FF), Color(0xFF0072FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF141926), Color(0xFF0F131D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.berry,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.berry,
        secondary: AppColors.cyan,
        surface: AppColors.darkSurface,
        background: AppColors.darkBg,
        error: Color(0xFFEF4444),
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.darkBorder, width: 1.2),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.berry,
      colorScheme: const ColorScheme.light(
        primary: AppColors.berry,
        secondary: AppColors.blue,
        surface: AppColors.lightSurface,
        background: AppColors.lightBg,
        error: Color(0xFFEF4444),
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.lightBorder, width: 1.2),
        ),
      ),
    );
  }
}

/// Theme Mode Riverpod Provider with local persistence
class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _prefKey = 'pimobile_theme_mode';

  ThemeNotifier() : super(ThemeMode.dark) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_prefKey);
    if (mode == 'light') {
      state = ThemeMode.light;
    } else if (mode == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.dark; // Default to sleek dark mode
    }
  }

  Future<void> toggleTheme() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, state == ThemeMode.dark ? 'dark' : 'light');
  }

  void setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
