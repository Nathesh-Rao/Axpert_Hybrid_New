import '../core/common.dart';

class AxiLogoWidget extends StatelessWidget {
  const AxiLogoWidget({
    super.key,
    this.scale,
    this.width,
    this.height,
    this.color,
    this.fit,
  });
  final double? scale;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit? fit;
  @override
  Widget build(BuildContext context) {
    var blackLogo = "assets/images/axi_logo_black.png";
    var whiteLogo = "assets/images/axi_logo_white.png";

    var isDark = context.theme.brightness == Brightness.dark;
    return Image.asset(
      isDark ? whiteLogo : blackLogo,
      scale: scale,
      width: width,
      height: height,
      color: color,
      fit: fit ?? BoxFit.cover,
    );
  }
}
