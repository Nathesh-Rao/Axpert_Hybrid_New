import 'package:axpert/app/data/enums/auth_enums.dart';
import 'package:axpert/app/data/models/project_model.dart';
import 'package:axpert/app/modules/auth/controller/auth_controller.dart';
import 'package:axpert/app/modules/auth/views/login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class _TestAuth extends AuthController {
  int signIns = 0;
  @override
  // Deliberately bypass production initialization: tests use no database or server.
  // ignore: must_call_super
  void onInit() {
    selectedProject.value = const ProjectModel(
      id: 1,
      url: 'https://example.com',
      armurl: 'https://example.com/arm',
      schemaName: 'PGBASE114',
    );
    currentProjectName.value = 'PGBASE114';
    projects.add(selectedProject.value!);
  }

  @override
  Future<String> getVersionName() async => '11.4.0';
  @override
  Future<void> startLoginProcess() async {
    isPWD_auth.value = true;
    authType.value = AuthType.passwordOnly;
  }

  @override
  Future<void> callSignInAPI() async {
    if (validateForm()) signIns++;
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(() => Get.reset());
  testWidgets(
    'username validation, password step, visibility and changing user',
    (tester) async {
      final c = Get.put<AuthController>(_TestAuth()) as _TestAuth;
      await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('remember-me-checkbox')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remember-me-checkbox')));
      await tester.pumpAndSettle();
      expect(c.rememberMe.value, isTrue);
      await tester.tap(find.byKey(const ValueKey('remember-me-checkbox')));
      await tester.pumpAndSettle();
      expect(c.rememberMe.value, isFalse);
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter User Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'narasimha');
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Hi, Narasimha'), findsOneWidget);
      expect(c.userNameController.text, 'narasimha');
      final rememberRect = tester.getRect(
        find.byKey(const ValueKey('remember-me-checkbox')),
      );
      final forgotRect = tester.getRect(
        find.widgetWithText(TextButton, 'Forgot password?'),
      );
      expect(rememberRect.center.dy, closeTo(forgotRect.center.dy, 1));
      expect(rememberRect.right, lessThanOrEqualTo(forgotRect.left));

      expect(
        find.byKey(const ValueKey('remember-me-checkbox')),
        findsOneWidget,
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Password is required'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(c.signIns, 1);
      await tester.tap(find.text('Not you? Use another username'));
      await tester.pumpAndSettle();
      expect(find.text('Username'), findsOneWidget);
      expect(c.userPasswordController.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'login scrolls on a narrow screen with the keyboard open in dark mode',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      Get.put<AuthController>(_TestAuth());
      await tester.pumpWidget(
        GetMaterialApp(theme: ThemeData.dark(), home: const LoginView()),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('login keeps the form readable on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put<AuthController>(_TestAuth());
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TextField)).width, closeTo(440, .1));
    expect(
      tester.getRect(find.byKey(const ValueKey('login-version'))).bottom,
      closeTo(784, 1),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'project picker shows the selected project and management action on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.put<AuthController>(_TestAuth());
      await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select project'));
      await tester.pumpAndSettle();
      expect(find.text('YOUR PROJECTS'), findsOneWidget);
      expect(find.text('Manage projects'), findsOneWidget);
      expect(find.text('Add or edit connections'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
