import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge =>
      GoogleFonts.poppins(fontSize: 40.sp, fontWeight: FontWeight.w700);
  static TextStyle get displayLargeSerif => GoogleFonts.sourceSerif4(
    fontWeight: FontWeight.w600,
    fontSize: 40.sp,
    height: 1,
  );

  static TextStyle get displayMedium =>
      GoogleFonts.poppins(fontSize: 32.sp, fontWeight: FontWeight.w700);

  static TextStyle get heading1 =>
      GoogleFonts.poppins(fontSize: 28.sp, fontWeight: FontWeight.w700);

  static TextStyle get heading2 =>
      GoogleFonts.poppins(fontSize: 24.sp, fontWeight: FontWeight.w600);

  static TextStyle get heading3 =>
      GoogleFonts.poppins(fontSize: 20.sp, fontWeight: FontWeight.w600);

  static TextStyle get title =>
      GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w600);

  static TextStyle get subtitle =>
      GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.w500);

  static TextStyle get bodyLarge =>
      GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.w400);

  static TextStyle get bodyMedium =>
      GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w400);

  static TextStyle get bodySmall =>
      GoogleFonts.poppins(fontSize: 12.sp, fontWeight: FontWeight.w400);

  static TextStyle get button =>
      GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.w600);

  static TextStyle get caption =>
      GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w400);
}
