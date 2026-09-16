import "package:flutter/material.dart";

class AdminTheme {
  static const bg = Color(0xFF0E1116);
  static const card = Color(0xFF171B22);
  static const line = Color(0xFF2A303A);
  static const silver = Color(0xFFD5D8DE);
  static const mute = Color(0xFF8B909A);
  static const accent = Color(0xFF7EB0FF);
  static const ok = Color(0xFF3DDC97);
  static const warn = Color(0xFFFFB547);
  static const danger = Color(0xFFFF6B6B);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: card,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: silver,
      ),
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: line),
        ),
      ),
      dividerColor: line,
    );
  }
}
