import '../common.dart';

class AxiTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryOrange,
      scaffoldBackgroundColor: AppColors.backgroundDarkEnd,

      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryOrange,
        secondary: AppColors.primaryGreen,
        tertiary: AppColors.primaryBlue,
        surface: AppColors.cardBackground,
        error: AppColors.accentRed,
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: AppColors.textWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textWhite,
          side: BorderSide(color: AppColors.borderOrange),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.textPlaceholder,
          fontSize: 18,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.glassLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.glassMedium, width: 1),
        ),
        elevation: 0,
      ),
    );
  }
}
