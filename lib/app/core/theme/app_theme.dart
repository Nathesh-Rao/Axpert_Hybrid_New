import 'package:flutter/material.dart';

import 'dark_theme.dart';
import 'light_theme.dart';

abstract class AppTheme {
  AppTheme._();

  static ThemeData light = LightTheme.theme;
  static ThemeData dark = DarkTheme.theme;
}
