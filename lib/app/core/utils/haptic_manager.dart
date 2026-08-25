import 'package:flutter/services.dart';

class HapticManager {
  HapticManager._();

  /// Subtle tap — button press, selection
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Solid tap — confirm, toggle
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Clean thud — delete, close
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Two clean taps — saved, done ✓
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// Short sharp double pulse — something went wrong
  static Future<void> error() async {
    await HapticFeedback.mediumImpact();
  }

  /// Single mid pulse — heads up
  static Future<void> warning() async {
    await HapticFeedback.mediumImpact();
  }

  /// Tiny tick — tab switch, scroll snap
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }
}
