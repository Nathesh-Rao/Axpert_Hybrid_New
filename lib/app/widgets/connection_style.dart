import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared visual language from the Axpert mobile HTML reference.
class ConnectionStyle {
  static const navy = Color(0xff3A5FC0);
  static const orange = Color(0xffF28C1E);
  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color bg(BuildContext c) =>
      dark(c) ? const Color(0xff080D1B) : const Color(0xffE9EDF7);
  static Color card(BuildContext c) =>
      dark(c) ? const Color(0xff121B36) : Colors.white;
  static Color ink(BuildContext c) =>
      dark(c) ? const Color(0xffEEF2FF) : const Color(0xff14203F);
  static Color muted(BuildContext c) =>
      dark(c) ? const Color(0xff9CA8C7) : const Color(0xff5D6985);
  static Color field(BuildContext c) =>
      dark(c) ? const Color(0xff1A2546) : const Color(0xffF3F6FC);
  static Color line(BuildContext c) =>
      dark(c) ? const Color(0xff27345E) : const Color(0xffDCE3F2);
  static Color tint(BuildContext c) =>
      dark(c) ? const Color(0xff1E2B54) : const Color(0xffE6ECFB);
  static TextStyle text(
    BuildContext c,
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color ?? ink(c),
  );
  static InputDecoration input(
    BuildContext c,
    String hint,
    IconData icon, {
    String? error,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    errorText: error == '' ? null : error,
    hintStyle: text(c, 14, color: muted(c)),
    filled: true,
    fillColor: field(c),
    prefixIcon: Icon(icon, size: 20, color: muted(c)),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: line(c)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: navy, width: 1.5),
    ),
  );
}

class ConnectionHero extends StatelessWidget {
  const ConnectionHero({super.key, required this.child, this.radius = 0});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff16275C), Color(0xff22397F), Color(0xff3A5FC0)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xbbF5A03A), Color(0x00F5A03A)],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _Rings())),
          child,
        ],
      ),
    ),
  );
}

class _Rings extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in [60.0, 100.0, 140.0, 180.0]) {
      canvas.drawCircle(Offset(size.width - 35, 30), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_Rings oldDelegate) => false;
}

class ConnectionMark extends StatelessWidget {
  const ConnectionMark({super.key, this.size = 38});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * .15),
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [Color(0xffFFC067), ConnectionStyle.orange],
      ),
    ),
    child: Image.asset(
      'assets/images/axpert_logo_new.png',
      fit: BoxFit.contain,
    ),
  );
}

class ConnectionButton extends StatelessWidget {
  const ConnectionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.orange = false,
    this.soft = false,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool orange, soft, loading;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 50),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: soft ? ConnectionStyle.tint(context) : null,
      gradient: soft
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: orange
                  ? [const Color(0xffFFB655), ConnectionStyle.orange]
                  : [const Color(0xff3F66C9), const Color(0xff2D4E9E)],
            ),
    ),
    child: TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (icon != null)
            Icon(
              icon,
              size: 20,
              color: soft
                  ? ConnectionStyle.ink(context)
                  : orange
                  ? const Color(0xff1A2447)
                  : Colors.white,
            ),
          if (loading || icon != null) const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: ConnectionStyle.text(
                context,
                14,
                weight: FontWeight.w700,
                color: soft
                    ? ConnectionStyle.ink(context)
                    : orange
                    ? const Color(0xff1A2447)
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
