import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color primary;
  final Color secondary;

  final Color pageBackground;
  final Color cardBackground;
  final Color surfaceBackground;

  final Color primaryText;
  final Color secondaryText;
  final Color hintText;

  final Color border;
  final Color divider;
  final Color glassBorder;

  final Color success;
  final Color warning;
  final Color error;

  final Color iconPrimary;
  final Color iconSecondary;

  final Color scaffoldGradientStart;
  final Color scaffoldGradientEnd;
  final Gradient scaffoldGradient;
  final Gradient textGradient;

  const AppThemeColors({
    required this.primary,
    required this.secondary,
    required this.pageBackground,
    required this.cardBackground,
    required this.surfaceBackground,
    required this.primaryText,
    required this.secondaryText,
    required this.hintText,
    required this.border,
    required this.divider,
    required this.glassBorder,
    required this.success,
    required this.warning,
    required this.error,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.scaffoldGradientEnd,
    required this.scaffoldGradientStart,
    required this.scaffoldGradient,
    required this.textGradient,
  });

  @override
  AppThemeColors copyWith({
    Color? primary,
    Color? secondary,
    Color? pageBackground,
    Color? cardBackground,
    Color? surfaceBackground,
    Color? primaryText,
    Color? secondaryText,
    Color? hintText,
    Color? border,
    Color? divider,
    Color? glassBorder,
    Color? success,
    Color? warning,
    Color? error,
    Color? iconPrimary,
    Color? iconSecondary,

    Color? scaffoldGradientStart,
    Color? scaffoldGradientEnd,
    Gradient? scaffoldGradient,
    Gradient? textGradient,
  }) {
    return AppThemeColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      pageBackground: pageBackground ?? this.pageBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      surfaceBackground: surfaceBackground ?? this.surfaceBackground,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      hintText: hintText ?? this.hintText,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      glassBorder: glassBorder ?? this.glassBorder,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      scaffoldGradientStart:
          scaffoldGradientStart ?? this.scaffoldGradientStart,
      scaffoldGradientEnd: scaffoldGradientEnd ?? this.scaffoldGradientEnd,
      scaffoldGradient: scaffoldGradient ?? this.scaffoldGradient,
      textGradient: textGradient ?? this.textGradient,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;

    return AppThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,

      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      surfaceBackground: Color.lerp(
        surfaceBackground,
        other.surfaceBackground,
        t,
      )!,

      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      hintText: Color.lerp(hintText, other.hintText, t)!,

      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      scaffoldGradient: Gradient.lerp(
        scaffoldGradient,
        other.scaffoldGradient,
        t,
      )!,
      textGradient: Gradient.lerp(textGradient, other.textGradient, t)!,

      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,

      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      scaffoldGradientStart: Color.lerp(
        scaffoldGradientStart,
        other.scaffoldGradientStart,
        t,
      )!,
      scaffoldGradientEnd: Color.lerp(
        scaffoldGradientEnd,
        other.scaffoldGradientEnd,
        t,
      )!,
    );
  }
}
