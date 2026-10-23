import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/modules/auth/controller/auth_controller.dart';
import 'package:axpert/app/modules/auth/views/otp_view.dart';
import 'package:axpert/app/modules/auth/widget/otp_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';

class _OtpTestAuth extends AuthController {
  int verifications = 0;
  int resends = 0;
  @override
  // Tests supply state directly without production database or API initialization.
  // ignore: must_call_super
  void onInit() {
    otpChars.value = '8';
    otpMsg.value = 'An OTP has been sent to your mobile number and email.';
    currentProjectName.value = 'PGBASE114';
    otpRemainingSeconds.value = 90;
  }

  @override
  Future<String> getVersionName() async => '11.4.0';
  @override
  Future<void> callVerifyOTP() async {
    verifications++;
    validateOTPField();
  }

  @override
  Future<void> callResendOTP() async {
    resends++;
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(() => Get.reset());
  testWidgets(
    'OTP completion and Login retain verification; resend respects controller timer',
    (tester) async {
      final c = Get.put<AuthController>(_OtpTestAuth()) as _OtpTestAuth;
      await tester.pumpWidget(const GetMaterialApp(home: OTPView()));
      await tester.pumpAndSettle();
      expect(find.text('1:30 min'), findsOneWidget);
      expect(tester.widget<Pinput>(find.byType(Pinput)).length, 8);
      await tester.tap(find.text('Resend in 90s'));
      expect(c.resends, 0);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(c.verifications, 1);
      expect(find.text('Enter full 8-digit OTP'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '12345678');
      await tester.pumpAndSettle();
      expect(c.verifications, 2);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(c.verifications, 3);
      c.otpRemainingSeconds.value = 0;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resend code'));
      expect(c.resends, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final length in [4, 8]) {
    testWidgets(
      '$length digit OTP fits 320px dark screen with keyboard and server error',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final c = Get.put<AuthController>(_OtpTestAuth());
        c.otpChars.value = '$length';
        c.otpErrorText.value = 'The code is invalid. Please try again.';
        await tester.pumpWidget(
          GetMaterialApp(theme: ThemeData.dark(), home: const OTPView()),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(WidgetOtpTextField));
        await tester.pumpAndSettle();
        expect(tester.widget<Pinput>(find.byType(Pinput)).length, length);
        expect(
          find.text('The code is invalid. Please try again.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Login'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('back returns to the existing login route', (tester) async {
    Get.put<AuthController>(_OtpTestAuth());
    await tester.pumpWidget(
      GetMaterialApp(
        home: const OTPView(),
        getPages: [
          GetPage(
            name: Routes.LOGIN,
            page: () => const Scaffold(body: Text('Sign in destination')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in destination'), findsOneWidget);
  });
}
