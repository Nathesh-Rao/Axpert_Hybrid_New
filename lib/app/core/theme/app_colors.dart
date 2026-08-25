import 'package:flutter/material.dart';

class AppColors {
  // Light Theme
  // static const Color lightPrimary = Color(0xFF6B4EFF);
  // static const Color lightAccent = Color(0xFFB29CFF);
  static const Color AXMDark = Color(0xff363942);
  static const Color AXMGray = Color(0xff61677D);
  static const Color lightPrimary = Color(0xFF6885FD);
  static const Color lightAccent = Color(0xFFC2CDFF);

  // Dark Theme
  static const Color darkPrimary = Color(0xFF053BE9);
  static const Color darkAccent = Color(0xFF053BE9);

  // Common
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);
  // ============================================
  // PRIMARY BRAND COLORS
  // ============================================
  static const Color primaryOrange = Color(0xFFF15A24);
  static const Color primaryBlue = Color(0xFF0079C0);
  static const Color primaryPink = Color(0xFFFF0072);
  static const Color primaryGreen = Color(0xFF2AB77E);
  static const Color primaryPurple = Color(0xFF7357F5);
  static const Color button1 = Color(0xFF6885FD);
  static const Color button2 = Color(0xFFB28FF8);

  // ============================================
  // BACKGROUND COLORS
  // ============================================
  static const Color backgroundDarkStart = Color(0xFF21263F);
  static const Color backgroundDarkEnd = Color(0xFF0B0E12);
  static const Color cardBackground = Color(0xFF151837);
  static const Color buttonBackground = Color(0xFF3C4181);

  // Dark text on light backgrounds
  static const Color textOnLight = Color(0xFF21263F);

  // ============================================
  // TEXT COLORS
  // ============================================
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textPlaceholder = Color(0xFF747474);
  static const Color textSecondary = Color(0xFF919191);
  static const Color darkBlue = Color(0xFF2a2b8f);
  static const Color moreDark = Color(0xFF1F1D2C);
  // ============================================
  // OVERLAY/GLASS COLORS (with opacity)
  // ============================================
  static const Color glassLight = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const Color glassMedium = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
  static const Color glassBorder = Color(0x36FFFFFF); // rgba(255,255,255,0.21)

  static const Color purpleOverlay = Color(0xA6784BA0); // rgba(120,75,160,0.65)
  static const Color greenOverlay14 = Color(
    0x242AB77E,
  ); // rgba(42,183,126,0.14)
  static const Color greenOverlay20 = Color(0x332AB77E); // rgba(42,183,126,0.2)
  static const Color purpleOverlay20 = Color(
    0x337357F5,
  ); // rgba(115,87,245,0.2)
  static const Color blueOverlay05 = Color(0x0D0079C0); // rgba(0,121,192,0.05)
  static const Color redOverlay05 = Color(0x0DEE0146); // rgba(238,1,70,0.05)
  static const Color purpleActiveOverlay = Color(
    0x5E8088FF,
  ); // rgba(128,136,255,0.37)

  // ============================================
  // ACCENT COLORS
  // ============================================
  static const Color accentCyan = Color(0xFF00B1FF);
  static const Color accentLightGreen = Color(0xFF00FF79);
  static const Color accentLavender = Color(0xFFAA83FF);
  static const Color accentHotPink = Color(0xFFFF3FA4);
  static const Color accentOrangeLight = Color(0xFFFF6B2C);
  static const Color accentYellow = Color(0xFFFFB432);
  static const Color accentRed = Color(0xFFEE0146);

  // ============================================
  // UTILITY COLORS
  // ============================================
  static const Color gray = Color(0xFF585858);
  static const Color grayOverlay36 = Color(0x5C585858); // rgba(88,88,88,0.36)
  static const Color grayOverlay11 = Color(0x1C585858); // rgba(88,88,88,0.11)

  // ============================================
  // GRADIENTS
  // ============================================

  // Main Background Gradient (Dark)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      backgroundDarkStart, // #21263F
      backgroundDarkEnd, // #0B0E12
    ],
  );

  // Business Platform Text Gradient
  static const LinearGradient businessPlatformGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    stops: [0.0, 0.40, 0.66],
    colors: [
      accentOrangeLight, // #FF6B2C
      accentYellow, // #FFB432
      primaryGreen, // #2AB77E
    ],
  );

  // Cyan to Green Gradient (Message Icon)
  static const LinearGradient cyanToGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accentCyan, // #00B1FF
      accentLightGreen, // #00FF79
    ],
  );

  // Purple to Pink Gradient (Box Icon)
  static const LinearGradient purpleToPinkGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      accentLavender, // #AA83FF
      accentHotPink, // #FF3FA4
    ],
  );

  // Glass/Frosted Effect Gradient
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33FFFFFF), // rgba(255,255,255,0.2)
      Color(0x7DFFFFFF), // rgba(255,255,255,0.49)
    ],
  );

  // ============================================
  // BORDER COLORS
  // ============================================
  static const Color borderGreen = Color(0xFF2AB77E);
  static const Color borderOrange = Color(0xFFF15A24);
  static const Color borderWhite = Color(0xFFFFFFFF);
  static const Color borderWhiteTransparent = Color(
    0x36FFFFFF,
  ); // rgba(255,255,255,0.21)

  // ============================================
  // SHADOW COLORS
  // ============================================
  static const Color shadowColor = Color(0x1C1F2687); // rgba(31,38,135,0.11)
  static const Color shadowColorMedium = Color(0x1A1F2687);

  static const Color accentPurple = Color(0xFF7357F5); // your purple
  static const Color accentGreen = Color(0xFF2AB77E); // your green
  static const Color accentAmber = Color(0xFFFFB347); // soft amber orange
  static const Color accentCyan2 = Color(0xFF38BDF8); // sky cyan blue
  static const Color accentCoral = Color(0xFFFF6B6B); // warm coral red

  static const List<Color> _itemColors = [
    accentPurple,
    accentGreen,
    accentAmber,
    accentCyan2,
    accentCoral,
  ];

  static Color getItemColor(int index) =>
      _itemColors[index % _itemColors.length]; // rgba(31,38,135,0.1)

  static Color? colorFromHex(String hex) {
    if (hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : null;
  }
}
