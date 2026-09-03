import 'package:axpert/app/modules/auth/bindings/auth_bindings.dart';
import 'package:axpert/app/modules/auth/controller/forgot_password_controller.dart';
import 'package:axpert/app/modules/auth/views/forgot_passwrod_view.dart';
import 'package:axpert/app/modules/auth/views/login_view.dart';
import 'package:axpert/app/modules/offline_form_pages/pages/offline_form_page.dart';
import 'package:axpert/app/modules/offline_form_pages/pages/offline_listing_page.dart';
import 'package:axpert/app/modules/project/binding/project_binding.dart';
import 'package:axpert/app/modules/project/project_view.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:axpert/app/modules/webview/webview_view.dart';
import 'package:get/get.dart';

import '../../modules/auth/views/otp_view.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/splash/splash_view.dart';
import '../../modules/onboarding/onboarding_binding.dart';
import '../../modules/onboarding/onboarding_view.dart';
import '../../modules/home/home_binding.dart';
import '../../modules/home/home_view.dart';

import '../../modules/webview/bindings/webview_bindings.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.ONBOARDING,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: Routes.PROJECT_CONFIG,
      page: () => const ProjectView(),
      binding: ProjectBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginView(),
      binding: AuthBindings(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.OTP,
      page: () => const OTPView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.FORGOT_PASSWORD,
      page: () => ForgetPasswordView(),
      binding: BindingsBuilder(() {
        Get.put(ForgetPasswordController());
      }),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.WEBVIEW,
      page: () => WebviewView(),
      binding: WebviewBindings(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.OFFLINE_LISTING_PAGE,
      page: () => OfflineListingPage(),
      // binding: WebviewBindings(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.OFFLINE_FORM_PAGE,
      page: () => OfflineFormPage(),
      // binding: WebviewBindings(),
      transition: Transition.rightToLeft,
    ),
    // GetPage(
    //   name: Routes.QR_SCAN,
    //   page: () => const QrScanView(),
    //   // binding: QrScanBinding(),
    //   transition: Transition.downToUp,
    //   transitionDuration: const Duration(milliseconds: 400),
    // ),
    // GetPage(
    //   name: Routes.ADD_MANUALLY,
    //   page: () => const AddManuallyView(),
    //   // binding: AddManuallyBinding(),
    //   transition: Transition.downToUp,
    //   transitionDuration: const Duration(milliseconds: 400),
    // ),
  ];
}
