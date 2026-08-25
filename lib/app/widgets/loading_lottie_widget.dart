

import '../core/common.dart';

class LoadingLottieWidget extends StatelessWidget {
  const LoadingLottieWidget({super.key, this.opacity, this.showColor = false});
  final double? opacity;
  final bool showColor;
  @override
  Widget build(BuildContext context) {
    var lightLoad = 'assets/lotties/loading_light.json';
    var darkLoad = 'assets/lotties/loading_dark.json';
    var colorLoad = 'assets/lotties/loading_purple.json';
    var isDark = context.theme.brightness == Brightness.dark;

    double inOpacity = opacity ?? (isDark ? 0.5 : 1);
    return Opacity(
      opacity: inOpacity,
      child: FadeInUp(
        from: 10.h,
        child: Lottie.asset(
          showColor
              ? colorLoad
              : isDark
              ? darkLoad
              : lightLoad,
          frameRate: FrameRate.max,
        ),
      ),
    );
  }
}
