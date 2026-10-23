import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/data/enums/auth_enums.dart';
import 'package:axpert/app/widgets/connection_style.dart';
import 'package:axpert/app/widgets/project_logo.dart';
import '../controller/auth_controller.dart';
import '../widget/biometric_switcher.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthController controller = Get.find();
  late final Future<String> _version;
  @override
  void initState() {
    super.initState();
    _version = controller.getVersionName();
  }

  bool get _busy =>
      controller.isUserDataLoading.value || controller.isSigninApiCalling.value;
  Future<void> _submit() async {
    if (_busy || controller.selectedProject.value == null) return;
    if (!controller.validateForm()) return;
    if (controller.isPWD_auth.value) {
      await controller.callSignInAPI();
    } else {
      await controller.startLoginProcess();
    }
  }

  void _resetUsername() {
    controller.isPWD_auth.value = false;
    controller.isOTP_auth.value = false;
    controller.authType.value = AuthType.none;
    controller.userPasswordController.clear();
    controller.errPassword.value = '';
    controller.errUserName.value = '';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop) await controller.showExitConfirmationSheet();
    },
    child: Scaffold(
      backgroundColor: ConnectionStyle.card(context),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FutureBuilder<String>(
                  future: _version,
                  builder: (context, snapshot) => Text(
                    snapshot.hasData
                        ? 'v${snapshot.data} · Axpert ${AppConst.APP_RELEASE_DATE}'
                        : 'Axpert',
                    key: const ValueKey('login-version'),
                    textAlign: TextAlign.center,
                    style: ConnectionStyle.text(
                      context,
                      11,
                      color: ConnectionStyle.muted(context),
                    ),
                  ),
                ),
              ),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                ConnectionHero(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        constraints.maxHeight < 600 ? 18 : 32,
                        24,
                        58,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            // Round logo badge that adapts to any dynamic logo.
                            Obx(
                              () => ProjectLogo(
                                url:
                                    controller.selectedProject.value?.logourl ??
                                    '',
                                projectName:
                                    controller.currentProjectName.value,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome back',
                              style: ConnectionStyle.text(
                                context,
                                28,
                                weight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in to continue',
                              style: ConnectionStyle.text(
                                context,
                                13,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Obx(
                              () => PopupMenuButton<int>(
                                enabled: !_busy,
                                tooltip: 'Select project',
                                position: PopupMenuPosition.under,
                                offset: const Offset(0, 10),
                                color: ConnectionStyle.card(context),
                                surfaceTintColor: Colors.transparent,
                                elevation: 12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 240,
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width < 380
                                      ? MediaQuery.sizeOf(context).width - 40
                                      : 340,
                                ),
                                onSelected: (id) {
                                  if (id == -1) {
                                    Get.offNamed(Routes.PROJECT_CONFIG);
                                  } else {
                                    _resetUsername();
                                    controller.projectChanged(id);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem<int>(
                                    enabled: false,
                                    height: 40,
                                    child: Text(
                                      'YOUR PROJECTS',
                                      style: ConnectionStyle.text(
                                        context,
                                        11,
                                        weight: FontWeight.w700,
                                        color: ConnectionStyle.muted(context),
                                      ),
                                    ),
                                  ),
                                  for (final p in controller.projects)
                                    if (p.id != null)
                                      PopupMenuItem<int>(
                                        value: p.id!,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                p.id ==
                                                    controller
                                                        .selectedProject
                                                        .value
                                                        ?.id
                                                ? ConnectionStyle.tint(context)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              ProjectLogo(
                                                url: p.logourl,
                                                projectName: p.schemaName,
                                                size: 38,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      p.schemaName,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          ConnectionStyle.text(
                                                            context,
                                                            13,
                                                            weight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    if (p.caption
                                                        .trim()
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        p.caption,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: ConnectionStyle.text(
                                                          context,
                                                          11,
                                                          color:
                                                              ConnectionStyle.muted(
                                                                context,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                p.id ==
                                                        controller
                                                            .selectedProject
                                                            .value
                                                            ?.id
                                                    ? Icons.check_circle_rounded
                                                    : Icons
                                                          .chevron_right_rounded,
                                                size: 20,
                                                color:
                                                    p.id ==
                                                        controller
                                                            .selectedProject
                                                            .value
                                                            ?.id
                                                    ? ConnectionStyle.navy
                                                    : ConnectionStyle.muted(
                                                        context,
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem<int>(
                                    value: -1,
                                    height: 70,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: ConnectionStyle.tint(
                                              context,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.settings_outlined,
                                            size: 20,
                                            color: ConnectionStyle.navy,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Manage projects',
                                                style: ConnectionStyle.text(
                                                  context,
                                                  13,
                                                  weight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Add or edit connections',
                                                style: ConnectionStyle.text(
                                                  context,
                                                  11,
                                                  color: ConnectionStyle.muted(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: ConnectionStyle.muted(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.storage_outlined,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          controller
                                                  .currentProjectName
                                                  .value
                                                  .isEmpty
                                              ? 'Select project'
                                              : controller
                                                    .currentProjectName
                                                    .value
                                                    .toUpperCase(),
                                          overflow: TextOverflow.ellipsis,
                                          style: ConnectionStyle.text(
                                            context,
                                            12,
                                            weight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -34),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      constraints.maxWidth < 360
                          ? 20
                          : (constraints.maxWidth - 440) / 2 > 28
                          ? (constraints.maxWidth - 440) / 2
                          : 28,
                      28,
                      constraints.maxWidth < 360
                          ? 20
                          : (constraints.maxWidth - 440) / 2 > 28
                          ? (constraints.maxWidth - 440) / 2
                          : 28,
                      0,
                    ),
                    decoration: BoxDecoration(
                      color: ConnectionStyle.card(context),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: CustomPaint(
                      painter: _LoginBackground(),
                      child: Obx(() {
                        final password = controller.isPWD_auth.value;
                        final busy = _busy;
                        return AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!password) ...[
                                Text(
                                  'Let’s get you signed in',
                                  style: ConnectionStyle.text(
                                    context,
                                    21,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enter your username to continue to your account.',
                                  style: ConnectionStyle.text(
                                    context,
                                    13,
                                    color: ConnectionStyle.muted(context),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (password) ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xffFFC067),
                                            ConnectionStyle.orange,
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        controller.userNameController.text
                                                .trim()
                                                .isEmpty
                                            ? '?'
                                            : controller.userNameController.text
                                                  .trim()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                        style: ConnectionStyle.text(
                                          context,
                                          18,
                                          weight: FontWeight.w800,
                                          color: const Color(0xff1A2447),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Hi, ${_greetingName(controller.userNameController.text)}',
                                            style: ConnectionStyle.text(
                                              context,
                                              17,
                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Enter your password to sign in',
                                            style: ConnectionStyle.text(
                                              context,
                                              12,
                                              color: ConnectionStyle.muted(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _label(context, 'Password'),
                                TextField(
                                  controller: controller.userPasswordController,
                                  focusNode: controller.passwordFocus,
                                  enabled: !busy,
                                  obscureText: controller.showPassword.value,
                                  autofillHints: const [AutofillHints.password],
                                  onChanged: (_) =>
                                      controller.errPassword.value = '',
                                  onSubmitted: (_) => _submit(),
                                  style: ConnectionStyle.text(context, 15),
                                  decoration: _input(
                                    context,
                                    'Your password',
                                    Icons.lock_outline,
                                    error: controller.errPassword.value,
                                    suffix: IconButton(
                                      tooltip: controller.showPassword.value
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: controller.showPassword.toggle,
                                      icon: Icon(
                                        controller.showPassword.value
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: ConnectionStyle.muted(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                _label(context, 'Username'),
                                TextField(
                                  controller: controller.userNameController,
                                  enabled: !busy,
                                  autofillHints: const [AutofillHints.username],
                                  autocorrect: false,
                                  textInputAction: TextInputAction.go,
                                  onChanged: (_) =>
                                      controller.errUserName.value = '',
                                  onSubmitted: (_) => _submit(),
                                  style: ConnectionStyle.text(context, 15),
                                  decoration: _input(
                                    context,
                                    'Enter your username',
                                    Icons.person_outline,
                                    error: controller.errUserName.value,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: ListTileTheme(
                                      data: ListTileTheme.of(context).copyWith(
                                        horizontalTitleGap: 4,
                                        minLeadingWidth: 24,
                                        minTileHeight: 44,
                                      ),
                                      child: CheckboxListTile(
                                        key: const ValueKey(
                                          'remember-me-checkbox',
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                        visualDensity: const VisualDensity(
                                          horizontal: -4,
                                          vertical: -2,
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        dense: true,
                                        activeColor: ConnectionStyle.navy,
                                        checkColor: Colors.white,
                                        side: BorderSide(
                                          color: ConnectionStyle.muted(context),
                                          width: 1.5,
                                        ),
                                        checkboxShape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        title: Text(
                                          'Remember me',
                                          style: ConnectionStyle.text(
                                            context,
                                            13,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                        value: controller.rememberMe.value,
                                        onChanged: busy
                                            ? null
                                            : (value) =>
                                                  controller.rememberMe.value =
                                                      value ?? false,
                                      ),
                                    ),
                                  ),
                                  if (password)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 12,
                                        ),
                                        foregroundColor: ConnectionStyle.navy,
                                        textStyle: ConnectionStyle.text(
                                          context,
                                          12,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      onPressed: busy
                                          ? null
                                          : () => Get.toNamed(
                                              Routes.FORGOT_PASSWORD,
                                              arguments: {
                                                'color': controller
                                                    .selectedColor
                                                    .value,
                                                'project': controller
                                                    .currentProjectName
                                                    .value,
                                                'username': controller
                                                    .userNameController
                                                    .text,
                                              },
                                            ),
                                      child: const Text('Forgot password?'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow:
                                        busy ||
                                            controller.selectedProject.value ==
                                                null
                                        ? null
                                        : const [
                                            BoxShadow(
                                              color: Color(0xb32D4E9E),
                                              blurRadius: 20,
                                              spreadRadius: -8,
                                              offset: Offset(0, 10),
                                            ),
                                          ],
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 52,
                                    ),
                                    child: ConnectionButton(
                                      label: busy
                                          ? controller.isUserDataLoading.value
                                                ? 'Validating user...'
                                                : controller
                                                      .signInApiStatusMessage
                                                      .value
                                          : password
                                          ? controller.authType.value ==
                                                    AuthType.both
                                                ? 'Get OTP'
                                                : 'Sign in'
                                          : 'Continue',
                                      icon: Icons.arrow_forward,
                                      loading: busy,
                                      onPressed:
                                          controller.selectedProject.value ==
                                              null
                                          ? null
                                          : _submit,
                                    ),
                                  ),
                                ),
                              ),
                              if (password)
                                Center(
                                  child: TextButton(
                                    onPressed: busy ? null : _resetUsername,
                                    child: const Text(
                                      'Not you? Use another username',
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  'By continuing, you agree to the Privacy Policy\nand Terms of Use.',
                                  textAlign: TextAlign.center,
                                  style: ConnectionStyle.text(
                                    context,
                                    11,
                                    color: ConnectionStyle.muted(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Center(child: BiometricSwitcher()),
                              const SizedBox(height: 18),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  InputDecoration _input(
    BuildContext context,
    String hint,
    IconData icon, {
    String? error,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    return ConnectionStyle.input(
      context,
      hint,
      icon,
      error: error,
      suffix: suffix,
    ).copyWith(
      hintStyle: ConnectionStyle.text(
        context,
        15,
        color: ConnectionStyle.dark(context)
            ? ConnectionStyle.muted(context)
            : const Color(0xff7A869F),
      ),
      constraints: const BoxConstraints(minHeight: 56),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      enabledBorder: border(ConnectionStyle.line(context)),
      focusedBorder: border(ConnectionStyle.navy),
      errorBorder: border(const Color(0xffC7364B)),
      focusedErrorBorder: border(const Color(0xffC7364B)),
      errorStyle: ConnectionStyle.text(
        context,
        12,
        weight: FontWeight.w600,
        color: const Color(0xffC7364B),
      ),
      errorMaxLines: 3,
    );
  }

  String _greetingName(String username) {
    final name = username.trim();
    if (name.isEmpty) return name;
    return '${name.characters.first.toUpperCase()}${name.characters.skip(1).toString()}';
  }

  Widget _label(BuildContext c, String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      label,
      style: ConnectionStyle.text(
        c,
        12,
        weight: FontWeight.w600,
        color: ConnectionStyle.muted(c),
      ),
    ),
  );
}

class _LoginBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(-45, size.height - 30);
    canvas.drawCircle(
      center,
      170,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x29F5A03A), Color(0x00F5A03A)],
        ).createShader(Rect.fromCircle(center: center, radius: 170)),
    );
    final paint = Paint()
      ..color = const Color(0x1a2D4E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in [60.0, 95.0, 130.0, 165.0]) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_LoginBackground oldDelegate) => false;
}
