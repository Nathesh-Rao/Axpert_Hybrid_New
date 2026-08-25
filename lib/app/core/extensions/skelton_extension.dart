import 'package:skeletonizer/skeletonizer.dart';
import '../common.dart';

extension SkeletonizeExtension on Widget {
  Widget skeletonLoading(bool enabled) {
    return Skeletonizer(
      enabled: enabled,
      effect: PulseEffect(duration: Duration(milliseconds: 500)),
      enableSwitchAnimation: true,
      child: this,
    );
  }
}
