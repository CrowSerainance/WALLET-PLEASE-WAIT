import 'package:material_ui/material_ui.dart';

/// Playful fintech-meets-social design tokens.
class AppColors {
  static const approve = Color(0xFF2ECC71);
  static const reject = Color(0xFFFF5A5F);
  static const background = Color(0xFFF9F9F6);
  static const slate = Color(0xFF1F2933);
  static const slateMuted = Color(0xFF52606D);
  static const surface = Color(0xFFFFFFFF);
  static const mintSoft = Color(0xFFE8F8F0);
  static const coralSoft = Color(0xFFFFE8E9);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto', // replaced visually via TextTheme; avoid Inter stack
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.approve,
        secondary: AppColors.reject,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.slate,
        error: AppColors.reject,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.slate,
        displayColor: AppColors.slate,
      ).copyWith(
        displaySmall: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.slate,
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
        ),
        bodyLarge: const TextStyle(height: 1.35, color: AppColors.slate),
        bodyMedium: const TextStyle(height: 1.35, color: AppColors.slateMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.slate,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.slate,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
