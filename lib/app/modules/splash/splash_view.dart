import '../../core/common.dart';
import '../../data/services/location/location_permission_gate.dart';
import '../../data/services/location/location_service.dart';
import '../../widgets/widgets.dart';
import 'controller/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await LocationPermissionGate.consumePendingCheck()) {
        await LocationPermissionGate.showBlockingUntilGranted();
        await LocationService.startLocationTracking();
      }
      // await LocationPermissionGate.showBlockingUntilGranted();
      controller.onSplashLoad();
    });

    return AppScaffold(
      body: Center(
        child: Stack(
          children: [
            Align(
              child: Hero(
                tag: AppHeroTags.splashLogo,
                child: AxpertLogo(width: 80.w),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 30.h,

              child: LoadingLottieWidget(),
            ),
            Align(
              alignment: AlignmentGeometry.bottomCenter,
              child: AxpertInfoWidget(
                padding: EdgeInsetsGeometry.only(bottom: 15.h),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
