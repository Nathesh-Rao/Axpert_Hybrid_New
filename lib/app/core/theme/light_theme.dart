import '../common.dart';

class LightTheme {
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.light,

      scaffoldBackgroundColor: Colors.transparent,

      primaryColor: AppColors.lightPrimary,

      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightAccent,
      ),

      useMaterial3: true,

      extensions: const [
        AppThemeColors(
          primary: AppColors.lightPrimary,
          secondary: AppColors.lightAccent,

          pageBackground: Colors.white,
          cardBackground: Color(0xFFF8F9FD),
          surfaceBackground: Colors.white,

          primaryText: Color(0xFF111827),
          secondaryText: Color(0xFF6B7280),
          hintText: Color(0xFF9CA3AF),

          border: Color(0xFFE5E7EB),
          divider: Color(0xFFF1F5F9),
          glassBorder: Color(0x33FFFFFF),

          success: Color(0xFF22C55E),
          warning: Color(0xFFF59E0B),
          error: Color(0xFFEF4444),

          iconPrimary: AppColors.white,
          iconSecondary: Color(0xFF6B7280),
          ////
          scaffoldGradientEnd: AppColors.lightAccent,
          scaffoldGradientStart: AppColors.white,
          scaffoldGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.5, 1],
            colors: [Colors.white, AppColors.lightAccent],
          ),
          textGradient: LinearGradient(
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF3730A3),
              Color(0xFF6D28D9),
              Color(0xFFA855F7),
              Color(0xFFEC4899),
            ],
            stops: [0.00, 0.25, 0.50, 0.75, 1.00],
          ),

          ///
        ),
      ],
    );
  }
}
