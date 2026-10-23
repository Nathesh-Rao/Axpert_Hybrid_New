import 'package:axpert/app/modules/auth/controller/forgot_password_controller.dart';
import 'package:axpert/app/modules/auth/views/forgot_passwrod_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _TestRecovery extends ForgetPasswordController {
  int requests = 0, submissions = 0, resends = 0;
  @override
  void proceedButtonClicked() {
    if (vaidateForm()) requests++;
  }

  @override
  void submitOTPClicked() {
    if (validateOTPSubmittionForm()) submissions++;
  }

  @override
  void reSendOTP() {
    resends++;
  }
}

Future<_TestRecovery> _open(WidgetTester tester, {bool dark = false}) async {
  final c = Get.put<ForgetPasswordController>(_TestRecovery()) as _TestRecovery;
  await tester.pumpWidget(
    GetMaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        body: TextButton(
          onPressed: () => Get.to(
            () => const ForgetPasswordView(),
            arguments: {'username': 'narasimha', 'project': 'PGBASE114'},
          ),
          child: const Text('Open recovery'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open recovery'));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUp(() {
    Get.testMode = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    PackageInfo.setMockInitialValues(
      appName: 'Axpert',
      packageName: 'axpert',
      version: '11.4.0',
      buildNumber: '6',
      buildSignature: '',
    );
  });
  tearDown(() => Get.reset());
  testWidgets(
    'route values initialize once; username stays read-only; existing email validation and callback work',
    (tester) async {
      final c = await _open(tester);
      expect(c.projectName, 'PGBASE114');
      expect(c.userNameController.text, 'narasimha');
      expect(
        tester.widget<TextField>(find.byType(TextField).first).readOnly,
        isTrue,
      );
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(find.text('Please Enter Email ID'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'bad');
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(find.text('Please Enter a valid Email ID'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'user@example.com');
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(c.requests, 1);
      c.userNameController.text = 'updated';
      c.isFPasswordLoading.value = true;
      await tester.pump();
      expect(c.userNameController.text, 'updated');
      expect(c.emailController.text, 'user@example.com');
      expect(find.text('Please wait...'), findsOneWidget);
      await tester.tap(find.text('Please wait...'));
      expect(c.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final otp in [false, true]) {
    testWidgets(
      'narrow dark layout with keyboard and ${otp ? 'OTP passwords' : 'email form'} has no overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final c = await _open(tester, dark: true);
        c.OTPSent.value = otp;
        if (otp) {
          c.passError.value =
              'Password should contain upper, lower, digit and Special character';
        }
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(otp ? 'Submit' : 'Proceed'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'OTP form retains resend gating, visibility toggles, validation and submit',
    (tester) async {
      final c = await _open(tester);
      c.OTPSent.value = true;
      c.otpLength.value = '4';
      c.timerText.value = '00:30';
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resend in 00:30'));
      expect(c.resends, 0);
      c.showTimer.value = false;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resend OTP'));
      expect(c.resends, 1);
      await tester.ensureVisible(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Enter OTP'), findsWidgets);
      c.otpController.text = '1234';
      c.passwordController.text = 'StrongPass1!';
      c.confirmPasswordController.text = 'StrongPass1!';
      await tester.ensureVisible(find.byTooltip('Show new password'));
      await tester.tap(find.byTooltip('Show new password'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isFalse,
      );
      await tester.ensureVisible(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(c.submissions, 1);
      await tester.ensureVisible(find.byTooltip('Back to sign in'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Back to sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Open recovery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
