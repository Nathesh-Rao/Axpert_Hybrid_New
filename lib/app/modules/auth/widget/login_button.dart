import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WidgetLoginButton extends StatelessWidget {
  const WidgetLoginButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.visible = true,
    this.icon,
    this.gradient,
    this.color,
    this.loading = false,
  });

  final String label;
  final bool visible;
  final bool loading;
  final Widget? icon;
  final Color? color;
  final VoidCallback? onPressed;

  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25),
        height: MediaQuery.of(context).size.height * 0.065,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: color == null
              ? gradient ??
                    const LinearGradient(
                      colors: [Color(0xFF196BFB), Color(0xFFA770EF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: color ?? Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: loading ? 12 : 18,
                  fontWeight: loading ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
