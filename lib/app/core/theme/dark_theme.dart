import '../common.dart';

class DarkTheme {
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: AppColors.darkPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkAccent,
      ),

      useMaterial3: true,
      extensions: const [
        AppThemeColors(
          primary: AppColors.darkPrimary,
          secondary: AppColors.darkAccent,

          pageBackground: Color(0xFF000000),
          cardBackground: Color(0xFF141414),
          surfaceBackground: Color(0xFF1C1C1E),

          primaryText: Colors.white,
          secondaryText: Color(0xFFB3B3B3),
          hintText: Color(0xFF7A7A7A),

          border: Color(0xFF2A2A2A),
          divider: Color(0xFF202020),
          glassBorder: Color(0x22FFFFFF),

          success: AppColors.success,
          warning: AppColors.warning,
          error: AppColors.error,

          iconPrimary: AppColors.black,
          iconSecondary: Color(0xFFB3B3B3),
          scaffoldGradientEnd: AppColors.darkPrimary,
          scaffoldGradientStart: AppColors.black,
          scaffoldGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.45, 1],
            colors: [Colors.black, AppColors.darkPrimary],
          ),
          textGradient: LinearGradient(
            colors: [
              Color(0xFFF43F5E),
              Color(0xFFEC4899),
              Color(0xFFA855F7),
              Color(0xFF6366F1),
              Color(0xFF3B82F6),
            ],
            stops: [0.00, 0.25, 0.50, 0.75, 1.00],
          ),
        ),
      ],
    );
  }
}
